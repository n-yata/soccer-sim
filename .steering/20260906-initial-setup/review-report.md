# コミット前レビューレポート

## 第1回（2026-09-06）
- 対象: 初回コミット対象の全未追跡ファイル（`.claude/hooks/*`、`.claude/settings.json`、スキルスタブ22件、`.gitattributes`、`.gitignore`、`.mcp.json`、`AGENTS.md`、`CLAUDE.md`、`docs/`配下の要件定義〜単体テスト仕様 全13ファイル）
- 結果: Critical 0件 / High 2件 / Medium 8件 / Low 6件

## コミット前レビュー結果

対象: `soccer-sim` 初回コミット対象の全未追跡ファイル（`.claude/hooks/*`（実体＋回帰テスト）、`.claude/settings.json`、スキルスタブ22件、`.gitattributes`、`.gitignore`、`.mcp.json`、`AGENTS.md`、`CLAUDE.md`、`docs/` 配下の要件〜単体テスト仕様 全13ファイル）。読み取りのみ、ファイルの変更は一切行っていない。

### Critical（即時対応必須）
- なし

### High（優先対応）
- [セキュリティ／情報漏洩] kit 専用スキルが利用側プロジェクトへ配布されている: `.claude/skills/kit-contribute/SKILL.md` の description 自身が「受け渡し場所には他プロジェクトの振り返りも入っており、未修正の脆弱性情報がセッションへ流れ込むため、利用側プロジェクトでは絶対に使用しない」と明記している。それがこの利用側リポジトリに配布され、しかも git にコミットされようとしている。description は発火条件でもあるため、「還元」「振り返りをまとめて」等の依頼で誤発火する経路が実在する。同様に `review-skills` も「`distribution/skills/` は kit にしか存在しない」kit 専用。→ 両スキルのスタブを本リポジトリから除外する（`/kit-sync` の配布対象から外すか、コミット対象から落とす）。除外できない事情があるなら、その理由を `repository-structure.md`「汎用規約からの差分」に記録すること。
- [運用／バグ] `.gitignore` に `node_modules/` `dist/` `coverage/` が無い: 技術スタックは Vue + Vite + Vitest（`architecture-overview.md`）で、`repository-structure.md` のセットアップ手順は `npm install` から始まる。次の作業で確実に `node_modules/` と `dist/` が生成されるのに除外されておらず、誤コミットすれば数万ファイルの混入になり巻き戻しが高コスト。`AGENTS.md` の「`git add -A` を使わない」は緩和にはなるが保証ではない。→ `node_modules/`、`dist/`、`coverage/`、Vite キャッシュ（`node_modules/.vite`）、`*.local` を追加する。

