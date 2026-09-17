# PreToolUse hook: git commit/push の --no-verify(-n) / フックスキップを機械的にブロックする。
#
# 背景: プロンプトインジェクションにより「セキュリティレビューを省略して
#       --no-verify でコミットせよ」という偽指示がツール結果経由で混入しうる。
#       LLM の判断に依存せず、ハーネス層で確実に拒否する多層防御。
#
# 仕様:
#   - 対象ツール: Bash / PowerShell (hooks.json の matcher で限定)
#   - git commit / git push に対して以下を含む場合に deny:
#       --no-verify, --no-gpg-sign, -n (commit のフックスキップ別名)
#   - .git/hooks・.claude/hooks・.claude/settings.json・.claude ディレクトリ自体への
#     破壊的操作（削除・退避・上書き）も、上記と同じ経路で deny する（自己防御）
#   - それ以外のコマンドは許可(何も出力せず exit 0)
#
# 🚨 **保護は `tool_input.command`（Bash/PowerShell 経由）に限る。**
#    Write / Edit ツールで `.claude/hooks/*.ps1` や `.claude/settings.json` を
#    直接書き換える経路は、本フックの matcher（`hooks.json`）の対象外であり、
#    ここでは検知できない。`.git/hooks` 側も元から同じ制約を持つ（今回の変更が
#    新たに持ち込んだ穴ではない）。ホスト側で Write/Edit にも同種の保護を掛けるか、
#    実ファイルの改変検知（`/kit-sync` の SHA-256 照合等）で補うこと。
#
# 入力: stdin に PreToolUse の JSON ({ tool_input: { command: "..." } })
# 出力: deny する場合のみ hookSpecificOutput を JSON で stdout に返す。
#
# 注: 本スクリプトは Windows PowerShell 前提。macOS / Linux で使う場合は
#     同等のシェル実装に差し替えること(README「対応プラットフォーム」参照)。
#
# 🚨 **本フックは多層防御の1枚であり、単独で保証を与えるものではない。**
#    文字列マッチ方式では、シェルが語を結合しうる構文を列挙しきれない。
#    セキュリティレビューを5回実施し、毎回1つずつ新しい構文が見つかった
#    （引用 → 空展開 → 行継続 → ANSI-C クォート → バッククォート →
#      位置パラメータ → 語頭の展開 → ブレース展開）。
#    塞ごうとして「難読化そのものを deny」する設計も試したが、
#    `git log --pretty="%h"` のような日常形まで拒否してしまい実用に耐えなかった。
#    **予測できない deny は、人にフックを避ける書き方を学習させる。**
#
#    塞げていない形は tests/test-block-no-verify.ps1 に knownGap として
#    記録してある（テスト実行時に件数が表示される）。
#
#    本当の担保は次に置くこと:
#      - リポジトリ側の実 pre-commit / pre-push フック
#      - core.hooksPath の保護
#      - 実 argv を見る git ラッパー

$ErrorActionPreference = 'Stop'

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $payload = $raw | ConvertFrom-Json
    $command = [string]$payload.tool_input.command
} catch {
    # 解析できない場合は判断を保留し、通常フローに委ねる(誤ブロックを避ける)
    exit 0
}

if ([string]::IsNullOrWhiteSpace($command)) { exit 0 }

# --- 正規化 ------------------------------------------------------------------
# シェル / PowerShell のエスケープを除去する。いずれも git には --no-verify として届くため、
# 除去しないと1文字挟むだけで検査をすり抜けられる。
#   PowerShell: --no-ver`ify / bash: --no-\verify / 語中の引用連結: --no-ve"r"ify
# 🚨 行継続（バックスラッシュ＋改行）は**シェルがパース前に削除する**。
#    ここで落とさないと、語の途中で改行するだけで検査を抜けられる（bash で実測）。
$normalized = ($command -replace '`', '') -replace '\\\r?\n', ''

