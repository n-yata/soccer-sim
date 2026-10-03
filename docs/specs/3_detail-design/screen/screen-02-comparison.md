# 画面詳細設計書: 比較画面

> 画面一覧・ルート・対応コンポーネント・画面遷移の正本は
> [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。レイアウト・画面項目・
> 画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)。本書は本画面の
> コンポーネント構成（props/state）・状態管理・詳細な画面遷移/イベント処理フロー・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面名 | 比較画面 |
| ルート(FE) | `/compare/:formationAId/:formationBId` |
| 対応コンポーネント | `ComparisonPage` |
| 関連API | 該当なし（本プロダクトはバックエンドAPIを持たない） |
| 関連機能 | FR-03, FR-04, FR-05, FR-06, FR-09, FR-11, FR-13 |

外部設計（レイアウト・画面項目定義・画面イベント一覧）は
[`screen-design.md`](../../2_basic-design/screen-design.md)「画面2: 比較画面」を参照。
本書は以下の実装レベル詳細に限定する。

## コンポーネント構成

FR-20は陣形学習画面に配置する。基本設計の `screen-design.md`「画面6」を参照。


比較の表示部品・算出状態・依存関係は `component-design.md` のComparisonPage節を参照。固定配置と静的特性値を使い、保存済み自由配置は参照しない。

## 状態管理（クエリキー設計）

**該当なし**: 本画面はバックエンドAPIを呼ばず、静的データモジュール（`data/formations.ts`,
`data/matchups.ts`）の関数（`getFormationById`, `getMatchup`）を直接呼び出して参照する。
TanStack Query等のデータ取得ライブラリは使用しない。

## 画面遷移・イベント処理の詳細フロー

### 画面表示（マウント時・ルートパラメータ変更時）

1. `useRoute()` から `formationAId`, `formationBId` を取得する。
2. `computed` として `formationA = getFormationById(formationAId)`,
   `formationB = getFormationById(formationBId)` を算出する。
3. `formationA` と `formationB` の両方が存在する場合のみ、
   `matchup = getMatchup(formationAId, formationBId)` を算出する
   （`getMatchup` は順序に依存しない。`component-design.md`参照）。
4. テンプレート側は以下の優先順位で表示を出し分ける。
   - `formationA`・`formationB`・`matchup` のいずれかが `undefined` → 「例外・エラー表示」の
     ケースを表示し、ピッチ図・優位ポイントは表示しない。
   - 3つとも存在する → タイトル・色の凡例・総合判定見出し（`matchup.overallEdge`/
     `overallReason`）・`MatchupPitchDiagram`（両チームを重ねたピッチ図）・
     `matchup.advantagesForA`/`advantagesForB` の箇条書きを表示する。優位ポイント各行と
     総合判定理由は`TermAnnotatedText`でラップし、含まれるサッカー用語をインライン表示する
     （FR-11）。
5. `formationA.id`/`formationB.id`/`matchup !== undefined` の組を`watch`（`immediate: true`）で
   監視し、3つが揃った時点で`markPairViewed(formationA.id, formationB.id)`を呼び学習進捗として
   記録する（FR-13）。監視対象を`matchup`オブジェクト自体ではなくIDの組にしているのは、
   `getMatchup`が呼び出し順序に応じて新しいオブジェクトを返す仕様のため、同じ組み合わせでも
   参照差で`watch`が誤発火するのを避けるため。

### 戻るボタン

1. ユーザーが「戻る」（アイコン: ArrowLeft）をクリックする。
2. `router.push('/')` を呼び、フォーメーション一覧画面へ遷移する。

### A/B入れ替え・切替（FR-09）

1. ユーザーが「入れ替え」（アイコン: ArrowLeftRight）ボタンをクリックする、またはA側・B側のセレクトで別の
   フォーメーションを選ぶ。
2. いずれの操作も `router.replace()` を呼ぶ（`push` ではない）。比較画面から比較画面への
   移動は「同じ画面の表示内容を変える」操作であり、`push` にすると履歴に比較画面が
   積み重なり、ブラウザバックで一覧画面へ戻るまでに何度も比較画面を経由することになるため。
   - 入れ替え: `router.replace('/compare/${formationB.id}/${formationA.id}')`
   - A側セレクト変更: `router.replace('/compare/${選択したID}/${formationB.id}')`
   - B側セレクト変更: `router.replace('/compare/${formationA.id}/${選択したID}')`
