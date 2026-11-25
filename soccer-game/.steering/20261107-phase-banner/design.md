# 設計（20261107-phase-banner）

- `PhaseBanner`（`game/ui/screens/s03_match/phase_banner.gd`。PanelContainer）
  - 画面の縦の真ん中に、横いっぱい・高さ 160px の帯。地は `TacticsBoard/bg`（不透明度 0.92）、上下の縁 6px と見出しは、その局面でボールを持つ側の色（攻撃・ポジトラは `you`、守備・ネガトラは `opponent`）。
  - 見出し 64px（`TagLabel` のフォント = Barlow Condensed SemiBold）と一言 28px（`TacticsBoard/text`）。
  - `show_phase(phase)`: 0.15 秒で現れ、合わせて 1.2 秒で消える（Tween。出ている途中なら初めから）。`dismiss()` ですぐ消す。
  - 自分も子もすべて `MOUSE_FILTER_IGNORE`。帯の下の手のボタンを押せる。
- `MatchTexts`: `user_phase(turn_kind, user_has_ball)`（利用者から見た局面）と、局面ごとの見出し・一言（`phase_banner_title`・`phase_banner_line`）。
- `MatchScreen`
  - `_last_phase` を持ち、`enter` で -1 に戻す。得点後（方式の選び直し）・ハーフタイム・再開では画面を開き直すので、キックオフの1ターン目には比べる相手が無く、出ない。
  - `_on_turn_started` で局面が前と違えば `show_phase`。`_on_reveal_started` で `dismiss`（前のターンの帯を次のターンへ持ち越さない）。
  - 帯は盤面パネルの後・メニューの前に足す（メニューは帯より上に重なる）。
- 秒数は演出の設定（`presentation_config`）へ出さず、帯の定数にした。別セッションがその設定を作業中で、今は遊んで見る段階のため。
- チュートリアル（S-08）には出さない（依頼は試合画面）。
