# 設計書

## アーキテクチャ概要

`architecture-overview.md` のレイヤー構成に従う。今回作るのは、ドメイン層の土台と、データ層の陣形の読み込みだけ。

```
data/ContentRepository ──(formations.json を読み、検証して変換)──▶ domain/ContentCatalog
                                                                     │ FormationDef / PlayerSlotDef
                                                                     ▼
                                         domain/layout/BaseLayoutDeriver.derive()
                                                                     │
                                                                     ▼
                                         domain/TeamLayout（PlayerState × 10、現在エリア）
                                                                     │ PitchArea / GameEnums
```

- ドメイン層は `RefCounted` だけを継承し、引数で受け取った値だけで計算する（`architecture-overview.md`「ドメイン層」）。
- データ層だけがファイルを読む。ドメインはデータ層に依存しない（`ContentCatalog` などの値の型はドメインに置く。`component-design.md` §2.2）。

## コンポーネント設計

### 1. `GameEnums`（`game/domain/game_enums.gd`）

**責務**: 区分値の集約。`component-design.md` §2.1 の enum を、同じ名前・同じ並びでそのまま書く。

### 2. `PitchArea`（`game/domain/pitch_area.gd`）

**責務**: 15エリアの1つを表す値と、位置関係の計算。

**実装の要点**:
- `_init(lane: GameEnums.Lane, zone: GameEnums.Zone)`。値は作成後に変えない（変える関数は新しい値を返す）。
- `mirrored()`: レーンは `4 - lane`、ゾーンは `2 - zone`。enum の並び（`L2, L1, C, R1, R2`・`D, M, A`）が鏡像の対応になっていることに依存する。依存していることはコメントで残す。
- `forward()`: ゾーン +1、`backward()`: ゾーン −1。盤外なら `null`。
- `neighbors4()`・`neighbors8()`: 盤内だけを返す。順序は `all()` と同じ（ゾーン → レーンの昇順）にして、結果を決定的にする。
- `to_key()`: `"M-L1"` の形。`from_key()`: 不正なら `null`。
- `all()`: D→M→A、各ゾーンの中は L2→R2 の15個。

### 3. 陣形と配置の値オブジェクト

| クラス | ファイル | 持つ値 | 補足 |
|---|---|---|---|
| `PlayerSlotDef` | `game/domain/player_slot_def.gd` | `id`・`position_type`（`"GK"` など）・`label`・`number`・`x`・`y` | `is_goalkeeper()` は `position_type == "GK"` |
| `FormationDef` | `game/domain/formation_def.gd` | `id`・`name`・`description`・`extra_tags: Array[String]`・`players: Array[PlayerSlotDef]` | — |
| `PlayerState` | `game/domain/player_state.gd` | `player_id`・`base_area`・`fixed_area`（固定されていなければ `null`） | `is_fixed()` |
| `TeamLayout` | `game/domain/team_layout.gd` | `players: Array[PlayerState]` と、選手 ID → 現在エリアの対応 | 下記 |
| `ContentCatalog` | `game/domain/content_catalog.gd` | `formations: Array[FormationDef]` | `formation(id)`（無ければ `null`） |

- ポジション種別は保存データ・静的データでは文字列のまま持つ。`GameEnums` に新しい enum を足さない（`component-design.md` §2.1 の一覧を変えずに済むため）。
  プロパティ名は `type`（GDScript の予約に近く紛らわしい）を避けて `position_type` にする。
- いずれも `duplicate_deep()` を持つ（`component-design.md` §1.1）。

**`TeamLayout` の現在エリアの持ち方**（要求書の未決事項）:
- 選手ごとの現在エリアを、基本エリア・固定とは別に持つ（`_current_areas: Dictionary`。キーは選手 ID、値は `PitchArea`）。
- 理由: アルゴリズム2では、方式の動き（スライド・マーク・保持型の前進）によって、固定されていない選手の現在エリアも基本エリアからずれる。
  現在エリアを `base_area` と `fixed_area` から導く形にすると、アルゴリズム2で作り直しになる。
- 公開する関数:
  - `_init(players: Array[PlayerState], current_areas: Dictionary)`
  - `static func at_base(players: Array[PlayerState]) -> TeamLayout`: 全員の現在エリアを基本エリアにする
  - `current_area_of(player_id: String) -> PitchArea`: いない選手なら `null`
  - `count_at(area: PitchArea) -> int`
  - `counts() -> Dictionary`: 15エリアすべてのキー → 人数（0 も含める。UI とヒントがキーの有無を気にしなくて済むように）
  - `duplicate_deep() -> TeamLayout`

### 4. `BaseLayoutDeriver`（`game/domain/layout/base_layout_deriver.gd`）

**責務**: アルゴリズム1。