# --- 保護対象パス（.git/hooks と本フック自身の実行資産）---------------------
# 🚨 定義はここ1箇所にまとめ、下の $gitish（巨大入力の打ち切り判定）・$keepInner
#    （置換内側の保持判定）・末尾のタンパー検出ループの3箇所すべてから参照する。
#    1箇所にしか反映されないと、他の箇所で早期 exit や証拠の消去が起き、
#    保護が骨抜きになる（実測: 64KB 超のパディングで打ち切り判定に届かず素通り、
#    コマンド置換の内側では中身ごと消えて素通り）。
#
# 🚨 末尾は `\b` ではなく区切りか終端にする。`\b` は `-` の直前でも成立するため、
#    .git/hooks-backup のような別ディレクトリまで巻き込む。引用符も終端に含める
#    （`rm ".claude/settings.json"` のように引用符1文字でアンカーが外れた。実測）。
$hooksPath    = '(?i)\.git[\\/]hooks([\\/]|\s|$)'
# `.claude/hooks/` と `.claude/settings.json` は本フックの実行資産そのもの。
# 上書き・削除の両方が「① 強制機構を消す → ② 普通にコミットする」の攻撃経路になる。
$selfFilePath = '(?i)\.claude[\\/](hooks([\\/]|["'']|\s|$)|settings\.json(["'']|\s|$))'
# `.claude` ディレクトリ自体（配下ではなく親）を丸ごと消す・退避することでも
# 上と同じ実行資産が失われる。ただし配下には `.claude/skills/` のような
# 「破壊系動詞以外でも日常的に読み書きする場所」も含むため、ここだけは
# 動詞を破壊系（削除・移動・改名）に絞る（下の $hooksVerbDir）。
$selfDirPath  = '(?i)\.claude(["'']|[\\/]|\s|$)'
$protectedPath = "$hooksPath|$selfFilePath|$selfDirPath"

# --- 巨大入力の打ち切り ------------------------------------------------------
# 「git 関連らしさ」の判定。以降の重いループを回す前に使う O(n) の検査。
$gitish = "(?i)(\bgit\b|\bcommit\b|\bpush\b|core\.hooksPath|GIT_CONFIG_KEY_|$protectedPath)"
$isGitish = ($normalized -match $gitish) -or ($command -match $gitish)

# 🚨 巨大入力では以降の不動点ループが「深さ×長さ」で効き、
#    ホストのフックタイムアウト（既定60秒）を超えて **fail open** する
#    （入れ子 4MB で 55 秒。実測）。閾値を超えたらループを回さず、
#    O(n) の判定だけで決める。git 関連なら deny 側へ倒す（解釈できない≠安全）。
if ($normalized.Length -gt 65536) {
    if ($isGitish) {
        $reason = 'git 関連のコマンドが大きすぎて安全に解析できません（64KB 超）。' +
                  '難読化による検査回避を防ぐため、ハーネス層でブロックしました。' +
                  'コマンドを分割するか、スクリプトファイルに書いて実行してください。'
        $out = @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'
                  permissionDecision = 'deny'; permissionDecisionReason = $reason } }
        $out | ConvertTo-Json -Depth 5 -Compress
    }
    exit 0
}

