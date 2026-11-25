# 設計: 効果音

## 部品

- `SoundCues`（`game/ui/common/sound_cues.gd`、`Node`）をオートロード `Sfx` にする（UI 層。ドメイン・アプリケーション層は音を知らない）。
  - `enum Cue { CLICK, GOAL_FOR, GOAL_AGAINST, WHISTLE }` と、音 → ファイル（`res://assets/sounds/*.ogg`）の対応を1か所に持つ。
  - 音ごとに `AudioStreamPlayer` を1つ（`bus = &"SE"`）。同じ音を重ねて鳴らすときは頭から鳴らし直す。
  - `play(cue)` で鳴らし、`cue_played(cue)` を出す（テストはこの信号で、どの場面で何を鳴らしたかを確かめる）。
  - `_ready` で `get_tree().node_added` を受け、木に入った `BaseButton` の `pressed` に `CLICK` をつなぐ（画面ごとに足さなくてよい）。
- 試合の音は `MatchScreen` が鳴らす（チュートリアルは同じパネルを使うが、画面が違うので鳴らない）。
  - `_on_turn_started(snapshot)`: `snapshot.turn_number == 1` なら `WHISTLE`（前半・後半のキックオフ。再開した試合の1ターン目でも鳴る）。
  - `_on_result_shown(snapshot)` に開示が要るので、`_on_reveal_started` で受けた `RevealView` を覚えておく。
    得点（`outcome == GOAL`）なら `MatchTexts.turn_winner` で `GOAL_FOR` / `GOAL_AGAINST`。`snapshot.is_half_over` なら `WHISTLE`。

## 素材

`game/assets/sounds/` に `click.ogg`・`goal_for.ogg`・`goal_against.ogg`・`whistle.ogg`。台帳は `game/assets/LICENSES.md`「効果音」。
音の選び方: 聞いて選べないので、ジングルは音の高さの動き（上がる＝得点、下がる＝失点）で選んだ。

## 仕様書

- `component-design.md`: UI 層の部品の表に `SoundCues`（オートロード `Sfx`）を足す。オートロードの記述があればそこにも。
- `screen-03-match.md`: 鳴らす時点を足す。
- `screen-12-settings.md`: 「素材はまだ無い」を直す。
- `architecture-overview.md`: 「外部の素材を使わない」の注記に、効果音は CC0 を使うことを足す（台帳への参照だけ）。
