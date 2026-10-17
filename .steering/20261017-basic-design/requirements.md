# 要求: 基本設計（docs/specs/2_basic-design/）

## 背景
要件定義工程の6ドキュメント（docs/specs/1_requirements/）がレビュー済みで main にマージされた。
次の工程として基本設計を作成する。

## 要求
- `specs-basic-design` スキルに従い、functional-overview.md を正本として実装詳細を作る
- 1ファイルずつシャビの承認を得る
- 成果物
  - `component-design.md`（レイヤー別の責務・インターフェース・依存関係、保存形式）
  - `usecase.md`（UC-01〜10 のシーケンス図）
  - `screen-design.md`（S-01〜12 のレイアウト・項目・イベント）＋ `wireframes.drawio`（画面1つにつき1ページ）
  - `api-design.md` は作らない（functional-overview.md「API一覧」が該当なし）

## 決定事項（本作業中）
- 3D演出の素材: 簡易形状（カプセル＋チーム色＋背番号）を自作し、移動はコードで補間する（2026-10-17 シャビ決定）