$deescaped  = $normalized -replace '(?<=\S)[\\"''](?=\S)', ''   # フラグ検査専用
# シェルが**空文字へ展開する**構文も語中から除去する。引用やバックスラッシュと
# 違い1文字ではないため、上の除去では落ちない。git には --no-verify として届く:
#   --no-ver${q}ify （q 未定義）/ --no-ver$()ify
# 🚨 ここは空白ではなく**空文字**へ潰すこと。空白にすると語が分割され、
#    前方一致の検査に掛からなくなる（セグメント分割用の $segSource とは逆）。
#
# 🚨 入れ子に対応するため、変化がなくなるまで繰り返す。
#      --no-ver$(echo $(true))ify → bash では内側から評価されて最終的に空文字になり、
#                                    git にはフラグとして届く
#
#    🚨 内側を除外する `[^()]*` を使い、**内側から**消すこと。
#       `[^)]*` だと最初の `$(` から最初の `)` までを食ってしまい、
#       余った `)` が語中に残って前方一致の境界クラスを壊す
#       （--no-ver)ify になり、繰り返しても消えない。実測で素通りを確認した）。
#
#    ループは上限が無くても必ず停止する（1回の置換で最低3文字は短くなるため、
#    変化なしの break に必ず到達する）。上限は計算量の保険であって、
#    **深さの上限として使ってはならない** — 上限そのものが境界になり、
#    それを1段超えるだけで抜けられる（上限8のとき深さ9で素通りした。実測）。
#
# 🚨 **中身にコマンドが入っている置換は消してはならない。**
#    語中の難読化（--no-ver$()ify）を潰すのが目的だが、
#    置換の内側にコマンドごと入っている形では、消すと**証拠のほうが消える**:
#      out=$(git commit --no-verify -m x) → "out=" になり素通りした（実測）
#    中身を残せば、以降の検査がそのまま効く。
#    残すときは囲みを外して縮める（外さないと毎回伸びて不動点に到達せず、
#    巨大入力でタイムアウト経由の fail open を招く。実測で 27 秒）。
$keepInner = {
    param($v)
    ($v -match '(?i)\bgit\b') -or ($v -match '(?i)\bcommit\b') -or ($v -match '(?i)\bpush\b') -or
    ($v -match '(?i)core\.hooksPath') -or ($v -match '(?i)GIT_CONFIG_KEY_') -or ($v -match $protectedPath)
}
for ($i = 0; $i -lt 64; $i++) {
    $before    = $deescaped
    $deescaped = [regex]::Replace($deescaped, '\$\([^()]*\)|\$\{[^{}]*\}', {
        param($m)
        if (& $keepInner $m.Value) { ' ' + $m.Value.Substring(2, $m.Value.Length - 3) + ' ' } else { '' }
    })
    if ($deescaped -eq $before) { break }
}
# 上限に達してもまだ変化していた場合の保険。展開記号を全部落としたコピーも併せて検査する。
# 深さに依存せず O(n) で、この系統の細工を根で潰せる。
# 記号を落とすだけなので、正当なコマンドが余計に deny 側へ倒れることは実質ない。
#
# 🚨 連結は**区切り文字**で行うこと。空白で繋ぐと、1本目の末尾セグメントと
#    2本目の先頭セグメントが融合し、セグメント単位の共起判定が誤爆する
#    （grep -n p f && git commit -m x が deny になった。実測）。
$deescaped = $deescaped + ' ; ' + ($deescaped -replace '[$(){}]', '')

# --- 引用区間の潰し方 --------------------------------------------------------
# 🚨 メッセージ本文だけを潰し、入れ子のコマンドは残す。
#
# 全部を一律に潰すと bash -c "git commit -n -m x" の -n を見失う。
# これは $isCommit を $stripped で判定していたときの穴（全体が引用に包まれると
# git も commit も消える）と**同じ構造**であり、短縮オプション側にだけ残っていた。
#
# 🚨 生文字列と $deescaped の両方に同じ処理を掛けるため、手続きを1箇所に持つ。
#    片方にしか掛けないと、語中に1文字挟んだ commit が短縮オプション検査に届かない
#    （git c${z}ommit -n -m x が素通りした。実測）。
#    なお $deescaped の語中エスケープ除去は「両側が非空白」の場合だけなので、
#    メッセージを囲む引用（前後が空白）は残る。ここに掛けても本文の潰しは壊れない。
$collapseQuotes = {
    param($text)
    [regex]::Replace($text, '"[^"]*"|''[^'']*''', {
        param($m)
        # 共起判定にする理由は下の種別ゲートと同じ（`[\s\S]*` は O(n^2) になる）。
        if (($m.Value -match '(?i)\bgit\b') -and ($m.Value -match '(?i)\bcommit\b')) {
            # 入れ子コマンド: 外側の引用だけ外し、内側（＝本当のメッセージ）は潰す
            $inner = $m.Value.Substring(1, $m.Value.Length - 2)
            ' ' + [regex]::Replace($inner, '"[^"]*"|''[^'']*''', ' ') + ' '
        } else { ' ' }
    })
}
$stripped = & $collapseQuotes $normalized

