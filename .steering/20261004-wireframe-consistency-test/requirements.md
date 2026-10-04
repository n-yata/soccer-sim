# 要求内容

## 概要

ワイヤーフレーム（`docs/specs/2_basic-design/wireframes.drawio`）と実装（ルート定義・主ナビ）の一致を
Vitest で機械検査し、画面変更時の wireframe 更新漏れを `npm test` で検出できるようにする。

## 背景

- 2026-10-04 の整合作業（`.steering/20261004-screen-docs-alignment/`）で、「画面を変える PR では
  wireframe と画面設計を同じ PR で更新する」ルールを `repository-structure.md` に定義した。
- しかし確認方法はレビュー担当の注意に依存しており、コミット前レビュー（第1回 Medium 2）で
  「見落としても何も起きない（fail open）」と指摘され、機械検査を後続作業として申し送った。

## 実装対象の機能

### 1. wireframe とルートの対応検査
- drawio の `wireframe-[slug]` ページの slug 集合が、`src/router/index.ts` のルート名の集合と一致することを検査する。

### 2. 主ナビの一致検査
- 全ページの主ナビ（`app-header-nav-*` セル）のラベル列が、`AppHeader.vue` が描画する主ナビのラベル列
  （項目・順序）と一致することを検査する。drawio のアイコン代替の絵文字は除去して比較する。

### 3. 現在地の一致検査
- 各ページで現在地として強調したナビ項目が、そのルートで `AppHeader.vue` が `aria-current` を付ける
  項目と一致することを検査する。

### 4. fail closed
- drawio が読めない・XML として壊れている・ページやナビが0件の場合は、成功ではなく失敗にする。

## 受け入れ条件

### 1. ルート対応
- [ ] ルート追加時に drawio へページを足さないとテストが落ちる（変異注入で確認）
- [ ] drawio のページ名を誤るとテストが落ちる

### 2. 主ナビ
- [ ] `AppHeader.vue` の項目名・順序を変えて drawio を直さないとテストが落ちる（変異注入で確認）

### 3. 現在地
- [ ] drawio の現在地の強調を別項目へ移すとテストが落ちる（変異注入で確認）

### 4. fail closed
- [ ] drawio を XML として壊すとテストが落ちる（変異注入で確認）
- [ ] 検査したページ数・ナビ項目数が0件のときに合格しない

### 共通
- [ ] 失敗時のメッセージから、どのページの何が食い違ったかが読める
- [ ] 既存テスト・lint・typecheck・build がパスする
- [ ] repository-structure.md の同時更新ルールの「確認方法」に本テストを追記する

## 成功指標

- 画面変更で wireframe の更新を漏らした PR が `npm test` で検出される

## スコープ外

- 主ナビ以外のワイヤーフレーム内容（タイトル・項目）の照合
- 画面6〜8の詳細設計書・単体テスト仕様書（別作業）

## 参照ドキュメント

- `docs/specs/1_requirements/repository-structure.md` - 同時更新ルールの正本
- `docs/specs/1_requirements/functional-overview.md` - 画面一覧の正本
- `.steering/20261004-screen-docs-alignment/retrospective.md` - 申し送り元