3. `route.params` の変化により `formationA`/`formationB`/`matchup` の `computed` が
   再評価され、表示内容が新しい組み合わせに更新される。
4. `MatchupPitchDiagram` には組み合わせをキーにした `:key` を与えており、キーの変化で
   コンポーネントが再マウントされる。これにより入れ替え・切替後も対戦演出
   （スライドイン）が再生される。
5. 各セレクトの `<option>` は、相手側に選択中のフォーメーションIDと一致する場合
   `disabled` になる。これにより、UI操作で同一フォーメーション同士の組み合わせ
   （`getMatchup` が `undefined` を返すケース）を発生させない。
6. 上記4.の`watch`は入れ替え・切替（`route.params`の変化）にも反応するため、A/B切替後の
   新しい組み合わせも学習進捗として記録される。

### 用語のインライン表示（FR-11）

1. ユーザーが優位ポイントまたは総合判定理由の中の用語（下線付きボタン）をクリックする。
2. `TermAnnotatedText`内部の`openIndex`が該当indexに更新され、`TermPopover`が開く。
3. 同じ用語の再クリック・別の用語のクリック・`Escape`キー・本文外のクリックのいずれかで
   `openIndex`が`null`に戻り、ポップオーバーが閉じる（同時に開くのは1つ）。
4. `text`（表示する文）自体が差し替わった場合（A/B入れ替え・切替）、`openIndex`は自動的に
   `null`にリセットされる（開いていたindexが差し替え後の別の用語を指してしまうのを防ぐ）。

### 画面遷移イベント

| 操作 | 遷移先 | 備考 |
|---|---|---|
| 「戻る」（アイコン: ArrowLeft）をクリック | `/`（`FormationListPage`） | — |
| エラー表示中のリンクをクリック | `/`（`FormationListPage`） | 戻るボタンと同じ遷移 |
| 「入れ替え」（アイコン: ArrowLeftRight）をクリック | `/compare/:formationBId/:formationAId`（`ComparisonPage`） | `router.replace`。履歴を積まない |
| 青チーム変更セレクトを変更 | `/compare/:選択したID/:formationBId`（`ComparisonPage`） | `router.replace`。履歴を積まない |
| 赤チーム変更セレクトを変更 | `/compare/:formationAId/:選択したID`（`ComparisonPage`） | `router.replace`。履歴を積まない |

## 例外・エラー表示

| ケース | 表示 |
|---|---|
| `formationA` または `formationB` が `undefined`（存在しないフォーメーションIDでの直接アクセス等） | 「指定された組み合わせを表示できません」等のメッセージを表示し、一覧画面へのリンクを併記する。ピッチ図・優位ポイントは表示しない |
| `formationA`・`formationB` は存在するが `matchup` が `undefined`（同一フォーメーション同士の
  ID指定によるURL直打ち、または将来のデータ追加漏れ） | 上記と同じエラー表示にする |

> **コミット前レビューで判明した経緯**: 当初は `formationA`/`formationB` の存在チェックのみで
> 表示を出し分けていたが、同一フォーメーション同士のURL直打ち（例:
> `/compare/4-4-2/4-4-2`）では両方とも存在するのに `getMatchup` が `undefined` を返し、
> タイトル・ピッチ図は表示されたまま解説文だけが無言で空欄になる欠陥があった。
> `formationA`/`formationB`/`matchup` の3つ全てが揃っていることをエラー表示の条件にすることで、
> このケースも一覧画面へのリンク付きエラー表示に含める。
>
> なお、`matchups.ts` はMVPで扱うフォーメーション全組み合わせ分の解説文をあらかじめ用意する
> 運用のため、**異なるフォーメーション同士**での `matchup` 未検出（データ追加漏れ）は
> 通常発生しない前提だが、発生した場合も同じエラー表示で扱われるため実装上の弊害は無い。
