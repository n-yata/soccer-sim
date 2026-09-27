# 画面詳細設計書: フォーメーション一覧画面

> 画面一覧・ルート・対応コンポーネント・画面遷移の正本は
> [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。レイアウト・画面項目・
> 画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)。本書は本画面の
> コンポーネント構成（props/state）・状態管理・詳細な画面遷移/イベント処理フロー・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面名 | フォーメーション一覧画面 |
| ルート(FE) | `/` |
| 対応コンポーネント | `FormationListPage` |
| 関連API | 該当なし（本プロダクトはバックエンドAPIを持たない） |
| 関連機能 | FR-01, FR-02, FR-08 |

外部設計（レイアウト・画面項目定義・画面イベント一覧）は
[`screen-design.md`](../../2_basic-design/screen-design.md)「画面1: フォーメーション一覧画面」を参照。
本書は以下の実装レベル詳細に限定する。

## コンポーネント構成

`screen-design.md`「詳細設計への申し送り」で委譲されていたコンポーネント分割をここで確定する。
フォーメーションカードを再利用可能な表示コンポーネント `FormationCard` として分離し、
カード内のミニピッチ図をさらに `FormationMiniPitch` として分離する。

```
FormationListPage
└── FormationCard（v-for で formations の件数分描画）
    └── FormationMiniPitch（formation を渡し、単独フォーメーションの配置図を描画）
```

### props / state 設計

| コンポーネント | props | 内部 state |
|---|---|---|
| `FormationListPage` | — | `selectedIds: string[]`（選択中のフォーメーションID。最大2件、選択順を保持する） |
| `FormationCard` | `formation: Formation`, `selected: boolean` | なし（emits `select(id: string)` のみ） |
| `FormationMiniPitch` | `formation: Formation` | なし（表示専用。`component-design.md`参照） |

## 状態管理（クエリキー設計）

**該当なし**: 本画面はバックエンドAPIを呼ばず、静的データモジュール（`data/formations.ts`）を
直接インポートして参照する。TanStack Query等のデータ取得ライブラリは使用しない
（`architecture-overview.md`「データ永続化戦略」参照）。

## 画面遷移・イベント処理の詳細フロー

### カード選択（トグル）

1. ユーザーが `FormationCard` をクリックする。
2. `FormationCard` が `select(id)` を emit する。
3. `FormationListPage` の `toggleSelection(id)` が呼ばれ、`selectedIds` を次のルールで更新する。
   - `id` が未選択の場合:
     - `selectedIds.length < 2` なら `id` を末尾に追加する。
     - `selectedIds.length === 2` の場合、`selectedIds` の先頭（最も古く選択したID）を削除してから
       `id` を末尾に追加する（常に直近2件を保持する）。
   - `id` が選択済みの場合: `selectedIds` から `id` を削除する（選択解除）。
4. `selectedIds` の更新を `watch` で監視し、`selectedIds.length === 2` になった時点で
   「比較画面への遷移」フローへ進む。

> **3件目選択（手順3の `selectedIds.length === 2` の分岐）について**: 2件揃った時点で
> 即座に比較画面へ自動遷移するため、通常操作ではこの分岐に到達しない。連打等のタイミングで
> 理論上到達しうる状態を未定義動作にしないための防御的な仕様であり、`screen-design.md`
> 「画面イベント」の注記と対応する。

### 比較画面への遷移

1. `selectedIds` が2件になったことを `watch` で検知する。
2. `router.push(`/compare/${selectedIds[0]}/${selectedIds[1]}`)` を呼び、比較画面へ遷移する。
3. 遷移後、`FormationListPage` の選択状態はコンポーネントの破棄とともにリセットされる
   （一覧画面に戻ってきたときは未選択状態から始まる）。

### 画面遷移イベント

| 操作 | 遷移先 | 備考 |
|---|---|---|
| 2件目のフォーメーションカードを選択 | `/compare/:formationAId/:formationBId`（`ComparisonPage`） | パスパラメータは `selectedIds` の選択順（`[0]` → `formationAId`, `[1]` → `formationBId`） |

## 例外・エラー表示

**該当なし**: 本画面は静的データのみを参照し、APIエラー・ローディング・空状態は発生しない
（`screen-design.md`「画面共通の状態表現」参照）。
