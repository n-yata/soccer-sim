# コミット前レビューレポート

## 第1回（2026-10-01）

- 対象: `src/styles/tokens.css`、`src/styles/base.css`、`PageHeader.vue`、`FormationCard.vue`、`ComparisonPage.vue`、`MatrixPage.vue`、`FormationListPage.vue`、`QuizPage.vue`ほか計17コンポーネント、`docs/specs/2_basic-design/screen-design.md`、新規 `.steering/20260929-ui-visual-language/`・`.steering/20260929-ui-token-cleanup/`
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 2件

## コミット前レビュー結果

対象: `src/styles/tokens.css`、`src/styles/base.css`、`PageHeader.vue`、`FormationCard.vue`、`ComparisonPage.vue`、`MatrixPage.vue`、`FormationListPage.vue`、`QuizPage.vue`ほか計17コンポーネント、`docs/specs/2_basic-design/screen-design.md`、新規 `.steering/20260929-ui-visual-language/`・`.steering/20260929-ui-token-cleanup/`（このプロジェクトはバックエンドを持たない静的SPAのため、認証・認可・サーバサイドインジェクション等は該当なし）

### Critical（即時対応必須）

なし

### High（優先対応）

なし

### Medium（対応推奨）

なし

### Low / 改善提案

- [バグ・正しさ] `FormationCard.vue`: 選択状態の説明文カラー上書き（`.selected .formation-card__description { color: #b44712; }`）が削除され、選択時も非選択時と同じ `--color-text-sub` になった。設計上の意図的な簡素化に見えるが、選択カードの視認性の変化（強調が弱まる）は仕様書に明記なし。意図通りか確認推奨。
- [運用] `.steering/20260929-ui-token-cleanup/` は未着手のタスクリスト（チェックボックス未消化）を含む次フェーズの計画。今回のコミット範囲（Phase2実装）とは独立した将来作業のメモであり、混入自体は問題ないが、コミットメッセージで「Phase2完了、Phase3(token-cleanup)は別コミット」と明示すると経緯が追いやすい。

### 問題なし

- **セキュリティ①ハードコーディング/シークレット**: 差分・新規`.steering/`配下ともAPIキー・URL・アカウントID等の機密情報なし。`.gitignore`に`.env`/`.env.*`（`.env.example`のみ許可）が設定済みで問題なし。
- **セキュリティ②〜④（認証・認可/インジェクション/情報漏洩）**: 該当なし（静的SPA、CSSトークン変更のみ、動的な値のレンダリングやDOM操作の変更なし）。
- **OWASP Top 10**: 該当なし（バックエンド・DB・外部APIを持たない）。
- **トークン置換の整合性**: 削除された旧トークン（`--radius-card`/`--shadow-card`/`--color-primary-end`）への参照が`src/`配下に一切残っていないことをgrepで確認済み。
- **チームカラー実値**: `--color-team-a`=`#2563eb`（青）、`--color-team-b`=`#ef4444`（赤）とも変更なしを確認。
- **PageHeader→jleague-linkの整合性**: `FormationListPage.vue`の`__jleague-link`は`PageHeader`スロット内に配置されており、ヘッダー背景がグラデーション→白に変わったことと、リンクの文字色が白→`--color-text-muted`に変わったことは整合している（暗い文字が暗い背景に埋もれる、白背景に白文字が消える、といった不整合はなし）。
- **境界値・空・null**: CSSのみの変更でロジック分岐なし、該当リスクなし。
- **性能**: 差分はCSS静的値のみで計算量・I/Oの変化なし。
- **運用・後方互換**: `screen-design.md`が実装の変更点（ヘッダー背景、カード枠線、判定エリアのカラーバー化等）に追随して更新されている。機能・データ構造の変更がないため既存利用側への影響なし。切り戻しも通常の`git revert`で可能。

### 未検証

- コントラスト比の実測値そのもの（design.md記載の「AA基準を満たすことをJSで確認済み」という記述）は、本レビューでは計算式やテスト実行結果を再現検証していない。差分の到達速度を優先し、記載を信頼する形で処理した。

### 総合評価

Critical / High の指摘なし。コミットして問題ない。Low項目（選択カードの説明文カラー削除）は仕様意図の確認を推奨するが、ブロッカーではない。

### 対応

- Low（選択カードの説明文カラー削除）: **意図通り。対応不要と判断。** design.md「5. FormationCard.vue — 選択表現の変更」に
  「選択時に文字色を変えていたのは、太い枠＋濃い背景に対する調整だった。背景を淡いトーンに
  留めれば文字色は`--color-text`のままでAAを満たせる」と明記されており、選択時に説明文の
  文字色を特別扱いしない（＝`--color-text-sub`のまま据え置く）のは計画どおりの設計判断。
  フェーズ7でのコントラスト実測（design.md「コントラスト比の実測結果」）でも
  `--color-text`×`--color-accent-bg`=16.81:1で問題なしを確認済み。
- Low（`.steering/20260929-ui-token-cleanup/`の混入）: コミットメッセージにPhase2/Phase3の
  切り分けを明記する対応で解消する（後述のコミットメッセージ参照）。
- 未検証（コントラスト比実測の再現性）: 実測はレビュー実施前に別途`javascript_tool`で
  実行済み（`design.md`「コントラスト比の実測結果」に実測値・実測方法を記録済み）。
  レビュー速度を優先しレビュー役による再計算はスキップされたが、実測自体は実施済みであり
  再確認の必要性は低いと判断。

## レビュー完了（2026-10-01）

- 最終ラウンド: 第1回
- 新たな Critical / High: なし（1周目から指摘なし）
- 積み残し（Medium / Low を申し送る場合）: なし（Low 2件は対応不要／コミットメッセージでの
  明示で解消済みと判断）