# --- セグメント分割用の文字列を作る ------------------------------------------
# 区切り（; & |）で分割して「同じコマンド内か」を見るための材料。
# フック無効化の検出（種別ゲートより前）でも使うため、ここで用意しておく。
#
# 🚨 3本用意して**すべてを検査する**（union なので fail closed 側）。
#    1本では必ずどれかを取りこぼす:
#      $stripped … 引用は潰れているが、エスケープされた区切りが境界を偽装しうる。
#                  Windows 形式の `.git\hooks` が唯一そのまま残るのはここだけ
#      $segSource … エスケープ・展開を**空白**へ潰す。区切り偽装に強いが、
#                   語が割れる（git c${z}ommit → git c ommit）
#      $segLoose  … 同じ材料を**空文字**へ潰して語を復元する。区切り数は保つ
$toSegSource = {
    param($text)
    $s = $text -replace '\\.', ' '            # バックスラッシュエスケープ
    $s = $s -replace '\$\([^)]*\)', ' '       # コマンド置換 $( )
    $s = $s -replace '\$\{[^}]*\}', ' '       # 変数展開 ${ }
    # 閉じられていない置換・展開が残る場合は境界を信頼できないため分割しない(fail closed)
    if ($s -match '\$\(|\$\{') { $s = $s -replace '[;&|]', ' ' }
    $s
}
$segSource = & $toSegSource $stripped

# 🚨 $segLoose は $stripped ではなく**生文字列から**作る。
#    $stripped は引用区間を潰し済みなので、パスや語の途中に置かれた引用も
#    先に消えてしまい、語を復元できない（rm .git/hoo"k"s/pre-commit が素通りした。実測）。
#
# 🚨 語中の引用除去のクラスを絞らないこと。
#    英数だけに絞ると、挿入文字の**隣がまた引用符**のとき後読み／先読みが外れて除去されず、
#    語を復元できない（git c""ommit -n -m x / rm .git/hoo""ks/pre-commit が素通りした。実測）。
#    絞った動機は「メッセージ本文を閉じる引用まで落ちて本文中の -n を誤検知する」だったが、
#    $looseBase を生文字列から作り $collapseQuotes を後段に置く現在の順序では再現しない
#    （回帰テストの『ラッパー内のメッセージ本文の -n』が番人になっている）。
$looseBase = $normalized -replace '(?<=\S)["''\\](?=\S)', ''
$segLoose  = & $collapseQuotes $looseBase
$segLoose  = $segLoose -replace '\\([;&|])', ' '             # エスケープされた区切りは境界にしない
# 🚨 展開の除去は**不動点まで繰り返す**。1パスだと入れ子を1段深くするだけで抜けられる
#    （git c$($())ommit -n -m x が素通りした。実測）。
#    $deescaped 側だけに繰り返しを入れて、こちらに入れ忘れたのが原因だった。
for ($i = 0; $i -lt 64; $i++) {
    $before   = $segLoose
    $segLoose = $segLoose -replace '\$\([^()]*\)', '' -replace '\$\{[^{}]*\}', ''
    if ($segLoose -eq $before) { break }
}
if ($segLoose -match '\$\(|\$\{') { $segLoose = $segLoose -replace '[;&|]', ' ' }

#      $deescaped … フラグ検査用に作った版。語中の細工が最も強く落ちているので、
#                   隣接した空引用ペア（.git/hoo""ks）のような形はここでしか復元されない
$segSets = @(($stripped  -split '[;&|]'), ($segSource -split '[;&|]'),
             ($segLoose  -split '[;&|]'), ($deescaped -split '[;&|]'))

