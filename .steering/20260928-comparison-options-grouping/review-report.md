# コミット前レビューレポート

## 第1回（2026-09-28）
- 対象: `src/pages/ComparisonPage.vue`（表示オプションの`<details>`グルーピング + 追加CSS）、`docs/specs/2_basic-design/wireframes.drawio`（該当セルの差し替え）
- 結果: Critical 0件 / High 0件 / Medium 2件 / Low 4件

## コミット前レビュー結果

対象: `src/pages/ComparisonPage.vue`（表示オプションの `<details>` グルーピング + 追加CSS）、`docs/specs/2_basic-design/wireframes.drawio`（該当セルの差し替え）。差分と、差分が壊しうる直近の呼び出し元（`FreeLayoutControls.vue` / `SquadConditionControls.vue` / `ComparisonPage.test.ts`）のみ確認。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- **[バグ] ネイティブ `details` のDOM状態と `:open` バインディングが desync し、操作中にパネルが勝手に閉じる**
  `:open="isFreeLayoutMode || squadConditionSeed !== null"` は片方向バインディングで、ユーザーが summary をクリックして開閉してもその状態はVue側に戻らない（vnodeの値は更新されない）。ユーザーが手動でパネルを開いた状態で自由配置/個体差トグルをON→OFFすると、式の再評価でVueが`open`属性を強制的に書き換え、クリックした瞬間にパネルが折りたたまれ、隣のボタンごと消える。逆向きの desync（自由配置ON中に手動で閉じる）も発生する。
  → ローカル状態を正本にして双方向に同期する。

- **[バグ/テスト] 新しい開閉挙動を検証するテストが無く、既存テストは空振りしている**
  `ComparisonPage.test.ts` は `.free-layout-controls__toggle` 等を直接 `find()` して操作しているだけで、jsdomは閉じた `details` の子も通常どおりDOMへ描画するため、パネルが閉じていてユーザーがボタンに到達できなくてもテストは緑になっていた。
  → `details` の `open` 属性に対するアサーションを追加する。

### Low / 改善提案
- **[運用] ワイヤーフレームと実装の食い違い（開閉アフォーダンス）**: drawio側は `⚙️ 表示オプション ▾` と下向き矢印を明示しているが、実装は`::-webkit-details-marker`でマーカーを消したまま代替のシェブロンを置いていない。
- **[運用] 図の要素が枠からはみ出している**: `options-panel`（幅220・右端260）に対し`options-toggle`（幅220・右端276）がラベルとしてパネル外へ16pxはみ出していた。
- **[運用] FR番号のtraceabilityが落ちた**: 削除されたコメントにあった `FR-15/FR-18` の参照が新コメントに引き継がれていなかった。
- **[UX] 既定で閉じたことで発見性が下がる**: 意図された変更だが申し送り。
- **[品質] CSSのマジックナンバー**: `.comparison-page__options-body`の`gap: 8px`をトークン化する余地。

### 問題なし
- **セキュリティ（必須4項目・OWASP A01〜A10）**: 該当なし。オフラインSPAで攻撃面が無く、シークレット・URL・認証・インジェクション・情報漏洩のいずれも該当箇所なし。追加importの`Settings2`は既存依存`@lucide/vue`からの静的参照のみ。
- **バグ**: 既存ロジック（トグル・リセット・watchでのリセット）は無変更。`:deep()`セレクタは両コンポーネントのルートclass名と一致し空振りなし。イベント配線はDOM位置が変わっただけ。
- **性能**: 計算量・I/Oの変化なし。`details`が閉じていても子は従来どおりマウントされる。
- **運用**: 純粋なUI変更でrevert可能。設定値・API・スキーマの変更なし。drawioは整形式で他セルからの参照切れなし。

### 未検証
- 実ブラウザでの`<summary>`への`display: flex`適用時のマーカー・クリック挙動（Safari等）は静的レビューのみ。
- `AppIcon.vue`の実装や他ページの同種パターンとの整合性は差分外のため対象外。

### 総合評価
Critical / Highの指摘は無し。セキュリティ観点の指摘も無し。コミット可能。Medium 2件は実ユーザーが確実に踏む経路のため同コミットで解消を推奨。

### 対応
- **Medium（`:open`片方向バインディングのdesync）**: 対応済み。`isOptionsOpen` ref をローカルの正本にし、`@toggle="isOptionsOpen = ($event.target as HTMLDetailsElement).open"` でネイティブの開閉をVue側へ取り込む方式に変更。機能（自由配置・選手個体差）が有効化されたときだけ`watch`で強制的に開き、無効化時には閉じない（ユーザーが開いた状態を尊重）。
- **Medium（テスト不足）**: 対応済み。`ComparisonPage.test.ts`に「表示オプションパネル」describeを追加し、(1)初期状態は閉、(2)各機能ON時に自動的に開く、(3)手動で開いた後に機能をON→OFFしてもパネルが閉じないこと、の3種を検証する4テストケースを追加。全535件（既存531 + 新規4）がパス。
- **Low（drawioのはみ出し）**: 対応済み。`options-toggle`の幅を220→188に修正し枠内に収めた。
- **Low（FR番号のtraceability）**: 対応済み。コメントに `FR-15` / `FR-18` の参照を復元した。
- **Low（開閉アフォーダンスの図との食い違い、既定で閉じたことによる発見性低下、CSSのマジックナンバー）**: 未対応・申し送り。実害が小さく、追加のUI変更を要するため本コミットのスコープ外とした。

## レビュー完了（2026-09-28）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし（発生していない）
- 積み残し（Low）: 開閉シェブロンのUI表示、既定で閉じることによる発見性、CSSのgap値のトークン化。いずれも悪用可能な欠陥ではなく、検出用テストの追加は不要と判断。