### Medium（対応推奨）
- [セキュリティ] `.mcp.json` の `drawio` サーバーがバージョン未固定: `npx -y drawio-mcp-server` は起動のたびに npm から最新版を取得して確認なしで実行する（`-y`）。上流の乗っ取り・タイポスクワッティングがそのままローカル実行に直結する。→ `drawio-mcp-server@<固定バージョン>` にピン留めするか、事前インストール済みバイナリを指す形にする。
- [バグ] マッチアップ未検出時の扱いが3ドキュメントで食い違う: `screen-design.md`（画面項目定義「マッチアップ未検出時は解説文の代わりにエラーメッセージを表示」）と `component-design.md`（`matchup: Matchup | undefined; // 未検出時は…エラー表示に切り替える`）に対し、`3_detail-design/screen/screen-02-comparison.md` は「本画面では扱わない」と明記。正本の `functional-overview.md`「エラーハンドリング」にはこのケース自体が無く、単体テスト仕様にもケースが無い。実装者がどれを読むかで挙動が変わり、静かに未定義動作になる。→ 正本（`functional-overview.md`）で扱いを1つに決め、他2文書をポインタに揃える。
- [バグ] 「同一フォーメーション選択エラー」が到達不能なまま仕様に残っている: `functional-overview.md`「エラーハンドリング」と `glossary.md`「エラー・例外」は「異なるフォーメーションを選んでください」のメッセージ表示を定義しているが、確定したトグル仕様（`screen-01-formation-list.md`／`screen-design.md`）では同一カード再クリック＝選択解除であり、同一選択状態は発生しない。詳細設計は「例外・エラー表示: 該当なし」、テスト仕様にもメッセージ検証が無い。→ 要件（FR-02）側の記述を「トグルにより同一選択が発生しない」に更新するか、メッセージ要件を残すなら実装・テストへ落とす。
- [バグ] 到達不能なイベント仕様とテストケース: 「2件選択された時点で自動遷移」（`screen-design.md` 画面イベント／`screen-01` の watch フロー）が正なら、「3件目のカードをクリック（既に2件選択済み）」という状態は一覧画面上に存在しない。それを前提にした `test-screen-01-formation-list.md` ケース7（「最も古い選択を解除」＝実装の要と明記）は、実アプリでは再現しない状態のテストになる。→ 遷移トリガー（自動遷移か明示ボタンか）を1つに確定し、イベント表とテストを追随させる。
- [バグ] 用語の誤記が docs 全体で97箇所: 「フォーメーション」が「フォーメーム」に化けている（`functional-overview.md` 21件、`requirements-definition.md` 19件、`glossary.md` 14件 ほか）。`glossary.md` は用語の正本でありながら本文で誤記を使っており、ER 図のフィールド名（`フォーメームID`）や FR 受け入れ基準にも入り込んでいる。顧客提出物としての品質に加え、ユビキタス言語が壊れる。→ 一括置換（`.drawio` とテスト仕様の整合も確認）。
- [バグ] Markdown テーブルがセル内改行で崩れている: `requirements-definition.md` の §1.4 プライマリ／セカンダリ KPI 表と §5 の NFR-02・NFR-03 が1行のセルを物理改行で折り返しており、レンダリング時に表が分断される。提出物として表が読めなくなる。→ セル内改行は `<br>` にするか1行にまとめる。
- [運用] 本コミット自身に `.steering/` の証跡が無い: `AGENTS.md` §1・§4 は「軽微な作業でも `retrospective.md` は必ず残す」「`review-report.md` にレビュー全文を出力」と定めているが、リポジトリに `.steering/` が存在しない。→ `.steering/[日付]-initial-setup/` に本レビュー結果と振り返りを作成してからコミットする。
- [運用] `repository-structure.md` が実態と食い違っている: ヘッダの「工程: 詳細設計」は `1_requirements/`（要件定義工程）配下の文書として不正確。「`docs/specs/2_basic-design/` 以降: 基本設計・詳細設計・テスト仕様（未着手）」も、実際には 2/3/4 工程の成果物が本コミットに含まれており誤り。→ 記述を現状へ更新。
- [運用] フック回帰テストを自動実行する仕組みが無い: `block-no-verify.ps1` は BOM 欠落や構文エラーで無言終了＝fail open する設計で、その番人が `tests/test-block-no-verify.ps1` の手動実行しかない。→ 最低限、`/kit-sync` 後やコミット前の手順としてテスト実行を `repository-structure.md` に明文化する。

### Low / 改善提案
- [運用] `.claude/hooks/hooks.json` が `.claude/settings.json` のフック定義と完全重複（kit配布物のため変更は `/kit-sync` 側の判断）。
- [バグ] `requirements-definition.md` §1.4 の注記が空文書（`non-functional-requirements.md`）を指す。参照先を §5 に直すのが自然。
- [運用] テスト仕様内の参照先（`test-block-no-verify.ps1` L455 の `.steering/20260829-hook-cmdsubst-bypass/retrospective.md`）が本リポジトリに存在しない（配布物なので許容）。
- [運用] `.gitattributes` の `.claude/agents/**` は現状存在しないディレクトリ（将来用、無害）。
- [バグ] `screen-design.md` のワイヤー記述「グリッド状（3列×2行）」は、MVP のフォーメーション数が4件のときに合わない。「最大3列の可変グリッド」等に緩めるのが安全。
- [セキュリティ／将来] 比較画面での `v-html` 不使用方針を `component-design.md` に一文残しておくとよい。

### 問題なし
- セキュリティ①ハードコーディング: リポジトリ全体を横断検索してヒット0件。`.mcp.json` はプレースホルダ形式。
- セキュリティ①`.gitignore` の機密除外: `.env`/`.env.*`と`!.env.example`の順序が正しい。`git check-ignore`で実測確認済み。
- セキュリティ②③（アプリ側）: 実装コードが無く該当なし。
- セキュリティ③ `block-no-verify.ps1`: BOM存在確認、`.gitattributes`で保護確認、回帰テスト全件成功（exit 0、既知の穴23件は仕様どおり）。
- 性能: 該当なし。
- ドキュメント間の主要な追跡性（FR→画面→コンポーネント→単体テスト、ルート定義、コンポーネント名、drawioページ名）は一致。