**実装の要点**:
- `area_of(x, y)`:
  - レーン: `d = absf(x - 50.0)` とし、`d <= 15` は `C`、`d < 30` はハーフスペース、それ以外は大外。左右は `x < 50` で決める。
  - ゾーン: `y < 100.0 / 3.0` は `D`、`y < 200.0 / 3.0` は `M`、それ以外は `A`。
- 境界の数値（50・15・30・3等分）は、ルールの定義（`functional-overview.md` アルゴリズム1）そのもので、調整値ではない。
  そのため Resource に出さず、名前の付いた定数にする。
- `derive(formation)`: GK を除いた選手について、`PlayerState(player_id, base_area, null)` を作り、`TeamLayout.at_base()` で返す。

### 5. `game/content/formations.json`

- 移植元の4陣形を、`data-definition.md` §3.1 のキー名で書く。最上位は `{"format_version": 1, "formations": [...]}`。
- 背番号は要求書 §5 の表のとおり。
- 移植は、移植元の値を目で写さず、移植元のファイルからスクリプトで機械的に起こす。スクリプトは使い捨てで、リポジトリに入れない。
  そのうえで、要求書の背番号の表と照合する。

### 6. `ContentRepository`（`game/data/content_repository.gd`）

**責務**: `content/` の JSON を読み、検証して `ContentCatalog` に変換する（今回は陣形だけ）。

**実装の要点**:
- `_init(content_dir: String = "res://content")`。テストで別のディレクトリを渡せるようにする（`component-design.md` §4.1 に引数を追記する）。
- `load_catalog() -> ContentCatalog`
  - 読む → 解析する → 検証する → 変換する、の順に行う。
  - 誤りが1件でもあれば、陣形を持たない空の `ContentCatalog` を返す。一部だけ正しいデータで動き続けないようにするため（fail closed）。
  - 誤りは `push_error` で出す。
- `validation_errors() -> Array[String]`: 直前の `load_catalog()` の誤り。まだ読んでいなければ読む。
- 誤りの文字列は `"formations.json: <場所>: <理由>"` の形にする（例: `formations[1].players[3].number: 陣形の中で重複`）。
  テストは、場所を含む誤りがあることを確かめる。
- 検証の項目（`data-definition.md` §3・§3.1）:
  - ファイルの有無・JSON として読めるか
  - `format_version` が 1
  - `formations` が4件で、ID が形式どおりかつ一意
  - `name` が 1〜20 文字、`description` が 1〜200 文字、`extra_tags` が文字列の配列
  - `players` が11件で、GK がちょうど1人
  - 選手 ID が形式どおりで、全陣形で一意
  - `type` が `GK`・`DF`・`MF`・`FW` のいずれか
  - `label` が 1〜4 文字
  - `number` が 1〜99 の整数で、陣形の中で一意
  - `x`・`y` が 0〜100 の数
- JSON の数は Godot では `float` になるので、整数の項目は「小数部が無いこと」で確かめる。

### 7. 禁止依存の検査（`tools/check_domain_deps.gd`）

**責務**: NFR-13。ドメイン層のスクリプトに、禁止した参照が無いことを確かめる。検索する API 名の一覧の正本はこのスクリプト。

**実装の要点**:
- **言語は GDScript にする**（要求書の未決事項）。
  - Godot は、テストの実行と CI にもともと必要なので、依存が増えない。
  - Python はセットアップの手順に無い。
- 実行方法: `godot --headless --path game --script <tools/check_domain_deps.gd の絶対パス> -- <検査するディレクトリ>`。ディレクトリを省くと `res://domain`。
  - `SceneTree` を継承した使い捨ての実行スクリプトで、ドメイン層のコードではない。
  - ファイルを読むのは、検査の道具なので問題ない。