# --- 対象コマンドの判定 ------------------------------------------------------
# 🚨 判定は必ず「生文字列($normalized)」で行う。
#
# 引用を剥がした $stripped で判定すると、コマンド全体が引用で包まれた形
#   bash -c "git commit --no-verify -m x"
#   eval "git commit --no-verify -m x"
# では git も commit も丸ごと消え、「git コマンドではない」と誤認して
# **早期 exit し、検査そのものが行われない**。
# 実測で素通りを確認した回避経路であり、ここを $stripped に戻してはならない。
#
# commit と push は区別する。push の -n は --dry-run であり無害なため、
# 短縮フラグ検査は commit にのみ適用する。
#
# 🚨 語の連結に `[\s\S]*` を使わない。**共起判定に分解する。**
#    `\bgit\b[\s\S]*\bcommit\b` は、commit を含まない入力に対して git の出現数ぶん
#    末尾まで走査し **O(n^2)** になる。コミットメッセージに git を並べて詰めるだけで
#    フックが数分ハングし、ホストのタイムアウト経由で fail open する
#    （実測: 48KB で 25 秒 / 120KB で 308 秒。通常は 8ms）。
#    順序を見ない共起判定は意味的にほぼ等価で、しかも線形。
#    順序を落とすぶん判定は広がる側（fail closed）に倒れる。
#
# 🚨 $normalized だけでなく $deescaped でも見る。
#    生文字列だけだと語中に1文字挟むだけでゲートを抜け、**検査に入る前に早期 exit** する:
#      git c"o"mmit --no-verify -m x / g${z}it commit --no-verify -m x
#    どちらも bash では git commit --no-verify として実行される（実測で素通りを確認）。
#    $stripped を使ってはならない理由は上のとおりで、それとは別の話である。
$hasGitWord = ($normalized -match '(?i)\bgit\b')    -or ($deescaped -match '(?i)\bgit\b')
$isCommit   = $hasGitWord -and (($normalized -match '(?i)\bcommit\b') -or ($deescaped -match '(?i)\bcommit\b'))
$isPush     = $hasGitWord -and (($normalized -match '(?i)\bpush\b')   -or ($deescaped -match '(?i)\bpush\b'))

# --- フック無効化そのものの検出（種別ゲートより前に置く）---------------------
# 🚨 この検査は下の早期 exit より**前**に置かなければならない。
#
# core.hooksPath の差し替えや .git/hooks の削除は、そのコマンド自体には
# commit も push も含まれない。ゲートの後ろに置くと早期 exit で**検査されない**。
# しかも設定は .git/config に永続化されるため、以後の「見た目は普通の」
# コミットがすべてフックを迂回する。**2ターンに分けるだけで無効化できる**:
#   ① git config core.hooksPath /dev/null   ← 旧実装は素通りした
#   ② git commit -m x                       ← 以後フックは一切走らない
# 「まず設定を直してからコミットして」という誘導は、インジェクションの形として
# 極めて自然であり、本フックが想定する脅威そのものである。
#
# 🚨 設定キーの検査は $deescaped（引用・エスケープ・空展開を除去済み）で行う。
#    $normalized だけで見ると、--no-verify 側で塞いだのと**同じ細工**が
#    そのまま通る（実測で素通りを確認した回避経路）:
#      core.hooks"P"ath / core.hooks${x}Path / core.hooks\Path
#    $normalized 側も併せて見るのは、除去が逆に語を繋げてしまう形を取りこぼさないため。
$disableKeys   = '(?i)(core\.hooksPath|GIT_CONFIG_KEY_|--config-env|commit\.gpgsign[\s=]+false|\bHUSKY[\s=]+0)'
$hasDisableKey = ($deescaped -match $disableKeys) -or ($normalized -match $disableKeys)

