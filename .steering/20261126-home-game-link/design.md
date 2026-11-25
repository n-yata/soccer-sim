# 設計書

## コンポーネント設計

### FormationListPage（`src/pages/FormationListPage.vue`）
- `PageHeader` の既定スロット（`page-header__actions`）に、Jリーグのリンクより前に `<a class="formation-list-page__game-link">` を置く
- `href` は `` `${import.meta.env.BASE_URL}game/index.html` ``（公開では `/soccer-sim/game/index.html`）。Router の外なので `router-link` にしない
- アイコンは `@lucide/vue` の `Gamepad2`、文言「戦術ゲームで遊ぶ」
- 見た目は主操作の塗りボタン（理解度チェックの「次へ」と同じ: `--color-primary` の塗り・白文字・ピル・高さ 44px 以上）。
  破線枠の Jリーグ（外部）と区別できる
- 狭い画面ではヘッダーの行が折り返すため、Jリーグのリンクと同じく `max-width: 100%`・折り返し可

## テスト戦略

- `FormationListPage.test.ts`: リンクがヘッダー内にあり、`href`・文言・`target` なしを確かめる。Jリーグ未設定でも表示される
- `wireframeConsistency.test.ts` は主ナビ・ルートの対応だけを見るため、本変更では変わらない（drawio は手で更新する）

## ディレクトリ構造

変更のみ（新規ファイルなし）:
```
src/pages/FormationListPage.vue / FormationListPage.test.ts
docs/specs/1_requirements/functional-overview.md（画面一覧の主な要素）
docs/specs/2_basic-design/screen-design.md・component-design.md・wireframes.drawio（wireframe-formation-list）
docs/specs/4_unit-test/test-screen-01-formation-list.md
```

## セキュリティ考慮事項

- URL はビルド時の `BASE_URL` から組み立てる同一オリジンの相対パスで、利用者の入力を含まない
