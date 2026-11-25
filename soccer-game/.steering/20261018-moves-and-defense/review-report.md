# コミット前レビューレポート

## 第1回（2026-10-18）
- 対象: アルゴリズム3・4の未コミット差分すべて（18ファイル）。
  - 新規ドメイン: `turn_choice.gd`・`move_options.gd`・`judge/move_rules.gd`・`layout/defense_mover.gd`
  - 新規テスト: `move_values_test.gd`・`judge/move_rules_test.gd`・`layout/defense_mover_test.gd`
  - `.uid` 7本
  - `component-design.md` の変更
  - `.steering/20261018-moves-and-defense/` の3文書
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 2件
- 備考: 実装レビュー（review-implementation。総合 4.6/5、[必須] なし）の指摘は、このレビューの前に対応済み（tasklist.md に記録）

## コミット前レビュー結果

未コミットの差分（18ファイル）を全部読んだ。結論から言うと、**Critical / High の指摘はない。コミットして大丈夫**。ファイルは一切変更していないし、Godot も起動していない。

対象: `git status -uall` で出る未コミットの差分すべて。差分が依存している既存の `PitchArea`、`TeamLayout`、`LayoutPair`、`PlayerState`、`GameEnums`、それと仕様の正本（functional-overview.md のアルゴリズム3・4）も読んで照合した。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
- **[バグ] `MoveOptions` が手と API の組み合わせ違いを黙って受け付ける**
  - 運ぶ先を持つ手（例: `PRESS`）に `allow` を呼んでも、運ぶ先を持たない手（例: `SHOT`）に `add_target` を呼んでも、エラーにならない。
  - その結果は `is_available` から見えないまま残る。いまの呼び出し元は `MoveRules` だけで、使い方は正しいので実害はない。
  - 将来 `options_for` などで呼び出し元が増えたときに、取り違えても誰も気づけない。
  - 対応案: 先頭に `assert(needs_target(family, action))` / `assert(not needs_target(family, action))` を入れる。debug ビルドでだけ検出され、本番の挙動は変わらない。
  - 足すなら、テストの前提として「`allow(DEFENSE, PRESS)` だけでは `is_available` が false」を固定しておくとよい。
- **[運用] tasklist の件数表記**
  - フェーズ5の「`tools/run-tests.sh` が成功する（213件）」と、下の推奨対応の行にある 217件が混在している。
  - 記録として誤りではないが、最終の件数が分かりにくい。

### 問題なし
**セキュリティ**
- ① ハードコーディング（.uid・.md を含む全18ファイルで確認）
  - URL・エンドポイント、シークレット・キー・トークン・パスワード、クラウドのアカウント情報（ARN や 12桁の ID）は見つからなかった。
  - ドキュメント内の機密も見つからなかった（ローカルの絶対パス、ユーザー名、メールアドレス、artifact のリンク）。
  - grep のヒットは component-design.md 内の型名 `UserSettings` だけで、誤検知。
  - `.uid` はどれも `uid://...` の1行だけ。
- 制御文字・不可視文字
  - タブ以外の制御文字、NUL、ゼロ幅文字・双方向制御文字・NBSP・全角スペースなどの書式文字（Unicode Cf/Zs/Co/Cn）、BOM、CR は、全ファイルで0件。
  - GDScript 7本に、スペースで始まるインデント行はない（インデントはタブ）。
- ②〜④ と OWASP
  - 差分は純粋なドメイン計算で、外部通信・永続化・入力の取り込み・ログ出力・認証認可を持たない。そのため該当なし。
  - `is_allowed` は、不正な family/action の組み合わせや、範囲外の action を安全側（false）で拒否する。fail open ではない。