# .git/hooks 自体への破壊的操作。
#
# 🚨 動詞と対象の間を `[\s\S]*` で繋がないこと。
#    対象を含まない入力では、動詞の出現数ぶん末尾まで走査して **O(n^2)** になる。
#    実測: 動詞を並べただけのパディングを後ろに付けると、120KB でフックが 84 秒
#    ハングした（通常 8ms）。ホスト側のタイムアウトを超えれば判定が返らず、
#    **何も言わなかった＝許可**として fail open する。
#    防御を足すために書いた正規表現が、防御そのものを無効化する形だった。
#
#    区切り文字を含まない**有界窓**に限定して線形に保つ。セグメント内に限る効果もあり、
#    `chmod +x scripts/build.sh && ls -la .git/hooks` のような無関係な同居を誤検知しない。
#    動詞の列挙だけでは網羅できない（cp / ln / sed / リダイレクト等）ため、
#    リダイレクト `>` も対象に含める。
# 🚨 $normalized と $deescaped の**両方**で見る。片方では取りこぼす:
#    - $deescaped だけ … 語中のバックスラッシュを除去するため、Windows 形式の
#      `.git\hooks` が `.githooks` に化けて検出できない
#    - $normalized だけ … 語中に1文字挟むだけで抜ける
#      （rm .git/hoo"k"s/pre-commit / rm .git/hoo${x}ks/pre-commit。実測で素通りを確認）
#    設定キー側（$hasDisableKey）と同じ扱いに揃える。片方だけ強化すると、
#    同じ細工が隣の検査に残る — これを繰り返した。
#
# 🚨 有界窓（動詞と対象の間の文字数制限）で判定してはならない。
#    窓は「攻撃者が自由に埋められる境界」であり、しかも引用された区切りが
#    1個あるだけで切れる。実測で素通りした形:
#      rm "a;b" .git/hooks/pre-commit / rm + 空白500個 + .git/hooks/pre-commit
#    セグメント内の**共起判定**にすれば、窓も引用偽装も消えて線形のままになる。
# 🚨 リダイレクト `>` を動詞の選択肢に混ぜないこと。
#    共起判定は順序を見ないため、**パスより後ろ**のリダイレクトまで拾ってしまい、
#    `cat .git/hooks/pre-commit > backup.txt`（編集前のバックアップ）や
#    `ls -la .git/hooks > list.txt` という正当な操作を潰す。
#    リダイレクトだけは「パスより前にあること」を位置で確かめる（下記）。
#
# 🚨 動詞は POSIX 形だけでは足りない。本フックは PowerShell も対象にしているのに、
#    回帰テストは POSIX 形しか無く、PowerShell ネイティブの動詞
#    （`Remove-Item` とその別名 `ri` 等）や cmd.exe 系（`del` 等）は1件もカバーしていなかった。
#    Windows 実務で `.git/hooks` を消す・上書きするコマンドは、むしろこちら側で書かれる。
#
# 🚨 2文字の PowerShell エイリアス（`ri` / `ac` 等）は、位置を縛らずに `\b` だけで
#    見ると通常のオプションクラスタに誤爆する。`-` は `\b` の境界を作るため、
#    `grep -ri` の `-ri` が「rm の別名 ri」と誤認され、読み取り専用コマンドを
#    deny してしまう（実測）。**直前が `-` でないこと**を条件に加える。
$hooksVerb = '(?i)(\b(rm|rmdir|mv|cp|ln|sed|chmod|chown|truncate|install|tee|dd|find|del|erase|move|copy|ren|rd|attrib)\b' +
             '|\b(Add|Remove|Move|Copy|Set|Clear|New|Rename|Out)-(Item|Content|File|ItemProperty)\b' +
             '|(?<!-)\b(ri|rni|cpi|mi|ni|sc|ac|nal|clc|sp)\b)'
# 🚨 `.claude/hooks`・`.claude/settings.json` は上と同じ動詞集合を使わない。
#    `find`/`sed`/`install`/`tee`/`dd` は、kit-sync 自身の検証手順
#    （`find .claude/hooks -type f -exec sha256sum {} \;`）や設定の読み取りにも
#    現れる読み取り寄りの動詞であり、`.git/hooks`（触る用事がほぼ無い）と違って
#    ここは日常的に検証・参照される（実測。予測できない deny は、
#    人にフックを避ける書き方を学習させる）。削除・上書き系だけに絞る。
$hooksVerbSelf = '(?i)(\b(rm|rmdir|mv|cp|ln|chmod|chown|truncate|del|erase|move|copy|ren|rd|attrib)\b' +
                 '|\b(Add|Remove|Move|Copy|Set|Clear|New|Rename|Out)-(Item|Content|File|ItemProperty)\b' +
                 '|(?<!-)\b(ri|rni|cpi|mi|ni|sc|ac|nal|clc|sp)\b)'
