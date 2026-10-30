# コミット前レビューレポート

## 第1回（2026-10-30）
- 対象: 効果音の変更一式（`game/ui/common/sound_cues.gd`・`.uid`、`game/project.godot` のオートロード、`game/ui/screens/s03_match/match_screen.gd`、`game/assets/sounds/*.ogg`・`.ogg.import`、`game/assets/LICENSES.md`、`game/tests/ui/sound_cues_test.gd`・`.uid`、`game/tests/ui/match_screens_test.gd`、仕様書5本、`.steering/20261030-sound-effects/`）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 3件

## コミット前レビュー結果

対象: 依頼で指定された効果音の変更一式を見た。具体的には `game/ui/common/sound_cues.gd`（.uid を含む）、`game/project.godot` のオートロード、`game/ui/screens/s03_match/match_screen.gd`、`game/assets/sounds/*.ogg` と `.ogg.import`、`game/assets/LICENSES.md`、`game/tests/ui/sound_cues_test.gd`、`game/tests/ui/match_screens_test.gd` の差分、仕様書5本の差分、`.steering/20261030-sound-effects/requirements.md`。あわせて、直接の呼び出し元の `game/ui/board2d/match_board_panel.gd`（シグナルを出す順序）、`game/application/app.gd`（`_ready`）、`game/export_presets.cfg` も確認した。Godot とテストは指示どおり実行していない。

### Critical（即時対応必須）
- 指摘なし

### High（優先対応）
- 指摘なし

### Medium（対応推奨）
- 指摘なし

### Low / 改善提案
- [バグ] `SoundCues._ready` は、`Cue.values()` の値をそのまま `Cue.keys()` の添字に使っている。enum に値を明示していない今は 0 から連番なので正しく動く。将来 `Cue` に値を明示すると（例 `WHISTLE = 10`）添字がずれて落ちる。直すならこう書ける:
  ```gdscript
  for key: String in Cue.keys():
      var cue: int = Cue[key]
      player.name = key
  ```
  今のままでも害は無い。申し送りでよい。
- [バグ] `MatchScreen._reveal` は画面を出るときも消していない。`match_board_panel.gd` を見ると、`reveal_started` と `result_shown` は `_on_turn_resolved` の中で必ずこの順に続けて出る（358行・377行）。前のターンの値で得点の音を誤って鳴らす経路は無い。
- [運用] `Sfx` は `node_added` を見てボタンにつなぐ。このため、`Sfx` より先に木に入ったボタンはクリック音が鳴らない。`App._ready` はボタンを作らず、メインシーンはオートロードの後に読まれるので、今は該当するボタンが無い。オートロードの順序（`App` → `Sfx`）を変えるとき、または `App` が UI を持つようになったときに注意が要る。

### 問題なし
- **セキュリティ**
  - ハードコーディング: 秘密の値、外部の URL、クラウドのアカウント情報は無い。コードにある `res://assets/sounds/*.ogg` はパッケージ内のパスなので該当しない。仕様書と台帳にある URL らしき記述は `www.kenney.nl`（作者の表記）とファイル名だけで、機密は含まない。
  - `.gitignore`: `.env` と `.env.*` が除外されていることを確認した。今回の差分で新しい秘密の値は増えていない。
  - 認証・認可、インジェクション、情報漏洩: 差分に該当するものは無い。外部との通信、ユーザーの入力、ログの出力が無く、音のファイルは同梱のリソースを `load` しているだけ。
  - OWASP: 差分に該当するカテゴリは無い。A08（安全でない取り込み）について: .ogg の先頭が `OggS` で Ogg 形式であること、`.import` が標準の `oggvorbisstr` インポーターでループ無しの設定であることを確認した。A06（依存関係）について: 新しい依存は無い。
- **素材のライセンス**
  - 笛: Wikimedia Commons の `File:218318 splicesound referee-whistle-blow-gymnasium.wav` のページを取得して確かめた。ライセンスは CC0 1.0、作者は SpliceSound、元は freesound の 218318 で、台帳の記載と一致する。
