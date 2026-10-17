# 画面詳細設計書: S-10 ゲームの表現範囲

> 画面一覧・画面遷移の正本は [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」、
> 表示する内容の正本は同書「単純化カタログ」。レイアウト・画面項目・画面イベントの外部設計は
> [`screen-design.md`](../../2_basic-design/screen-design.md)「S-10」、呼び出しの順序は
> [`usecase.md`](../../2_basic-design/usecase.md)「UC-08」。画面共通の決めごとは [`screen-common.md`](./screen-common.md)。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面 ID・画面名 | S-10 ゲームの表現範囲 |
| シーン | `game/ui/screens/s10_scope/scope_screen.tscn` |
| ルートの `class_name` | `ScopeScreen`（`Control`） |
| 使うアプリケーション層 | `App.library`（`simplifications()`）、`App.request_screen()` |
| `enter` の `params` | なし |
| 関連機能 | FR-23 |
| ワイヤーフレーム | [`wireframes.drawio`](../../2_basic-design/wireframes.drawio)（ページ: `wireframe-s10-scope`） |

## ノード構成

```
ScopeScreen (Control)
├── Header                                  # ScreenHeader（「← 戻る」と「ゲームの表現範囲」）
└── Scroll (ScrollContainer)                # 縦にスクロール
    └── Body (VBoxContainer)                # 外周の余白 24px、間隔 20px
        ├── Lead (Label)                    # 「このゲームが表現していないこと」＋1文の説明
        └── SimplificationList              # common/simplification_list.tscn（S-08 の最後の段階と共用）。2列
            └── SimplificationCard × 件数   # 「SIM-01 縦方向のライン調整」／「ゲームでは: …」／「実戦では: …」（caution の色）
```

- `SimplificationList` は S-08 の最後の段階でも同じものを使う（FR-23「チュートリアルの最後と同じ一覧」）

## 画面の状態

状態を持たない（表示だけ）。

## イベント処理の詳細フロー

### 画面を開く（`enter`）

1. `library.simplifications()` を ID 順に `SimplificationList` に渡す

### 戻る・Android の戻る操作

`App.request_screen(S01_TITLE)`。`true` を返す。

### 画面遷移

| 操作 | 遷移先 |
|---|---|
| 戻る | S-01 タイトル |

## 例外・エラー表示

| ケース | 表示 |
|---|---|
| 単純化カタログが0件 | 起きない（静的データとカタログの件数の一致は NFR-17 ② で確かめる） |
