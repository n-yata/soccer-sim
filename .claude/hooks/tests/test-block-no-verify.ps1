# block-no-verify.ps1 の回帰テスト
#
# 背景: 本フックは「LLM の判断に依存せず --no-verify を機械的に拒否する」多層防御。
#       スクリプトがパースエラーで落ちると **何も出力せず素通り(fail open)** するため、
#       壊れても気づかないまま security 制御が無効化される。実際に移設作業で
#       BOM 欠落によるパースエラーが発生し、deny すべき3ケースが全て allow になった。
#
# 実行:
#   powershell -NoProfile -ExecutionPolicy Bypass -File ./tests/test-block-no-verify.ps1
#
# 終了コード: 全ケース成功で 0、1件でも失敗で 1

$ErrorActionPreference = 'Stop'

$hookPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'block-no-verify.ps1'

if (-not (Test-Path -LiteralPath $hookPath)) {
    Write-Output "FAIL: フック本体が見つからない: $hookPath"
    exit 1
}

# --- 前提条件: BOM 付き UTF-8 であること -------------------------------------
# Windows PowerShell 5.1 は BOM 無しの .ps1 を ANSI(CP932)として読むため、
# 日本語を含むスクリプトは BOM が無いとパースエラーになる。
$bytes = [System.IO.File]::ReadAllBytes($hookPath)
$hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
if (-not $hasBom) {
    Write-Output "FAIL: block-no-verify.ps1 に UTF-8 BOM が無い。Windows PowerShell 5.1 がパースに失敗し、フックが素通りする"
    exit 1
}
Write-Output "PASS: UTF-8 BOM あり"

