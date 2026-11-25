# 設計（20261108-tutorial-phase-banner）

- 「前の局面と比べて出す」を、画面（MatchScreen の `_last_phase`）から `PhaseBanner` へ移す。
  - `follow(phase)`: 前と変わっていれば `show_phase`、変わらなければ `dismiss`。最初（前の局面が無い）は出さない。
  - `forget()`: 前の局面を忘れて消す。画面の `enter` で呼ぶ。
  - 変わらないときに消すのは、チュートリアルの説明だけの段階（EXPLAIN）には開示が無く、前の段階の帯が開示で消えないため（試合では開示で必ず消えるので、20261107 では外していた）。
- `MatchScreen`: `_last_phase` と `_show_phase_change` をやめ、`enter` で `forget`、`_on_turn_started` で `follow`。動きは同じ。
- `TutorialScreen`: 帯を画面の子に足す（確認のダイアログより下）。`enter` で `forget`、`_on_turn_started` で `follow`、`_on_reveal_started` と最後の段階（`_show_scope`）で `dismiss`。
- 2つの画面で使う部品になったので、`phase_banner.gd` を `ui/screens/s03_match/` から `ui/common/` へ移した（`git mv`。class_name で参照するので呼び出し側は変わらない）。
