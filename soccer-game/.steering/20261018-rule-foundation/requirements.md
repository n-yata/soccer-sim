# 要求内容

## 概要

ドメイン層の土台として、次の4つを作る。
- 区分値
- エリア
- 陣形と選手単位の配置
- 基本配置の導出（アルゴリズム1）

あわせて、陣形の静的データ（`formations.json`）を読み込んで検証できるようにし、ドメイン層の禁止依存を検出するスクリプトを作る。

## 背景

- 判定・CPU・3D 演出のすべてが、エリアと選手単位の配置の上に乗る。ルールの正しさはプロダクトの価値の中核なので（FR-05・NFR-14）、
  最初にテストで固定した土台を作る。
- 開発環境の構築（`../20261018-dev-env-setup/`）の時点では、テストは 0 件だった。
- NFR-13 の禁止依存のチェックスクリプトは、「`tools/` に置く」とだけ決まっていて、まだ無い。

## 決定事項（2026-10-18 シャビ）

- 最初の機能は「ルールの土台」にする。範囲は次の3つ（「スコープ外」も参照）。
  - ドメイン
  - 陣形データとその読み込み
  - 禁止依存の検査
- 背番号は移植元に無いので、ポジションの慣例で付ける（下の §5 の表）。

## 実装対象の機能

### 1. 区分値 `GameEnums`（`game/domain/game_enums.gd`）
- `component-design.md` §2.1 の enum をすべて持つ。値の名前も同書のとおりにする。

### 2. エリア `PitchArea`（`game/domain/pitch_area.gd`）
- `component-design.md` §2.2 の API を持つ。
  - `mirrored`・`forward`・`backward`
  - `neighbors4`・`neighbors8`
  - `equals`・`to_key`・`from_key`・`all`

### 3. 陣形と配置の値オブジェクト
- `FormationDef`・`PlayerSlotDef`: `is_goalkeeper`・背番号・座標を持つ。
- `PlayerState`: `player_id`・`base_area`・`fixed_area` を持つ。
- `TeamLayout`: 選手の一覧と、各選手の現在エリアを持つ。エリアごとの人数を返す。
- いずれも `RefCounted` を継承し、`duplicate_deep()` を持つ（`component-design.md` §1.1）。

### 4. 基本配置の導出 `BaseLayoutDeriver`（`game/domain/layout/`）
- `area_of(x, y)` と `derive(formation)` を持つ（`component-design.md` §2.3、`functional-overview.md` アルゴリズム1）。
- `derive` は GK を除く10人の配置を返す。固定は無く、現在エリアは基本エリアと同じ。

### 5. 陣形の静的データ `game/content/formations.json`
- フォーメーションラボ（`soccer-sim`）の `src/data/formations.ts` から、4陣形（4-4-2・4-3-3・4-2-3-1・3-5-2）を移植する。
  - そのまま移す: `id`・`name`・`description`・`extraTags`（`extra_tags` に改名）、選手の `id`・`type`・`label`・`x`・`y`。
  - `stats`（レーダーチャート用）は移さない。
  - 最上位に `format_version: 1` を付ける（`data-definition.md` §3）。
- 背番号は次のとおり。陣形の中で一意で、移植元の選手 id の末尾と1対1に対応する。

  | 陣形 | 背番号（移植元の選手 id の末尾 → 番号） |
  |---|---|
  | 4-4-2 | gk 1, rb 2, lb 3, cb1 4, cb2 5, cm2 6, rm 7, cm1 8, st1 9, st2 10, lm 11 |
  | 4-3-3 | gk 1, rb 2, lb 3, cb1 4, cb2 5, cm2 6, rw 7, cm1 8, st 9, cm3 10, lw 11 |
  | 4-2-3-1 | gk 1, rb 2, lb 3, cb1 4, cb2 5, dm1 6, amr 7, dm2 8, st 9, amc 10, aml 11 |
  | 3-5-2 | gk 1, rwb 2, lwb 3, cb1 4, cb2 5, cb3 6, cm1 8, st1 9, cm3 10, st2 11, cm2 14 |

### 6. 陣形の読み込み `ContentRepository`（`game/data/content_repository.gd`）と `ContentCatalog`
- `load_catalog()` と `validation_errors()` を持つ（`component-design.md` §4.1）。
- `formations.json` を、次の範囲・制約で検証する。
  - `data-definition.md` §3.1
  - 同 §3 冒頭の、ID の形式と `format_version`
- `ContentCatalog` は、陣形だけを持つ形で始める。ほかの静的データ（方式・噛み合わせルールなど）は、それを使う機能の作業で足す。

### 7. ドメイン層の禁止依存の検出（NFR-13。`tools/` に置く）
- `game/domain/` 配下のスクリプトから、`architecture-overview.md`「ドメイン層」で禁止した参照を検索する。
  - シーンツリー・ノード（`Node`・`get_tree`・`SceneTree` など）
  - ファイル（`FileAccess`・`DirAccess`・`ResourceLoader`・`load(`・`preload(` など）
  - 時刻（`Time` など。実装時に、Godot 4 の `OS` には時刻の関数が無いと分かったため `OS.get_ticks` は対象から外した）
  - グローバルな乱数（`randi`・`randf`・`randomize` など）