- **書き出し**
  - `export_filter="all_resources"` なので、取り込み済みの `.oggvorbisstr` は書き出しに入る（`.import` が `.godot/imported/` へ割り当てている）。
  - `exclude_filter="tests/*, addons/gdUnit4/*"` は `assets/sounds/` に当たらない。
  - 依頼の見立てどおり、`include_filter` に足す必要は無い。`include_filter` は `.json` や `OFL.txt` のようなリソースでないファイル用。
- **バグ**
  - 鳴らす時点が仕様（`screen-03-match.md`）および受け入れ条件と一致している。キックオフの笛は `turn_number == 1`、得点の音は `turn_winner` で自分か相手かを分ける、ハーフの終わりは `is_half_over` で笛、得点とハーフの終わりが重なれば両方鳴らす。
  - チュートリアルは `MatchBoardPanel` を使うが `MatchScreen` は使わない。得点と笛が鳴らないのはスコープ外として仕様どおり。
  - ボタンを木から外して入れ直しても、`is_connected` で調べているので二重につながらない。テストでも固定してある。
  - テストは実際の振る舞いを確かめている。音ファイルが読めて長さが 0 より大きいこと、SE バスで鳴ること、音ごとに別のファイルであること、`playing` が真になること、場面ごとの音の並びを試合1つ分すべて比べること、得点が1回以上起きる（空振りしない）こと。シグナルの切断も `after_test` に移っている。
- **性能**
  - `node_added` の処理はノード1つにつき型の確認だけで、ほぼ負荷にならない。`AudioStreamPlayer` は4つを1回だけ作る。ループの中で I/O はしていない。
- **運用**
  - 音量は SE バスに統一されていて、設定の効果音音量がそのまま効く。
  - revert で戻せる。オートロード1行と、新しいファイルを足しただけ。
  - 仕様書（アーキテクチャ・リポジトリ構造・コンポーネント・S-03・S-12）と台帳が更新されている。

### 未検証
- Kenney の素材2つ（Interface Sounds、85 Short music jingles）のライセンス: OpenGameArt のページは HTTP 403 で取得できなかった。zip に同梱されたライセンスの文もリポジトリに無く、確かめられていない。Kenney の素材は一般に CC0 で公開されているが、台帳の記載が正しいことは今回は確認していない。
- テストが通るか: 指示に従い Godot を実行していない。
- 書き出したパッケージに音が実際に入っているか: 書き出しを実行していない。設定ファイルを読んで判断しただけ。

### 総合評価
Critical / High の指摘は無い。コミットしてよい。Kenney 2つのライセンスは、手元の zip の `License.txt` を見るか、ブラウザで調達元のページを見て、念のため確かめてほしい。

### 対応
- Low 1（enum の値を添字に使う）: 直した。名前から値を引く形にした（`for key: String in Cue.keys(): var cue: int = Cue[key]`）。
- Low 2（`_reveal` を消さない）: 直さない。レビューの見立てどおり、`reveal_started` と `result_shown` は同じ呼び出しの中で続けて出るので、前のターンの値で鳴らす経路が無い。
- Low 3（`Sfx` より先に木に入ったボタン）: 直さない。今は該当するボタンが無い。オートロードの順序の注意は `sound_cues.gd` のコメントに足した。
- 未検証の Kenney のライセンス: 素材を取った時点（2026-10-30）に、zip に同梱の文を確かめてある。Interface Sounds の `License.txt` は「License: (Creative Commons Zero, CC0)」（Interface Sounds 1.0、2020-02-11）、85 Short music jingles の `license.txt` は「License (CC0)」。zip はリポジトリに入れていない（台帳に調達元とファイル名を記録）。

## レビュー完了（2026-10-30）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し: Low 2・3 は上の理由で直さない（Low 3 はコードのコメントで申し送る）