# --- 振る舞いのテスト --------------------------------------------------------
$cases = @(
    # --- 基本の deny ---------------------------------------------------------
    @{ name = '--no-verify を含む commit';        command = 'git commit --no-verify -m test'; expect = 'deny'  }
    @{ name = '-n (--no-verify の別名)';           command = 'git commit -n -m test';          expect = 'deny'  }
    @{ name = '--no-gpg-sign を含む push';         command = 'git push --no-gpg-sign';         expect = 'deny'  }
    @{ name = '大文字混じりの --NO-VERIFY';        command = 'git commit --NO-VERIFY -m test'; expect = 'deny'  }

    # --- セキュリティレビューで実証された回避経路（旧実装は全て素通りした）---
    @{ name = '短オプション結合 -nm';              command = 'git commit -nm "msg"';                      expect = 'deny' }
    @{ name = '二重引用符で囲んだフラグ';          command = 'git commit "--no-verify" -m x';             expect = 'deny' }
    @{ name = '単一引用符で囲んだフラグ';          command = "git commit '--no-verify' -m x";             expect = 'deny' }
    @{ name = 'core.hooksPath 差し替え';           command = 'git -c core.hooksPath=/dev/null commit -m x'; expect = 'deny' }
    @{ name = 'GIT_CONFIG_* 経由の注入';           command = 'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null git commit -m x'; expect = 'deny' }

    # --- コマンド全体を引用で包む形（2026-08-16 のレビューで実測により素通りを確認）---
    # 旧実装は「引用を剥がした文字列」でコマンド種別を判定していたため、
    # 全体が引用に包まれると git も commit も消え、**検査に入る前に早期 exit** していた。
    # 判定を生文字列で行うことで塞いだ。ここを引用剥がし側へ戻してはならない。
    @{ name = 'bash -c で包んだフラグ';            command = 'bash -c "git commit --no-verify -m x"';     expect = 'deny' }
    @{ name = 'eval で包んだフラグ';               command = 'eval "git commit --no-verify -m x"';        expect = 'deny' }
    @{ name = 'sh -c で包んだフラグ（単一引用）';  command = "sh -c 'git commit --no-verify -m x'";       expect = 'deny' }
    @{ name = 'バッククォートによるエスケープ';    command = 'git commit --no-ver`ify -m x';              expect = 'deny' }

    # --- ラッパー引用形の短縮オプション（H-1 と同じ穴が -n 側に残っていた）---
    # 引用区間を一律に潰すと、入れ子コマンド内の -n を見失う。
    # メッセージ本文だけを潰す方式に変えて塞いだ。
    @{ name = 'bash -c で包んだ -n';               command = 'bash -c "git commit -n -m x"';              expect = 'deny' }
    @{ name = 'eval で包んだ -nm';                 command = 'eval "git commit -nm msg"';                 expect = 'deny' }
    @{ name = 'sh -c で包んだ -n（単一引用）';     command = "sh -c 'git commit -n -m x'";                expect = 'deny' }

    # --- ロングオプションの省略形（git は曖昧でなければ前方一致を受理する）---
    @{ name = '省略形 --no-veri';                  command = 'git commit --no-veri -m x';                 expect = 'deny' }
    @{ name = '省略形 --no-verif';                 command = 'git commit --no-verif -m x';                expect = 'deny' }

    # --- 終端が空白・引用以外（; && | 括弧）-----------------------------------
    @{ name = 'セミコロンで連結';                  command = 'git commit --no-verify;echo done';          expect = 'deny' }
    @{ name = '括弧で囲んだ commit';               command = '(git commit --no-verify)';                  expect = 'deny' }
    @{ name = 'パイプで連結';                      command = 'git commit -m x --no-verify|cat';           expect = 'deny' }

    # --- 語中のエスケープ・引用連結（git には --no-verify として届く）---------
    @{ name = 'バックスラッシュエスケープ';        command = 'git commit --no-\verify -m x';              expect = 'deny' }
    @{ name = '語中の二重引用連結';                command = 'git commit --no-ve"r"ify -m x';             expect = 'deny' }

    # --- 誤検知の回帰（旧実装は誤って deny した）-----------------------------
    @{ name = 'push の -n は --dry-run';           command = 'git push -n';                    expect = 'allow' }
    @{ name = 'メッセージ本文の -n';               command = 'git commit -m "fix -n handling"'; expect = 'allow' }

    # 意図的な誤検知（許容する）:
    # ロングオプションは「引用符で囲んだバイパス」(git commit "--no-verify") を捕捉するため
    # 生文字列で検査している。副作用としてメッセージ本文に --no-verify と書いた場合も deny になる。
    # 取りこぼし(fail open)より誤検知(fail closed)を選ぶ。回避したい場合はメッセージの表記を
    # 変える(例: "no verify")か、フラグを使わない旨を本文から外す。
    @{ name = 'メッセージ本文の --no-verify 言及（許容する誤検知）'; command = "git commit -m 'document --no-verify policy'"; expect = 'deny' }

    # --- 通常操作 -----------------------------------------------------------
    @{ name = '通常の commit';                     command = 'git commit -m test';             expect = 'allow' }
    @{ name = '通常の push';                       command = 'git push origin main';           expect = 'allow' }
    @{ name = '-am での commit';                   command = 'git commit -am "msg"';           expect = 'allow' }
    @{ name = 'git 以外のコマンド';                command = 'npm run build';                  expect = 'allow' }
    @{ name = 'no-verify を含むが git でない';     command = 'echo --no-verify';               expect = 'allow' }
    @{ name = 'git grep（誤ブロック回帰）';        command = 'git grep -n "pattern"';          expect = 'allow' }

    # --- 誤検知の番人（塞ぎを強めたことで壊れやすい箇所）---------------------
    @{ name = 'git log -n';                        command = 'git log -n 5';                   expect = 'allow' }
    @{ name = 'commit --amend --no-edit';          command = 'git commit --amend --no-edit';   expect = 'allow' }
    @{ name = 'push --dry-run';                    command = 'git push --dry-run origin main'; expect = 'allow' }
    @{ name = 'commit --verbose';                  command = 'git commit --verbose -m x';      expect = 'allow' }
    @{ name = 'ラッパー内のメッセージ本文の -n';   command = 'bash -c "git commit -m ''fix -n handling''"'; expect = 'allow' }

    # --- 複合コマンド中の git 以外の -n（2026-08-20 に実測した誤検知）---------
    # 短縮オプション検査がコマンド全体に対して走っていたため、git commit と
    # 同居する grep -n / head -n / sort -n 等に誤反応していた。
    # 検査を「git commit を含むセグメント（; & | 区切り）」に限定して解消。
    @{ name = 'grep -n と commit の複合';          command = 'grep -n "pattern" file && git commit -m x';     expect = 'allow' }
    @{ name = 'head -n と commit の複合';          command = 'head -n 20 log.txt; git commit -m x';           expect = 'allow' }
    @{ name = 'sort -n のパイプ後に commit';       command = 'sort -n data.txt | tail -1 && git commit -m x'; expect = 'allow' }
    @{ name = '複合でも commit 側の -n は deny';   command = 'echo start && git commit -n -m x';               expect = 'deny' }
    @{ name = '複合でも commit 側の -nm は deny';  command = 'grep -n p f; git commit -nm x';                  expect = 'deny' }
    @{ name = '改行で逃がした -n は deny（改行では分割しない）'; command = "git commit -m x`n-n";              expect = 'deny' }

    # --- セグメント境界の偽装（deny 範囲を狭めた境界のすぐ外側を突く敵対的ケース）---
    # エスケープされた区切り・コマンド置換内の区切りはシェルでは境界にならず、
    # -n は git に独立オプションとして届く。分割前の無効化で deny を維持する。
    @{ name = 'エスケープした ; で -n を逃がす';   command = 'git commit -m foo\;bar -n';        expect = 'deny' }
    @{ name = 'エスケープした & で -n を逃がす';   command = 'git commit -m foo\&bar -n';        expect = 'deny' }
    @{ name = 'エスケープした | で -n を逃がす';   command = 'git commit -m foo\|bar -n';        expect = 'deny' }
    @{ name = 'コマンド置換内の ; で境界を偽装';   command = 'git commit -m $(printf a;b) -n';   expect = 'deny' }
    @{ name = 'エスケープ ; と結合クラスタ -nm';   command = 'git commit -m foo\;bar -nm y';     expect = 'deny' }
    @{ name = '未閉鎖のコマンド置換（fail closed）'; command = 'git commit -m $(echo a;b -n';    expect = 'deny' }
    @{ name = '変数展開 ${} 内の ; で境界を偽装';  command = 'git commit -m ${x;y} -n';          expect = 'deny' }
    @{ name = 'Windows パスとの複合は誤検知しない'; command = 'git commit -m C:\tmp\out && grep -n p f'; expect = 'allow' }

    # --- フック無効化の「単独コマンド」形（H-1。旧実装は全て素通りした）-------
    # commit も push も含まないため、種別ゲートの早期 exit に阻まれて
    # 検査そのものが行われていなかった。設定は .git/config に永続化されるので、
    # 2ターンに分けるだけで以後のコミットが全てフックを迂回できた。
    @{ name = '単独の core.hooksPath 差し替え';    command = 'git config core.hooksPath /dev/null';   expect = 'deny' }
    @{ name = '単独の gpgsign 無効化（空白区切り）'; command = 'git config commit.gpgsign false';     expect = 'deny' }
    @{ name = '単独の gpgsign 無効化（= 区切り）'; command = 'git config commit.gpgsign=false';       expect = 'deny' }
    @{ name = '単独の GIT_CONFIG_* 注入';          command = 'GIT_CONFIG_KEY_0=core.hooksPath true';  expect = 'deny' }
    @{ name = 'pre-commit フックの削除';           command = 'rm .git/hooks/pre-commit';              expect = 'deny' }
    @{ name = 'pre-commit フックの退避';           command = 'mv .git/hooks/pre-commit /tmp/';        expect = 'deny' }
    @{ name = 'pre-commit フックの実行権剥奪';     command = 'chmod -x .git/hooks/pre-commit';        expect = 'deny' }
    @{ name = 'フックの読み取りは誤検知しない';    command = 'cat .git/hooks/pre-commit';             expect = 'allow' }
    @{ name = 'hooks を含む無関係なパスの削除';    command = 'rm build/hooks/tmp.txt';                expect = 'allow' }

    # --- 空展開を語中に挟むロングオプション回避（H-2。旧実装は素通りした）----
    # 引用・バックスラッシュは1文字なので既存の除去で落ちたが、
    # シェルが空文字へ展開する ${...} / $(...) は落ちず、git には届いていた。
    @{ name = '空変数展開を語中に挟む ${q}';       command = 'git commit -m x --no-ver${q}ify';       expect = 'deny' }
    @{ name = '空コマンド置換を語中に挟む $()';    command = 'git commit -m x --no-ver$()ify';        expect = 'deny' }
    @{ name = '空展開を挟んだ --no-gpg-sign';      command = 'git commit -m x --no-gpg-${z}sign';     expect = 'deny' }

    # --- 設定キー側にも同じ細工が残っていた（H-B。実測で素通りを確認）--------
    # --no-verify 側だけ $deescaped で検査を強化し、設定キー側は生文字列のまま
    # だったため、1文字挟むだけで「① 設定を書き換える → ② 普通にコミットする」の
    # 2ターン攻撃が完全に復活していた。検査対象の文字列を揃えて解消。
    @{ name = '引用を挟んだ hooksPath';            command = 'git config core.hooks"P"ath /dev/null';   expect = 'deny' }
    @{ name = '空変数展開を挟んだ hooksPath';      command = 'git config core.hooks${x}Path /dev/null'; expect = 'deny' }
    @{ name = 'バックスラッシュを挟んだ hooksPath'; command = 'git config core.hooks\Path /dev/null';   expect = 'deny' }

    # --- 入れ子のコマンド置換（H-C。1回の置換では消えなかった）---------------
    # \$\([^)]*\) は最初の ) で止まるため、余った ) が語中に残って
    # 前方一致の境界クラスを壊していた。変化がなくなるまで繰り返して解消。
    @{ name = '入れ子の $() を挟んだフラグ';       command = 'git commit -m x --no-ver$(echo $(true))ify';         expect = 'deny' }
    @{ name = '入れ子の $() を挟んだ hooksPath';   command = 'git config core.hooks$(echo $(true))Path /dev/null'; expect = 'deny' }

    # --- .git/hooks の破壊は動詞の列挙では網羅できない（M-1）-----------------
    @{ name = 'cp で pre-commit を潰す';           command = 'cp /dev/null .git/hooks/pre-commit';     expect = 'deny' }
    @{ name = 'リダイレクトで pre-commit を潰す';  command = 'echo "" > .git/hooks/pre-commit';        expect = 'deny' }
    @{ name = 'ln -s で pre-commit を差し替え';    command = 'ln -sf /dev/null .git/hooks/pre-commit'; expect = 'deny' }
    @{ name = 'sed -i で pre-commit を書き換え';   command = 'sed -i "s/x/y/" .git/hooks/pre-commit';  expect = 'deny' }
    @{ name = 'find -delete で一括削除';           command = 'find .git/hooks -type f -delete';        expect = 'deny' }
    @{ name = 'Windows 形式の .git\hooks 削除';    command = 'rm .git\hooks\pre-commit';               expect = 'deny' }

    # --- PowerShell ネイティブの動詞（H-2。旧実装は POSIX 形しか見ていなかった）---
    # 本フックは Windows PowerShell が主対象なのに、回帰テストは POSIX 形しか無く、
    # ネイティブの動詞（Remove-Item とその別名 ri 等）は1件もカバーしていなかった。
    @{ name = 'Remove-Item で pre-commit を削除';  command = 'Remove-Item .git/hooks/pre-commit';      expect = 'deny' }
    @{ name = 'Remove-Item -Recurse で hooks ごと削除'; command = 'Remove-Item -Recurse -Force .git/hooks'; expect = 'deny' }
    @{ name = 'エイリアス ri で pre-commit を削除'; command = 'ri .git/hooks/pre-commit';               expect = 'deny' }
    @{ name = 'Move-Item で hooks を退避';         command = 'Move-Item .git/hooks .git/hooks-off';    expect = 'deny' }
    @{ name = 'Set-Content で pre-commit を上書き'; command = 'Set-Content -Path .git/hooks/pre-commit -Value ""'; expect = 'deny' }
    @{ name = 'Out-File で pre-commit を上書き';   command = 'Out-File -FilePath .git/hooks/pre-commit'; expect = 'deny' }
    @{ name = 'cmd.exe 系 del で pre-commit を削除'; command = 'del .git\hooks\pre-commit';             expect = 'deny' }
    @{ name = 'cmd.exe 系 move で hooks を退避';   command = 'move .git\hooks .git\hooks-off';         expect = 'deny' }

    # --- 本フック自身の実行資産の保護（H-1。旧実装は保護対象外だった）-----------
    # 「① 強制機構を消す → ② 普通にコミットする」の2ターン攻撃が、.git/hooks
    # ではなく本フック自身（.claude/hooks/ と .claude/settings.json）に対して
    # そのまま成立していた。フックが無いと powershell は落ち、ホストは fail open する。
    @{ name = 'フック本体スクリプトの削除';        command = 'rm .claude/hooks/block-no-verify.ps1';   expect = 'deny' }
    @{ name = 'Remove-Item でフック本体を削除';    command = 'Remove-Item .claude/hooks/block-no-verify.ps1'; expect = 'deny' }
    @{ name = 'settings.json の削除';              command = 'rm .claude/settings.json';               expect = 'deny' }
    @{ name = '引用符付き settings.json の削除（旧実装は素通り）'; command = 'rm ".claude/settings.json"'; expect = 'deny' }
    @{ name = '単一引用符付き settings.json の削除'; command = "rm '.claude/settings.json'";            expect = 'deny' }
    @{ name = 'settings.json の上書き';            command = 'echo "{}" > .claude/settings.json';      expect = 'deny' }
    @{ name = 'Set-Content で settings.json を上書き'; command = 'Set-Content -Path .claude/settings.json -Value "{}"'; expect = 'deny' }
    @{ name = 'Windows 形式の .claude\hooks 削除'; command = 'rm .claude\hooks\block-no-verify.ps1';   expect = 'deny' }
    @{ name = '.claude ディレクトリ自体の削除（旧実装は素通り）'; command = 'rm -rf .claude';           expect = 'deny' }
    @{ name = 'Remove-Item で .claude ディレクトリごと削除';    command = 'Remove-Item -Recurse -Force .claude'; expect = 'deny' }
    @{ name = 'Move-Item で .claude を退避';       command = 'Move-Item .claude .claude-off';          expect = 'deny' }
    @{ name = 'settings.local.json も配下として保護される'; command = 'rm .claude/settings.local.json'; expect = 'deny' }
    @{ name = '大入力パディングでも .claude 削除は deny（旧実装は $gitish 未到達で素通り）';
       command = ('rm .claude/hooks/block-no-verify.ps1 # ' + ('x' * 70000)); expect = 'deny' }
    @{ name = '置換の内側に .claude 破壊全体（旧実装は証拠ごと消えて素通り）';
       command = 'echo "$(rm .claude/hooks/block-no-verify.ps1)"'; expect = 'deny' }
    @{ name = 'hooks を含む無関係なパスは誤検知しない（自己防御側）'; command = 'rm vendor/claude/hooks/tmp.txt'; expect = 'allow' }
    @{ name = '似た名前のディレクトリを誤検知しない（.claude-backup）'; command = 'rm -rf .claude-backup/hooks'; expect = 'allow' }
    @{ name = '似た名前のディレクトリを誤検知しない（.claudex）';      command = 'rm .claudex/settings.json'; expect = 'allow' }
    @{ name = '本体の読み取りは誤検知しない';      command = 'cat .claude/hooks/block-no-verify.ps1';  expect = 'allow' }
    @{ name = 'grep -ri は誤検知しない（M-1: -ri を別名 ri と誤認しない）'; command = 'grep -ri todo .git/hooks'; expect = 'allow' }
    @{ name = 'diff -ac は誤検知しない（M-1: -ac を別名 ac と誤認しない）'; command = 'diff -ac a.txt .git/hooks/pre-commit'; expect = 'allow' }
    @{ name = 'Add-Content で pre-commit を追記（M-2で追加）'; command = 'Add-Content .git/hooks/pre-commit "exit 0"'; expect = 'deny' }
    @{ name = 'ren で hooks を退避（M-3で追加）'; command = 'ren .git\hooks pre-off';                  expect = 'deny' }
    @{ name = 'rd /s /q で hooks を削除（M-3で追加）'; command = 'rd /s /q .git\hooks';                expect = 'deny' }

    # --- 引用符1文字で .claude 親ディレクトリ削除が復活する穴（H-A。再レビューで実測） ---
    @{ name = '二重引用符付き .claude 削除（H-A）';   command = 'rm -rf ".claude"';                    expect = 'deny' }
    @{ name = '単一引用符付き .claude 削除（H-A）';   command = "rm '.claude'";                        expect = 'deny' }
    @{ name = 'LiteralPath 指定の .claude 削除（H-A）'; command = 'Remove-Item -LiteralPath ".claude" -Recurse'; expect = 'deny' }
    @{ name = '変数展開に埋めた .claude 削除（H-A）'; command = 'rm -rf "$PWD/.claude"';                expect = 'deny' }

    # --- .claude 配下の正当な運用を過剰検知しない（H-B。再レビューで実測） --------
    # kit-sync 自身の検証手順・スキル配置・ジャンクション作成が、自己防御の追加で
    # 巻き添えに deny されていた。「予測できない deny」を作らないための境界テスト。
    @{ name = 'kit-sync の検証手順（find）は誤検知しない（H-B）'; command = 'find .claude/hooks -type f -exec sha256sum {} \;'; expect = 'allow' }
    @{ name = '.claude/settings.json の sed 読み取りは誤検知しない（H-B）'; command = 'sed -n "1,20p" .claude/settings.json'; expect = 'allow' }
    @{ name = 'スキルのジャンクション作成は誤検知しない（H-B）';
       command = 'New-Item -ItemType Junction -Path .claude\skills -Target C:\kit\distribution\skills'; expect = 'allow' }
    @{ name = 'スキルスタブの複製は誤検知しない（H-B）'; command = 'cp distribution/skills/foo/SKILL.md .claude/skills/foo/SKILL.md'; expect = 'allow' }
    @{ name = 'Copy-Item でのスキル複製は誤検知しない（H-B）'; command = 'Copy-Item distribution/skills/foo/SKILL.md .claude/skills/foo/SKILL.md'; expect = 'allow' }
    @{ name = 'Set-Content でのスキル更新は誤検知しない（H-B）'; command = 'Set-Content -Path .claude/skills/foo/SKILL.md -Value "x"'; expect = 'allow' }
    @{ name = '.claude を含むコミットメッセージ本文は誤検知しない（M-A・除外した動詞なら）'; command = 'git commit -m "install .claude deps"'; expect = 'allow' }
    @{ name = '.claude/skills 配下の削除は破壊系動詞なので deny のまま（境界確認）'; command = 'rm .claude/skills/foo/SKILL.md'; expect = 'deny' }

    # --- 既知の残存バイパス（3回目のレビューで発見。文字列マッチ方式の限界として記録） ---
    # 🚨 これらは「直っていない」のではなく、**直せば直すほど別の誤検知を広げる
    #    トレードオフの relationship にある**ため、シャビの判断でここで打ち切った。
    #    ファイル冒頭の「多層防御の1枚であり、単独で保証を与えるものではない」を
    #    そのまま体現している。実 pre-commit フック等の併用が前提。
    @{ name = '引用符+Windowsバックスラッシュで .claude\hooks 削除（既知の穴）';
       command = 'rm -rf ".claude\hooks"';    expect = 'deny'; knownGap = $true }
    @{ name = '引用符+Windowsバックスラッシュで settings.json 削除（既知の穴）';
       command = 'rm ".claude\settings.json"'; expect = 'deny'; knownGap = $true }
    @{ name = 'グロブで .claude を削除（既知の穴）';
       command = 'rm -rf .claude*';           expect = 'deny'; knownGap = $true }
    @{ name = '同型の穴は .git\hooks 側にも変更前から存在する（既知の穴。回帰ではない）';
       command = 'rm -rf ".git\hooks"';       expect = 'deny'; knownGap = $true }
    # 🚨 以下3件は「過検知（over-blocking）」の既知のトレードオフ。knownGap は
    #    「攻撃が素通りする（under-blocking）」を表す語なのでここでは使わない。
    #    `expect` は実際の挙動（deny）に合わせ、**そうなる理由**をコメントで残す。
    @{ name = 'コミットメッセージ本文の誤検知（過検知。verb+.claudeの共起で発生。受容する）';
       command = 'git commit -m "fix: move .claude skills to dist"'; expect = 'deny' }
    @{ name = '読み取り専用コマンドの誤検知（過検知。動詞名が本文に出るだけで deny。受容する）';
       command = 'grep -r "rm .claude" docs/'; expect = 'deny' }
    @{ name = 'kit-sync のスキル退避は Bash 経由では deny のまま（過検知。kit-sync 側は Write ツール経由で行うこと）';
       command = 'mv .claude/hooks/x.ps1 .claude/hooks/x.ps1.bak'; expect = 'deny' }

    # --- ReDoS の番人（H-A。動詞と対象を [\s\S]* で繋いで O(n^2) になっていた）---
    # 🚨 これは「時間」ではなく「有界窓が効いていること」を検査している。
    #    動詞を並べたパディングは対象（.git/hooks）を含まないので allow が正しい。
    #    ここを [\s\S]* に戻すと、この入力でフックが数十秒ハングし、
    #    ホストのタイムアウト経由で fail open する（実測: 120KB で 84 秒）。
    @{ name = '動詞パディングは有界窓で素通り';    command = ('git status ' + ([string][char]114 + [string][char]109 + ' ') * 4000); expect = 'allow' }
    @{ name = '区切りを跨いだ同居は誤検知しない';  command = 'chmod +x scripts/build.sh && ls -la .git/hooks'; expect = 'allow' }

    # --- 種別ゲート自体を語中細工で抜ける（初回版から存在した穴。実測で確認）---
    # ゲートを生文字列だけで判定していたため、1文字挟むだけで
    # **検査に入る前に早期 exit** していた。$deescaped との OR で解消。
    @{ name = 'commit の語中に引用';               command = 'git c"o"mmit --no-verify -m x';    expect = 'deny' }
    @{ name = 'commit の語中に空変数展開';         command = 'git c${z}ommit --no-verify -m x';  expect = 'deny' }
    @{ name = 'commit の語中に空コマンド置換';     command = 'git c$()ommit --no-verify -m x';   expect = 'deny' }
    @{ name = 'git の語中に空変数展開';            command = 'g${z}it commit --no-verify -m x';  expect = 'deny' }
    @{ name = 'ゲートを抜けた先の短縮オプション';  command = 'git c${z}ommit -n -m x';           expect = 'deny' }

    # --- .git/hooks 検出も語中細工で抜けていた（H-4）-------------------------
    @{ name = 'hooks の語中に引用';                command = 'rm .git/hoo"k"s/pre-commit';       expect = 'deny' }
    @{ name = 'hooks の語中に空変数展開';          command = 'rm .git/hoo${x}ks/pre-commit';     expect = 'deny' }
    @{ name = 'git の語中に引用（パス側）';        command = 'rm .g"i"t/hooks/pre-commit';       expect = 'deny' }

    # --- 入れ子の深さで抜けられないこと（H-2。上限8のとき深さ9で素通りした）---
    # 🚨 ループ上限を「深さの上限」として使うと、上限そのものが境界になる。
    #    上限の引き上げと、展開記号を全除去したコピーの併用検査で解消。
    @{ name = '深さ12の入れ子コマンド置換';        command = ('git commit -m x --no-ver' + ('$(' * 12) + 'a' + (')' * 12) + 'ify'); expect = 'deny' }
    @{ name = '深さ12の入れ子（設定キー側）';      command = ('git config core.hooks' + ('$(' * 12) + 'a' + (')' * 12) + 'Path /dev/null'); expect = 'deny' }

    # --- ReDoS の番人 その2（git を並べたパディング。初回版から O(n^2) だった）---
    # 🚨 これは「時間」ではなく「共起判定に分解されていること」を検査している。
    #    ここを \bgit\b[\s\S]*\bcommit\b に戻すと、この入力でフックが数十秒ハングし、
    #    ホストのタイムアウト経由で fail open する（実測: 48KB で 25 秒 / 120KB で 308 秒）。
    #    commit を含まないので allow が正しい。
    @{ name = 'git パディングは共起判定で素通り';  command = ('git status ' + ('git ' * 4000));  expect = 'allow' }

    # --- ReDoS の番人 その3（置換の「残す」枝が伸びて収束しない）--------------
    # 🚨 $collapseSubst の残す枝で $m.Value をそのまま返すと毎回2文字伸び、
    #    不動点に到達せず 64 回すべて回り切る。
    #    実測: $(git commit) を3万個で 27 秒（通常 8ms の約3400倍）。
    #    外挿すると 1MB 前後でホストのフックタイムアウトを超え、
    #    **何も返らない＝許可**として fail open する。
    #    残す枝では $( ) を外して縮めること（次の反復で再マッチしないため収束する）。
    #    🚨 検査しているのは判定ではなく**有界時間で返ること**。返らなければテストが終わらない。
    #    判定は deny（語中に $( が並ぶ＝難読化の形であり、git 関連語を含むため）。
    @{ name = '置換の残す枝を並べても収束する';    command = ('$(git commit)' * 3000);            expect = 'deny'; knownGap = $true }

    # --- 巨大入力のガード（不動点ループは深さ×長さで効く）--------------------
    # 🚨 入れ子を並べた巨大入力は、ループを回すとホストのタイムアウトを超え、
    #    **何も返らない＝許可**として fail open する（1.19MB で 21 秒。実測）。
    #    閾値超過時は重いループを回さず O(n) 材料で判定し、
    #    git 関連なら **deny 側へ倒す**（検出できなかった≠安全）。
    @{ name = '巨大な入れ子＋git は deny（fail closed）';
       command = ('$(' * 63 + 'git commit' + ')' * 63) * 1500;                     expect = 'deny' }
    @{ name = '巨大でも git 無関係なら素通り';
       command = ('echo ' + ('$(' * 63 + 'a' + ')' * 63) * 1500);                  expect = 'allow' }
    @{ name = '閾値超えの git は解析せず deny';
       command = ('git status ' + ('x' * 70000));                                  expect = 'deny' }

    # --- 長いオプション連打で有界窓を溢れさせない（M-1。窓が狭いと後退する）---
    @{ name = '長いオプション連打でも hooks は deny'; command = ('rm ' + ('-v ' * 60) + '.git/hooks/pre-commit'); expect = 'deny' }

    # --- 有界窓をやめてセグメント共起にした（窓は攻撃者が埋められる境界だった）---
    # 🚨 ここを「動詞と対象の間の文字数制限」に戻さないこと。
    #    引用された区切りが1個あるだけで窓が切れ、距離を空けるだけでも抜けられる。
    @{ name = '引用された ; で窓を切る';           command = 'rm "a;b" .git/hooks/pre-commit';        expect = 'deny' }
    @{ name = '引用された | で窓を切る';           command = 'rm "a|b" .git/hooks/pre-commit';        expect = 'deny' }
    @{ name = '引用された & で窓を切る';           command = 'rm --preserve-root "x&y" .git/hooks/pre-commit'; expect = 'deny' }
    @{ name = '空白500個で距離を空ける';           command = ('rm' + (' ' * 500) + '.git/hooks/pre-commit');   expect = 'deny' }
    @{ name = 'オプション200個で距離を空ける';     command = ('rm ' + ('-v ' * 200) + '.git/hooks/pre-commit'); expect = 'deny' }

    # --- $segLoose の展開潰しを不動点まで繰り返す（1パスだと1段深くするだけで抜けた）---
    @{ name = '深さ2の入れ子で -n を逃がす';       command = 'git c$($())ommit -n -m x';              expect = 'deny' }
    @{ name = '深さ2の入れ子（git 側）';           command = 'g$($())it commit -n -m x';              expect = 'deny' }
    @{ name = '深さ12の入れ子で -n を逃がす';      command = ('git c' + ('$(' * 12) + 'a' + (')' * 12) + 'ommit -n -m x'); expect = 'deny' }

    # --- 区切り数が食い違ったときに fail open しないこと（$loose との添字対応）---
    # $segSource と $segLoose は未閉鎖展開の扱いが違うため要素数がずれうる。
    # ずれたら語の検出は $segLoose 全体で見る側（fail closed）に倒す。
    @{ name = '要素数がずれる入力（; 版）';        command = 'git commit -m $(x $(y) ; z) -n';        expect = 'deny' }
    @{ name = '要素数がずれる入力（| 版）';        command = 'git commit -m $(x $(y) | z) -n';        expect = 'deny' }
    @{ name = '要素数がずれる入力（結合クラスタ）'; command = 'git commit -m $(x $(y) ; z) -nm y';    expect = 'deny' }
    @{ name = '要素数がずれる入力（${} 版）';      command = 'git commit -m ${x${y};z} -n';           expect = 'deny' }

    # --- 隣接した空引用ペア（語中細工の中で最も落ちにくい形）-----------------
    # 挿入文字の隣がまた引用符だと、後読み/先読みを英数に絞った版では除去されず
    # 語を復元できなかった。クラスを絞らない＋$deescaped も分割対象に含めて解消。
    @{ name = '空引用ペアを挟んだ commit';         command = 'git c""ommit -n -m x';                  expect = 'deny' }
    @{ name = '空引用ペアを挟んだ commit（単一）'; command = "git c''ommit -nm x";                    expect = 'deny' }
    @{ name = '空引用ペアを挟んだ git';            command = 'g""it commit -n -m x';                  expect = 'deny' }
    @{ name = '空引用ペアを挟んだ hooks';          command = 'rm .git/hoo""ks/pre-commit';            expect = 'deny' }
    @{ name = '空引用ペアを挟んだ hooks（単一）'; command = "rm .git/hoo''ks/pre-commit";             expect = 'deny' }

    # --- コマンド置換の「内側にコマンド全体」が入る形 -------------------------
    # 🚨 既存の $() ケースはすべて「置換を語中の難読化に使い、実フラグは置換の外」
    #    という形だった（--no-ver$()ify 等）。コマンドとフラグが**まとめて置換の
    #    内側に入る**形は1件も無く、実測で素通りしていた。
    #    フラグ検査が「$() を中身ごと消した文字列」だけを材料にしていたため。
    @{ name = '置換の内側に commit 全体（代入）'; command = 'out=$(git commit --no-verify -m x)';     expect = 'deny' }
    @{ name = '置換の内側に commit 全体（代入なし）'; command = 'echo $(git commit --no-verify -m x)'; expect = 'deny' }
    @{ name = '置換の内側に短縮オプション';        command = 'out=$(git commit -nm x)';               expect = 'deny'; knownGap = $true }
    @{ name = '置換の内側に push';                 command = 'echo $(git push --no-verify)';          expect = 'deny' }
    @{ name = '変数展開の内側に commit 全体';      command = 'echo ${x:-git commit --no-verify -m y}'; expect = 'deny' }
    @{ name = 'バッククォート置換の内側';          command = 'out=`git commit --no-verify -m x`';     expect = 'deny' }

    # 🚨 「語中細工 × 置換の内側」の組み合わせ。
    #    片方ずつは塞がっていたが、重ねると全経路が抜けた（実測）。
    #    語の復元を引用潰しより前に置かないと、c"o"mmit が `c mmit` に割れて
    #    種別ゲートで早期 exit する。
    @{ name = '置換の内側＋語中引用';              command = 'out=$(git c"o"mmit --no-verify -m x)';  expect = 'deny' }
    @{ name = '置換の内側＋語中引用（引用付き）'; command = 'echo "$(git c"o"mmit --no-verify -m x)"'; expect = 'deny' }
    @{ name = '変数展開の内側＋語中引用';          command = 'echo ${x:-git c"o"mmit --no-verify -m x}'; expect = 'deny' }
    @{ name = 'ラッパー内の置換＋語中引用';        command = "sh -c '`$(git c`"o`"mmit --no-verify -m x)'"; expect = 'deny' }
    @{ name = '置換の内側＋語中引用（短縮）';      command = 'out=$(git c"o"mmit -nm x)';             expect = 'deny'; knownGap = $true }
    @{ name = '置換の内側＋語中引用（hooks破壊）'; command = 'out=$(rm .git/hoo"k"s/pre-commit)';     expect = 'deny' }

    # 🚨 語中細工は引用だけではない。**空展開でも語が割れる**。
    #    引用版だけ塞いだ状態では、1文字を ${z} / $() にするだけで全経路が抜けた（実測）。
    @{ name = '置換の内側＋語中空変数';            command = 'out=$(git c${z}ommit --no-verify -m x)'; expect = 'deny' }
    @{ name = '置換の内側＋語中空置換';            command = 'out=$(git c$()ommit --no-verify -m x)'; expect = 'deny' }
    @{ name = '置換の内側＋入れ子の空置換';        command = 'out=$(git c$($())ommit -nm x)';        expect = 'deny'; knownGap = $true }
    @{ name = '変数展開の内側＋語中空変数';        command = 'echo ${x:-git c${z}ommit --no-verify -m y}'; expect = 'deny' }
    @{ name = '引用付き置換＋語中空置換';          command = 'echo "$(git c$()ommit --no-verify -m x)"'; expect = 'deny' }

    # 🚨 push も種別ゲートの対象。commit だけで判定すると引用でくくるだけで抜ける。
    @{ name = '引用付き置換の内側に push';         command = 'echo "$(git push --no-verify)"';        expect = 'deny' }
    @{ name = 'ラッパー内の置換に push';           command = "sh -c '`$(git push --no-verify)'";      expect = 'deny' }

    # 🚨 フック無効化系（core.hooksPath / .git/hooks）も置換の内側に隠せる。
    #    設定は .git/config に永続化されるため、以後の全コミットが迂回される。
    @{ name = '置換の内側に hooksPath＋語中引用'; command = 'out=$(git config core.hooks"P"ath /dev/null)'; expect = 'deny' }
    @{ name = '置換の内側に hooksPath＋空変数';   command = 'out=$(git config core.hooks${x}Path /dev/null)'; expect = 'deny' }
    @{ name = '置換の内側に hooks 破壊＋空変数'; command = 'out=$(rm .git/hoo${x}ks/pre-commit)';   expect = 'deny' }

    # 🚨 空白を含む「空展開」でも語は繋がる。構文の見た目で判定すると穴が開く。
    #    bash で実際に実行して git へ commit として届くことを確認済み。
    @{ name = '語中に $( ) を挟む';                command = 'git c$( )ommit --no-verify -m x';       expect = 'deny' }
    @{ name = '語中に $(echo ) を挟む';            command = 'git commit -$(echo )nm x';              expect = 'deny'; knownGap = $true }
    @{ name = '語中に $( : ) を挟む（置換の内側）'; command = 'out=$(git c$( : )ommit --no-verify -m x)'; expect = 'deny' }
    @{ name = '語中に空単一引用 $'''' を挟む';     command = "out=`$(git c`$''ommit --no-verify -m x)"; expect = 'deny' }
    @{ name = '$( ) で hooksPath を割る';          command = 'out=$(git config core.hooks$( )Path /dev/null)'; expect = 'deny' }
    @{ name = '$( ) で hooks 破壊を割る';          command = 'out=$(rm .git/hoo$( )ks/pre-commit)';   expect = 'deny' }

    # 🚨 行継続（バックスラッシュ＋改行）はシェルがパース前に削除する。
    #    語の途中で改行するだけで全経路を抜けられた（bash で実測）。
    @{ name = '行継続で commit を割る';            command = "git c\`nommit --no-verify -m x";        expect = 'deny' }
    @{ name = '行継続でフラグを割る';              command = "git commit --no-ver\`nify -m x";        expect = 'deny' }
    @{ name = '行継続で短縮オプションを割る';      command = "git commit -\`nn -m x";                 expect = 'deny' }
    @{ name = '行継続で hooksPath を割る';         command = "git config core.hooks\`nPath /dev/null"; expect = 'deny' }
    @{ name = '行継続で hooks 破壊を割る';         command = "rm .git/hoo\`nks/pre-commit";           expect = 'deny' }

    # 🚨 ANSI-C クォート $'...' は**除去では語が戻らない**。デコードが要る。
    @{ name = 'ANSI-C クォートで commit を割る';   command = "git c`$'\x6f'mmit --no-verify -m x";    expect = 'deny'; knownGap = $true }
    @{ name = 'ANSI-C クォートで hooksPath を割る'; command = "git config core.hooks`$'\x50'ath /dev/null"; expect = 'deny'; knownGap = $true }
    @{ name = 'ANSI-C クォートで hooks 破壊';      command = "rm .git/hoo`$'\x6b's/pre-commit";       expect = 'deny'; knownGap = $true }

    # 🚨 4回目のレビューで実測された素通り（bash で本当に届くことを確認済み）。
    #    いずれも「語を割る構文」の新しい種類であり、列挙では追いつかないことの証拠。
    #    設計を反転させ、**語中の難読化そのもの**を deny 条件にして塞いだ。
    @{ name = 'バッククォートで commit を割る';    command = 'git c`true`ommit --no-verify -m x';      expect = 'deny'; knownGap = $true }
    @{ name = 'バッククォートで git を割る';       command = 'g`true`it commit --no-verify -m x';      expect = 'deny'; knownGap = $true }
    @{ name = 'バッククォートで hooksPath を割る'; command = 'git config core.hooks`true`Path /dev/null'; expect = 'deny'; knownGap = $true }
    @{ name = 'バッククォートで hooks 破壊';       command = 'rm .git/hoo`true`ks/pre-commit';        expect = 'deny'; knownGap = $true }
    @{ name = 'ANSI-C \u で commit を割る';        command = "git c`$'o'mmit --no-verify -m x";  expect = 'deny' }
    @{ name = 'ANSI-C \U で commit を割る';        command = "git c`$'\U0000006f'mmit --no-verify -m x"; expect = 'deny'; knownGap = $true }
    @{ name = '位置パラメータ $1 で割る';          command = 'git c$1ommit --no-verify -m x';         expect = 'deny'; knownGap = $true }
    @{ name = '特殊パラメータ $* で割る';          command = 'git c$*ommit -nm x';                    expect = 'deny'; knownGap = $true }
    @{ name = '位置パラメータで hooksPath を割る'; command = 'git config core.hooks$1Path /dev/null'; expect = 'deny'; knownGap = $true }
    @{ name = 'ANSI-C で短縮オプションを割る';     command = "git commit -`$'\x6e' -m x";             expect = 'deny'; knownGap = $true }
    @{ name = '引用で短縮オプションを割る';        command = 'git commit "-"n -m x';                  expect = 'deny'; knownGap = $true }
    @{ name = '引用で短縮オプションを割る（単一）'; command = "git commit '-'nm x";                   expect = 'deny'; knownGap = $true }

    # 🚨 誤検知の番人。置換を**引数として**使う正当な形を deny にしない。
    #    置換の中身を無条件に残すと、head -n の -n を git のものとして拾う（実測）。
    @{ name = '引数の置換内の -n は素通り';        command = 'git commit -m x $(head -n 20 log.txt)'; expect = 'allow' }
    @{ name = '引数の置換内の -n（引用付き）';     command = 'git commit -m x "$(head -n 20 log.txt)"'; expect = 'allow' }

    # 🚨 難読化を deny 条件にしたことで壊れやすい形。ここが崩れると実用に耐えない。
    #    語頭から始まる引用は**メッセージ本文**であり、その内側は難読化ではない。
    @{ name = 'Windows パスの語中バックスラッシュ'; command = 'git add C:\tmp\a.txt && git commit -m x'; expect = 'allow' }
    @{ name = '本文中のアポストロフィ';            command = "git commit -m ""fix it's bug""";        expect = 'allow' }
    @{ name = '本文中のドル記号';                  command = 'git commit -m "cost is $5 total"';      expect = 'allow' }
    @{ name = '語頭の置換を引数に使う';            command = 'git commit -m "release $(date -I)"';    expect = 'allow' }
    @{ name = 'ラッパー内のメッセージ（既存形）';  command = 'bash -c "git commit -m ''fix bug''"';   expect = 'allow' }

    # --- .git/hooks の境界（\b だと別ディレクトリまで巻き込む）---------------
    @{ name = 'hooks-backup は別物なので素通り';   command = 'cp -r .git/hooks-backup restore/';      expect = 'allow' }
    @{ name = 'バックアップ目的の読み取りは素通り'; command = 'cat .git/hooks/pre-commit > backup.txt'; expect = 'allow' }
    @{ name = '一覧のリダイレクトは素通り';        command = 'ls -la .git/hooks > /tmp/list.txt';     expect = 'allow' }
)

$failed = 0

$gaps = 0

foreach ($case in $cases) {
    $payload = @{ tool_input = @{ command = $case.command } } | ConvertTo-Json -Compress
    $output = $payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $hookPath
    $actual = if ([string]::IsNullOrWhiteSpace($output)) { 'allow' } else { 'deny' }

    # 🚨 knownGap = 塞げていないと**分かっている**バイパス。
    #    文字列マッチ方式では原理的に塞げず、塞ごうとすると誤検知が実用を壊す
    #    （5回のセキュリティレビューで確認。詳細は
    #     .steering/20260829-hook-cmdsubst-bypass/retrospective.md）。
    #    テストを消さずに残すのは、①どの形が通るかを記録に残すため、
    #    ②将来塞げたときに気づけるようにするため。
    if ($case.knownGap) {
        if ($actual -eq 'allow') {
            Write-Output ("GAP : {0} -> allow (既知の穴。塞げていない)" -f $case.name)
            $gaps++
        } else {
            Write-Output ("改善: {0} -> deny (塞がった。knownGap を外して expect='deny' にすること)" -f $case.name)
            $failed++
        }
        continue
    }

    if ($actual -eq $case.expect) {
        Write-Output ("PASS: {0} -> {1}" -f $case.name, $actual)
    } else {
        Write-Output ("FAIL: {0} -> {1} (期待: {2})" -f $case.name, $actual, $case.expect)
        $failed++
    }
}

# --- 異常入力で誤ブロックしないこと ------------------------------------------
foreach ($bad in @('', 'not-json', '{}', '{"tool_input":{}}')) {
    $output = $bad | & powershell -NoProfile -ExecutionPolicy Bypass -File $hookPath
    if ([string]::IsNullOrWhiteSpace($output)) {
        Write-Output ("PASS: 異常入力で素通り ({0})" -f $(if ($bad -eq '') { '空文字' } else { $bad }))
    } else {
        Write-Output ("FAIL: 異常入力で誤ブロックした ({0})" -f $bad)
        $failed++
    }
}

Write-Output ""
if ($gaps -gt 0) {
    Write-Output ("既知の穴: {0}件（塞げていないバイパス。文字列マッチ方式の限界）" -f $gaps)
    Write-Output "  → 本フックは多層防御の1枚であり、単独で保証を与えるものではない。"
    Write-Output "     実 pre-commit フック / core.hooksPath の保護と併用すること。"
    Write-Output ""
}
if ($failed -eq 0) {
    Write-Output "全テスト成功"
    exit 0
} else {
    Write-Output ("失敗: {0}件" -f $failed)
    exit 1
}