- 検索する API 名の一覧は、このスクリプトを正本にする（NFR-13）。
- 見つかったら、該当したファイル・行・API 名を出し、終了コード 1 で終わる。

### 8. テストの一括実行スクリプト（`tools/`）
- 次の2つをまとめて実行し、どちらかが失敗したら失敗で終わる。
  - gdUnit4 の CLI（`repository-structure.md`「セットアップ手順」2 のコマンド）
  - 禁止依存の検査

## 受け入れ条件

### 共通
- [ ] テストは、先に失敗する状態を確かめてから実装する（Red→Green）。
- [ ] gdUnit4 の CLI を一括実行スクリプトから実行して、次をすべて満たす。
  - 実行件数が 0 件でない。
  - 失敗が 0 件。
  - 終了コードが 0。
- [ ] 型の警告（エラー扱いの3つ）が 0 件で、`godot --headless --editor --quit` のエラーが 0 件。

### エリア `PitchArea`
- [ ] 15エリアすべてで、鏡像を2回取ると元に戻る。対応は `L2↔R2`・`L1↔R1`・`C↔C`・`D↔A`・`M↔M`。
- [ ] `forward`・`backward` は、盤外へ出ると `null` を返す。
- [ ] 隣接の件数が正しい（角 / 辺 / 中央）。`neighbors4` は 2 / 3 / 4、`neighbors8` は 3 / 5 / 8。
- [ ] `to_key` と `from_key` で往復できる。不正な文字列を `from_key` に渡すと `null` になる。
- [ ] `all()` は15エリアを返す。順序は D→M→A で、各ゾーン内は L2→R2。

### 基本配置の導出 `BaseLayoutDeriver`（アルゴリズム1のエッジケースすべて）
- [ ] レーンの境界: x=35・65 は `C`、x=20・80 は大外、x=50 は `C`。
- [ ] ゾーンの境界: y=100/3 ちょうどは `M`、y=200/3 ちょうどは `A`。
- [ ] GK を数えない。各陣形の合計は 10 になる。
- [ ] `formations.json` を `ContentRepository` で読み込んで導出した、4陣形の基本配置が、アルゴリズム1の表と15エリアすべてで一致する
  （NFR-14、`data-definition.md` §3.1 の検証）。

### 陣形の読み込みと検証
- [ ] 本物の `formations.json` で、`validation_errors()` が空になる。
- [ ] テスト用の壊れたデータで、次の誤りをそれぞれ検出する（設計で、`tests/fixtures/` に置かず、本物を1か所だけ変えてテストの中で作る形に変えた。`design.md`「テスト戦略」）。
  - ID の重複
  - ID の形式違反
  - GK が1人でない
  - 背番号の重複・範囲外
  - 座標が範囲外
  - 選手が11人でない
  - `format_version` の欠落
- [ ] 書き出した APK に `content/formations.json` が含まれる。

### 禁止依存の検出
- [ ] 本物の `game/domain/` では、検出が 0 件で、終了コードが 0。
- [ ] 禁止した API を書いたテスト用のファイルでは、それを検出して終了コード 1 になる。カテゴリ（ノード・ファイル・時刻・乱数）ごとに確かめる。

## 成功指標

- アルゴリズム1の計算結果の表とエッジケースの 100% に、対応するテストがある（NFR-14 のうち、この作業の範囲）。
- 以降の機能の作業で、`PitchArea`・`TeamLayout`・`BaseLayoutDeriver` をそのまま使える（API を作り直さない）。

## スコープ外

以下はこの作業では実装しない。

- アルゴリズム2以降（方式による動き方、選択可能な手、判定、試合の進行、CPU、解説、振り返り）
- 方式・噛み合わせルールなど、ほかの静的データ。NFR-17 のカタログの突き合わせ
- 調整値の Resource（`game/config/`）
- 端末内保存
- アプリケーション層・UI・メインシーン（書き出した APK の起動の確認は、動く骨格の作業へ持ち越す）
- CI の導入（リモートをまだ用意していない）

## 参照ドキュメント

- `docs/specs/1_requirements/functional-overview.md` - データモデル（区分値・ドメイン上の制約）、アルゴリズム1
- `docs/specs/1_requirements/architecture-overview.md` - ドメイン層の禁止事項（NFR-13 の正本）
- `docs/specs/1_requirements/non-functional-requirements.md` - NFR-13・NFR-14・NFR-17
- `docs/specs/1_requirements/repository-structure.md` - `game/` 配下の配置、テストの実行コマンド
- `docs/specs/2_basic-design/component-design.md` - §1（共通の約束）、§2.1〜2.3、§4.1
- `docs/specs/3_detail-design/data/data-definition.md` - §3・§3.1（`formations.json`）
- kit の `coding-gdscript.md`・`testing.md`

## 未決事項

- **禁止依存の検査を書く言語**: 追加の依存なしで、Windows と将来の CI の両方で動くものにする。候補は次の2つで、設計で決める。
  - Godot を画面なしで動かす GDScript（Godot が既に必要なので依存が増えない）
  - Python
- **`TeamLayout` が現在エリアを持つ形**: 選手ごとに持つか、`fixed_area` と `base_area` から導くかを設計で決める。
  アルゴリズム2（方式による動き方）で現在エリアが基本エリアからずれるため、そこで作り直さない形にする。
