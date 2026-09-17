# 要求内容

## 概要

サッカーのフォーメーションを2つ選んで、ピッチ図と戦術解説を並べて比較できるMVPを実装する
（「フォーメーションラボ」のMVP）。

## 背景

サッカー戦術の知識がなくても、フォーメーション同士の噛み合わせを「見て・読んで」直感的に
理解できる学習アプリが欲しい、という開発者本人の要求から始まった
（`docs/ideas/initial-requirements.md`）。要件定義〜単体テスト仕様書までのドキュメント一式は
既に作成済み（`docs/specs/1_requirements/`〜`docs/specs/4_unit-test/`）。本作業はそれに基づく
初回実装である。

## 実装対象の機能

### 1. フォーメーション一覧表示・選択（FR-01, FR-02）

- 4〜6種類のフォーメーション（4-4-2, 4-3-3, 4-2-3-1, 3-5-2等。4-2-3-1と4-4-2は必須）を
  一覧表示する。
- ユーザーは一覧から異なる2つのフォーメーションを選択できる（トグル方式）。
- 2件選択された時点で比較画面へ自動遷移する。

### 2. ピッチ図の並列表示（FR-03）

- 選択した2つのフォーメーションの選手配置をSVGのピッチ図で並べて表示する（青/赤で区別）。

### 3. 戦術解説の表示（FR-04）

- 選択した組み合わせに対応する戦術解説文を表示する（平易な日本語）。

## 受け入れ条件

### フォーメーション一覧表示・選択

- [x] `/` にアクセスすると、4〜6件のフォーメーションカードが一覧表示される。
- [x] カードをクリックすると選択状態になり、強調表示される。
- [x] 選択済みカードを再度クリックすると選択が解除される。
- [x] 異なる2件を選択すると `/compare/:formationAId/:formationBId` へ自動遷移する。
- [x] 既に2件選択済みの状態で3件目を選択すると、最も古い選択が解除され新しい選択に置き換わる。

### 比較画面

- [x] `/compare/4-2-3-1/4-4-2` にアクセスすると、2つのピッチ図（青=4-2-3-1, 赤=4-4-2）と
      戦術解説文が表示される。
- [x] 存在しないフォーメーションID、または同一フォーメーション同士のIDでアクセスすると、
      エラーメッセージと一覧画面へのリンクが表示され、ピッチ図・解説文は表示されない
      （コミット前レビュー対応で同一フォーメーション同士のケースを追加）。
- [x] 「← 戻る」をクリックすると `/` へ遷移する。

### 品質

- [x] `docs/specs/4_unit-test/test-screen-01-formation-list.md` の全9ケースが実装され、
      すべて成功する（チェック欄`[x]`）。
- [x] `docs/specs/4_unit-test/test-screen-02-comparison.md` の全16ケース（コミット前レビュー
      対応で1件追加）が実装され、すべて成功する（チェック欄`[x]`）。

## 成功指標

定量指標は設けない（`requirements-definition.md` §1.4参照。趣味・学習目的のプロジェクトのため）。
本作業では「単体テスト仕様書の全ケースが実装・実行され、チェックが付いていること」を
完了の目安とする。

## スコープ外

以下はこのフェーズでは実装しない（`requirements-definition.md` §6.2参照）。

- 簡易シミュレーション機能
- 相性マトリクス表
- 自由配置機能
- アニメーション演出

## 参照ドキュメント

- `docs/specs/1_requirements/requirements-definition.md` - 要件定義書（FR-01〜04、NFR-01〜03）
- `docs/specs/1_requirements/functional-overview.md` - 機能概要（データモデル・画面設計）
- `docs/specs/1_requirements/architecture-overview.md` - アーキテクチャ概要（技術スタック）
- `docs/specs/2_basic-design/component-design.md` - コンポーネント設計
- `docs/specs/2_basic-design/screen-design.md` - 画面設計
- `docs/specs/2_basic-design/wireframes.drawio` - ワイヤーフレーム
- `docs/specs/3_detail-design/screen/screen-01-formation-list.md` - 一覧画面詳細設計
- `docs/specs/3_detail-design/screen/screen-02-comparison.md` - 比較画面詳細設計
- `docs/specs/4_unit-test/test-screen-01-formation-list.md` - 一覧画面単体テスト仕様
- `docs/specs/4_unit-test/test-screen-02-comparison.md` - 比較画面単体テスト仕様