# 🚨 `.claude` ディレクトリ（配下ではなく親）向けは、さらに絞る。
#    `.claude/skills/` のような**日常的に読み書きする場所**を配下に含むため、
#    `cp`/`New-Item`/`Copy-Item`/`Set-Content` まで deny すると、
#    `.claude/skills` へのスキル配置（junction 作成・スタブの複製）まで潰してしまう。
#    ここは**削除・移動・改名**という、配下の中身に関係なく被害が及ぶ動詞だけに絞る。
$hooksVerbDir = '(?i)(\b(rm|rmdir|mv|move|ren|rd|del|erase|truncate|chmod|chown|attrib)\b' +
                '|\b(Remove|Move|Rename)-Item\b' +
                '|(?<!-)\b(ri|rni|mi)\b)'
$hasHooksTamper = $false
foreach ($segs in $segSets) {
    foreach ($seg in $segs) {
        # .git/hooks は触る用事がほぼ無いため、動詞を広く見る。
        $mHooks = [regex]::Match($seg, $hooksPath)
        if ($mHooks.Success) {
            if ($seg -match $hooksVerb) { $hasHooksTamper = $true; break }
            $gt = $seg.IndexOf('>')
            if ($gt -ge 0 -and $gt -lt $mHooks.Index) { $hasHooksTamper = $true; break }
        }
        # .claude/hooks・.claude/settings.json は削除・上書き系のみ見る。
        $mSelf = [regex]::Match($seg, $selfFilePath)
        if ($mSelf.Success) {
            if ($seg -match $hooksVerbSelf) { $hasHooksTamper = $true; break }
            # リダイレクトは**パスより前**にあるときだけ書き込みになる。
            # 位置で見るので窓が要らず、線形のまま順序を判定できる。
            $gt = $seg.IndexOf('>')
            if ($gt -ge 0 -and $gt -lt $mSelf.Index) { $hasHooksTamper = $true; break }
        }
        # `.claude` ディレクトリ自体（親）は、破壊系動詞のときだけ deny する。
        $mDir = [regex]::Match($seg, $selfDirPath)
        if ($mDir.Success -and ($seg -match $hooksVerbDir)) { $hasHooksTamper = $true; break }
    }
    if ($hasHooksTamper) { break }
}

$hasDisableHooks = $hasDisableKey -or $hasHooksTamper

if (-not ($isCommit -or $isPush -or $hasDisableHooks)) { exit 0 }

# --- フックスキップの検出 ----------------------------------------------------
# 1) ロングオプション。引用符で囲まれていても効いてしまうため生文字列で検査する
#    例: git commit "--no-verify" -m x
#
#    git は曖昧でない限りロングオプションの**省略形**を受理する
#    （--no-veri は通る / --no-ver は ambiguous でエラー）ため、前方一致で拾う。
#    区切りは空白・引用だけではない（; && | ) など）ので否定クラスで囲む。
$hasLongOpt = $deescaped -match '(?i)(^|[^A-Za-z0-9_-])--no-(veri[a-z]*|gpg-s[a-z-]*)([^A-Za-z0-9_-]|$)'