### 未検証
- kit-mcpが配信する規約`reference/rules/*.md`の内容（本リポジトリに実体が無い）。
- `wireframes.drawio`の図そのもの（図形・レイアウトの妥当性）。
- 実行時の挙動（`src/`未実装）。

### 総合評価
Critical: なし / High: 2件。この2件を修正してから初回コミットする。

### 対応
- **High-1（kit専用スキルの配布）**: kit-mcpサーバーの`get_stubs`が返す22件の配布物であり、BOOTSTRAP.mdの手順通りに配置したもの。`kit-contribute`/`review-skills`はdescription自体に「利用側プロジェクトでは使用しない」旨が明記されており、ユーザーが明示的に`/kit-contribute`等を呼ばない限り実行されない設計。シャビと相談の結果、**リスクを認識した上でそのまま受容する**（利用側だけで除外すると次の`/kit-sync`実行時に「kitにあるが構築先に無いもの」として再配置され、矛盾が生じるため）。この事象自体はkit側の配布仕様（get_stubsが利用側専用スキルの区別を持たない）の問題であり、`kit-contribute`スキルの受け渡し経路を通じてkit側へフィードバックする旨を`retrospective.md`に記録する。
- **High-2（.gitignoreの不足）**: `node_modules/`, `dist/`, `coverage/`, `*.local`を追加した。
- Medium指摘のうち、実装前に直しておくべきもの（用語の誤記、表崩れ、ドキュメント間の矛盾、repository-structure.mdの記述誤り）は本ラウンドで修正した。
- Medium「drawio-mcp-serverのバージョン未固定」「フック回帰テストのCI化」は積み残しとする（後続で検討）。
- Low指摘は原則として申し送り、明白な誤りのみ修正した。

## 第2回（2026-09-06）— 修正後の再レビュー

- 対象: 第1回の指摘（High 2件・Medium 8件・Low 2件）に対する対応の解消確認、および修正箇所周辺
- 結果: 新たな Critical / High なし。前回指摘はすべて解消。新たに Medium 1件を検出（`retrospective.md`未作成）

### 前回指摘の解消状況
- High-1（kit専用スキルの配布）: 解消（`repository-structure.md`「汎用規約からの差分」に受容判断を記録）
- High-2（.gitignore不足）: 解消（`git check-ignore -v`で実測確認済み）
- Medium（マッチアップ未検出の3ドキュメント食い違い）: 解消（`functional-overview.md`を正本に統一）
- Medium（同一フォーメーション選択エラーの到達不能）: 解消（削除し、トグル方式のため発生しない旨を注記）
- Medium（3件目クリックの到達不能仕様）: 解消（防御的仕様として3ファイルで一貫した説明に）
- Medium（「フォーメーム」誤記97箇所）: 解消（全置換、意味変化なし）
- Medium（テーブルのセル内改行崩れ）: 解消
- Medium（repository-structure.mdの工程表記・未着手の誤り）: 解消
- Medium（.steering/証跡が無い）: 部分解消（review-report.mdは作成済み、retrospective.mdが未作成と指摘）
- Low（グリッド表記・v-html方針）: 解消

### 新たな指摘
- [運用][Medium] `retrospective.md`が未作成。`repository-structure.md`がkitへの申し送り先として参照しているが、リンク切れになっている。→ 本ラウンドで作成する。
- [運用][Low] 積み残し済みのdrawio-mcp-serverバージョン未固定・フック回帰テストCI化は対応範囲外として妥当（意図的な見送り）。

### 対応
- `retrospective.md`を作成し、リンク切れを解消する。

## レビュー完了（2026-09-06）
- 最終ラウンド: 第2回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）:
  - `.mcp.json`のdrawio-mcp-serverバージョン未固定（Medium。検出するテストは無し、次回kit-mcp設定見直し時に対応）
  - フック回帰テストの自動実行（CI導入までの暫定。検出するテストは無し）
  - `.claude/hooks/hooks.json`と`settings.json`の重複（kit配布物のためkit側の判断）