- `.gd` ファイルを再帰的に読み、`#` 以降（コメント）を除いた各行に正規表現を当てる。
- 見つかったら、ファイル・行番号・カテゴリ・パターンを出し、終了コード 1 で終わる。0 件なら 0 で終わる。
- パターンは4カテゴリ（`architecture-overview.md`「ドメイン層」の禁止事項）で持つ。実装レビューの指摘で広げた。
  - ノード: `extends` は許可リスト方式（`RefCounted`・`Resource`・`Object` と、検査対象のディレクトリ内の `class_name` だけを許す。
    行のどこにある `extends` も拾う（1行の `class_name X extends Y`・内部クラス・パス指定を含む）。
    Node の派生には名前が Node で始まらないもの（`Control`・`Timer` など）が多く、禁止側を列挙すると漏れるため）。
    ほかに `Node*` の型名、`SceneTree`、`get_tree(`・`get_node(`・`get_viewport(`・`add_child(`・`queue_free(` などのノード操作、
    `$名前`・`$"パス"`・`%名前`、`Engine.get_main_loop`、`Engine.get_singleton(`・`ClassDB.instantiate(`（文字列で型を渡す経路）
  - ファイル: `FileAccess`・`DirAccess`・`ResourceLoader`・`ResourceSaver`・`ConfigFile`、`load(`・`preload(`・`.load(`・`.load_from_file(`
  - 時刻: `Time`（別名でも見逃さないよう名前そのもの）、`Engine.get_physics_frames`・`get_process_frames`（Godot 4 の `OS` には時刻の関数が無いので対象にしない）
  - 乱数: `randi(`・`randf(`・`randi_range(`・`randf_range(`・`randfn(`・`randomize(`・`seed(`・`rand_from_seed(`、`.shuffle(`・`.pick_random(`
    （配列のこの2つはグローバルな乱数を使う）、`RandomNumberGenerator.new(`（生成器は引数で注入されたものだけを使う）
- 違反を見つけたら、当たった語そのものとルールを出力する。
- **実行時エラーで合格にしない**: GDScript は関数が実行時エラーで打ち切られると戻り値の型の既定値（int なら 0 ＝違反なし）を返し、
  呼び出し側はそのまま進む。そこで、最後まで走ったファイル数・処理を数えて突き合わせ、合わなければ終了コード 2 にする。
  一括実行スクリプトも、終了コードに加えて「最後まで走ったときだけ出る行」と `SCRIPT ERROR` が無いことを確かめる（コミット前レビューの指摘）。
- **検査そのものの空振りを防ぐ**: カテゴリごとに、そのカテゴリの全ルールに当たる行を書いたファイルを `game/tests/fixtures/forbidden_deps/` に置く。
  - `--self-check <カテゴリ>` を付けて実行すると、そのカテゴリの全ルールが1回以上当たり、ほかのカテゴリが当たらないときだけ 0 を返す。
    ルールを足して fixture に足し忘れると、ここで失敗する。
  - fixture の、検出されなければならない行の末尾に `# expect` を付ける。`--self-check` は、目印の付いた行がすべて検出されたことも確かめる
    （1つのルールに複数の書き方を割り当てたとき、2つ目以降の書き方が退行しても気づけるようにするため。コミット前レビュー第2回の指摘）。
  - 継承を許すドメインの `class_name` は、行を正規表現で読まず、Godot が構文解析したグローバルなクラスの一覧から取る
    （複数行の文字列の中の `class_name X` にだまされないため）。`ClassDB`・`Expression` は名前ごと禁止する（文字列で型・式を渡す経路）。
  - 一括実行スクリプトは、本番の検査の前に、4カテゴリの自己確認・誤検出しないこと（`clean/`）・検査できない対象
    （無いディレクトリ、スクリプトが0件のディレクトリ）が終了コード 2 になることを確かめる（fail closed）。
  - 置くファイルはどれも、Godot として正しい構文で書く（エディタの取り込みでエラーにならないように）。

### 8. 一括実行スクリプト（`tools/run-tests.sh`）

- bash で書く（Windows では Git Bash、CI では Linux のシェルで動く）。Godot は環境変数 `GODOT_BIN`、無ければ `godot` を使う。
- 次の順に実行し、1つでも失敗したら終了コード 1 で終わる。
  1. 禁止依存の検査の自己確認（fixture ごとに、全ルールと `# expect` の全行が検出されること、`clean/` で誤検出しないこと、検査できない対象が失敗になること）
  2. `game/domain/` の禁止依存の検査（0 件であること）
  3. gdUnit4 の CLI（`repository-structure.md` 手順2のコマンド）。テストが0件で正常終了したときも、失敗として扱う（空振りの防止）

## データフロー

### 陣形の基本配置を得る
1. データ層: `ContentRepository.new().load_catalog()` が `res://content/formations.json` を読み、検証して `ContentCatalog` を返す。
2. 呼び出し側（後の作業ではアプリケーション層）: `catalog.formation("4-4-2")` で `FormationDef` を得る。
3. ドメイン層: `BaseLayoutDeriver.derive(formation)` が、10人の `TeamLayout` を返す。`counts()` で15エリアの人数を得る。

## エラーハンドリング戦略

- ドメイン層は例外を投げない。
  - 不正な入力は `null` で返す（`from_key` の不正な文字列、盤外の `forward` など）。
  - `null` を返しうる関数は、ドキュメントコメントに書く（`component-design.md` §1.1）。
- データ層の静的データの誤りは、開発時の誤りとして扱う（`data-definition.md` §4）。
  - `validation_errors()` に出して、テストを失敗させる。
  - `load_catalog()` は空のカタログを返す。

## テスト戦略