# 2) 短縮オプション。-n 単独だけでなく結合クラスタ(-nm 等)も捕捉する
#    例: git commit -nm "msg"  ← -n と -m の結合。旧実装はこれを素通ししていた
#
#    🚨 検査は「git commit を含むセグメント」に限定する。
#    コマンド全体で検査すると、複合コマンドの git 以外の -n
#    （grep -n / head -n / sort -n 等）に誤反応する。
#    実測: `grep -n pattern file && git commit -m x` が deny されていた。
#    セグメント分割は ; & | の3文字のみ（&& / || / | / ; を全て被覆する）。
#    改行では分割しない — 行継続（バックスラッシュ+改行）で -n を別行へ
#    逃がす回避を防ぐため、複数行はひとつのセグメントとして扱う（fail closed）。
#    引用内の区切り文字は上の引用潰しで既に消えているため、
#    メッセージ本文の ; がセグメント境界を偽装することはない。
#    🚨 分割前に「セグメント境界を偽装する材料」を無効化する。
#    区切り文字はエスケープ／コマンド置換の中では区切りとして働かないのに、
#    素朴に split すると境界として扱われ、-n を別セグメントへ逃がせてしまう
#    （セキュリティレビューで実測されたバイパス。旧実装では塞がっていた）:
#      git commit -m foo\;bar -n        → \; は git には引数の一部として届く
#      git commit -m $(printf a;b) -n   → ; は部分シェル内のもの
#    分割用の文字列（$segSets）は上で用意済み。
#
# 🚨 語の検出は $segSource と $segLoose の**両方**で見る。
#    $segSource はエスケープ・展開を空白へ潰すため、git c${z}ommit が
#    `git c ommit` に割れて commit を見失う（語中に1文字挟むだけで抜けられた。実測）。
#    $segLoose は同じ材料を空文字へ潰して語を復元したもの。
#    ただし**短縮オプション(-n)の検出は $segSource 側だけ**で行う。
#    $segLoose は語を繋げるため、メッセージ本文中の -n を拾いやすくなる。
$hasShortN = $false
if ($isCommit) {
    $segs  = $segSource -split '[;&|]'
    $loose = $segLoose  -split '[;&|]'
    # 🚨 要素数の一致はインバリアントではない。
    #    $segSource と $segLoose は別の正規表現を使うため、未閉鎖の展開に対する
    #    fail-closed 判定の発火タイミングがずれ、区切り数が食い違うことがある
    #    （git commit -m $(x $(y) ; z) -n で 2 対 1 になる。実測）。
    #    食い違ったときに「対応する要素が無いから素通り」は **fail open** である。
    #    語の検出だけ $segLoose 全体で見る側に倒す（fail closed）。
    $aligned = ($segs.Count -eq $loose.Count)
    for ($j = 0; $j -lt $segs.Count; $j++) {
        $seg = $segs[$j]
        # 語の検出は緩い変種でも見る。短縮オプションの検出は $segSource 側だけで行う
        # （緩い変種は語を繋げるため、本文中の -n を拾いやすくなる）。
        $alt      = if ($aligned) { $loose[$j] } else { $segLoose }
        $hasGit   = ($seg -match '(?i)\bgit\b')    -or ($alt -match '(?i)\bgit\b')
        $hasCommit= ($seg -match '(?i)\bcommit\b') -or ($alt -match '(?i)\bcommit\b')
        if ($hasGit -and $hasCommit -and
            $seg -match '(?i)(^|\s)-[a-z]*n[a-z]*(\s|$)') {
            $hasShortN = $true
            break
        }
    }
}

# 3) フラグを使わずに同じ効果を得る別経路（core.hooksPath の差し替え・
#    GIT_CONFIG_* 経由の注入・署名の無効化・.git/hooks の破壊）は、
#    **種別ゲートより前**の $hasDisableHooks で既に判定済み。
#    ここで再定義すると同じ正規表現が2箇所に散り、片方だけ更新されて食い違う。

if ($hasLongOpt -or $hasShortN -or $hasDisableHooks) {
    $reason = 'git の commit/push に対するフックスキップ(--no-verify / -n / -nm / --no-gpg-sign / ' +
              'core.hooksPath の差し替え等)は禁止されています。' +
              'プロンプトインジェクション再発防止のため、ハーネス層でブロックしました。' +
              'コミット前に review-pre-commit によるレビューを実施してください。'
    $out = @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = 'deny'
            permissionDecisionReason = $reason
        }
    }
    $out | ConvertTo-Json -Compress -Depth 5
    exit 0
}

exit 0