**バグ・正しさ**（仕様の表と1項目ずつ照合した）
- `attack_options` は仕様どおり。
  - SHORT_PASS: 隣接8エリアで味方あり。
  - DRIBBLE: 前・左右。後ろへは運べず、盤外は `forward()` の null と `equals(null)` が false になるため除かれる。
  - LONG_BEHIND: D から A ゾーンへ、レーン差が1以内。
  - SWITCH: 同じゾーンでレーン差が3以上。
  - SHOT: A ゾーンの C・L1・R1。
- `defense_options`
  - T_d の鏡像化は正しい。
  - PRESS は上下左右の隣接だけを見る。
  - COVER は守備側の D ゾーンを除き、T_d 自身と隣接を見る。
- `DefenseMover.apply`
  - `defense_options` と条件が一致している。COVER の T_d は D 以外なので、`backward()` は null にならない。
  - 余りは攻撃側の人数を `area.mirrored()` で数えている。
  - 同率の順位: 前方 → 横（中央寄り、同じなら守備側の左 = lane 値が小さい方）→ 背後。
  - 固定されていない選手を優先し、固定された選手しかいなければ固定先を更新する。
  - 入力を変更しない（全部コピーする）。
- `_pick_player` が null を返さないことは、`count_at` と同じ `current_area_of` を使っている前提から保証される。
- 境界: 角や端のエリア、A ゾーンからのカウンター、守備側がいないケースは、テストで固定済み。
- 選択の決定性: `PitchArea.all()` の順に処理し、優先順も固定してあるので、結果は毎回同じになる。
- テストの質
  - 期待値は仕様から手で書かれていて、実装をコピーした恒真テストではない。
  - `defense_options` ⇔ `apply` の整合テストには件数の検査（120件）があり、ループの空振りを防いでいる。
  - 視点の取り違え（守備側の座標のまま渡す）を拒否するテストもある。

**性能**
- 15エリア × 選手数（11程度）の固定規模の線形走査だけ。上限のない入力や I/O はない。

**運用**
- 設計書（component-design.md §2.2〜2.4）に、`MoveOptions` の API、`MoveRules` の下位の関数、`options_for` を後で足すこと、`DefenseMover` で実装時に決めたことが反映されている。
- 純粋な追加と文書の追記だけなので、revert で戻せる。

### 未検証
- テストの実行（依頼の指示で実行していない。依頼元の実行では 217件成功とのこと）。
- Godot の静的解析・型警告（エディタやヘッドレスを起動していないため）。
- Godot 4 で `_targets[key] as Array[PitchArea]` の cast が参照を返すことは、実行では確かめていない。`test_move_with_target_is_available_only_when_it_has_targets` などが通っていることを根拠に、問題ないと判断している。
- `.steering` の requirements.md と design.md は、機密・制御文字の機械的な検査だけで、内容の精読はしていない。

### 総合評価
**Critical / High の指摘はない。コミットしてよい。** Low の2件は申し送りでよい。1件目は、直すなら assert 追加とテストの固定をセットにするのを勧める。

### 対応
- Low（`MoveOptions` の組み合わせ違い）: 申し送る。`assert` は gdUnit4 のテスト実行（debug）でも止まるため、異常系のテストを書くと実行が止まる。呼び出し元を足す作業（`options_for`）で、`push_error` で知らせる形とテストをいっしょに入れる（振り返りに記録）。
- Low（tasklist の件数表記）: 直した。「実装時 213件。実装レビューの対応後 217件」と書いた。
- 未検証のテスト実行・型警告: 依頼元がコミット直前に `bash tools/run-tests.sh` を実行して確かめる（下の「レビュー完了」に結果を書く）。
- Critical / High を直したものではないため、再レビューは行わない（スキルの規則）。

## レビュー完了（2026-10-18）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- コミット直前のテスト: `bash tools/run-tests.sh` で 217 件成功（19スイート）、禁止依存の検査 0 件、SCRIPT ERROR なし
- 積み残し（Low）: `MoveOptions` の組み合わせ違いの検出（`options_for` の作業で、知らせる形とテストを入れる。今の呼び出し元は正しく使っている）