### ユニットテスト（gdUnit4。`game/tests/` に、対象と同じ構成で置く）
- `tests/domain/pitch_area_test.gd`:
  - 15エリアの鏡像の往復と対応表
  - 盤外の `forward`・`backward`
  - 角・辺・中央の隣接の件数と中身
  - キーの往復・不正なキー
  - `all()` の順序
- `tests/domain/team_layout_test.gd`:
  - `at_base` で現在エリアが基本エリアと一致する
  - `counts()` が15キーを持ち、合計が人数に一致する
  - 現在エリアを変えた配置で、人数がそちらに従う
  - `duplicate_deep()` が元を共有しない
- `tests/domain/layout/base_layout_deriver_test.gd`:
  - アルゴリズム1のエッジケースすべて: レーンの境界、ゾーンの境界（100/3・200/3 ちょうど）、x=50、GK の除外
  - 手で組んだ陣形で、合計が10になる
- `tests/data/content_repository_test.gd`:
  - 本物の `formations.json` で誤りが 0 件になり、4陣形・各11人が変換される
  - 壊れたデータで、誤りの種類ごとに検出する。さらに `load_catalog()` が空のカタログを返す
- `tests/data/formations_base_layout_test.gd`:
  - 本物の `formations.json` から導出した4陣形の基本配置が、アルゴリズム1の表（期待値はテストに表として書く）と15エリアすべてで一致する

**壊れたデータの作り方**（要求書の「`tests/fixtures/` に置く」から変える）:
- テストの中で、本物の `formations.json` を読み、1か所だけ変えて、テスト用の一時ディレクトリ（`user://` の下）に書く。それを `ContentRepository` に読ませる。
- 理由:
  - 本物の陣形データを手で写した fixture を7種類置くと、本物を直したときに fixture が古いまま残る。
  - 本物から1か所だけ変える形なら、「その1か所の誤りだけが検出される」ことまで確かめられる。
- 禁止依存の検査の fixture（`tests/fixtures/forbidden_deps/`）は、陣形データとは関係ないので、ファイルとして置く。

### 統合テスト
- 書き出した APK に `content/formations.json` が含まれることを確かめる（`aapt` ではなく、APK の中身の一覧で見る）。

## 依存ライブラリ

追加なし（Godot 4.7.2・gdUnit4 6.2.2 のみ）。

## ディレクトリ構造

```
game/
├── content/formations.json
├── data/content_repository.gd
├── domain/
│   ├── game_enums.gd
│   ├── pitch_area.gd
│   ├── player_slot_def.gd
│   ├── formation_def.gd
│   ├── player_state.gd
│   ├── team_layout.gd
│   ├── content_catalog.gd
│   └── layout/base_layout_deriver.gd
└── tests/
    ├── domain/{pitch_area_test.gd, team_layout_test.gd, layout/base_layout_deriver_test.gd}
    ├── data/{content_repository_test.gd, formations_base_layout_test.gd}
    └── fixtures/forbidden_deps/{node/{node_ref.gd, inner_class_ref.gd}, file/file_ref.gd, time/time_ref.gd,
                                random/random_ref.gd, clean/clean_ref.gd}
tools/
├── check_domain_deps.gd
└── run-tests.sh
```

## 実装の順序

1. 一括実行スクリプトと禁止依存の検査（以降のテストを、毎回この1本で回すため）
2. `GameEnums` → `PitchArea`（テスト先行）
3. `PlayerSlotDef`・`FormationDef`・`PlayerState`・`TeamLayout`・`ContentCatalog`（テスト先行）
4. `BaseLayoutDeriver`（テスト先行）
5. `formations.json` の移植 → `ContentRepository`（テスト先行）→ 4陣形の表のテスト
6. 書き出しの確認、文書の更新

## セキュリティ考慮事項

- 外部通信・個人情報・シークレットは扱わない。
- 静的データはアプリに同梱する信頼できる入力だが、`ContentRepository` は型を確かめてから値を使う。
  型の誤ったデータで実行時エラーにならないようにするため。

## パフォーマンス考慮事項

- 起動時に1回、数KBの JSON を読むだけ。`PitchArea.all()` などは15要素で、計算量の問題は無い。

## 将来の拡張性

- `ContentCatalog` には、ほかの静的データ（方式・噛み合わせルールなど）を、使う作業ごとに足す。
  `ContentRepository` の検証も、ファイルごとの関数を足す形にする。
- `TeamLayout` は現在エリアを独立して持つので、アルゴリズム2（`StyleLayoutCalculator`）は、新しい現在エリアを渡して新しい `TeamLayout` を作るだけで済む。
- 禁止依存の検査は、ディレクトリを引数で受け取る。ほかの層の制約にも使い回せる。
