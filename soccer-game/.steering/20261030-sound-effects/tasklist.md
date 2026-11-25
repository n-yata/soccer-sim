# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを`[x]`にすること。スキップは技術的理由のときだけ、理由を明記する

---

## フェーズ1: 実装

- [x] 素材を `game/assets/sounds/` に置き、台帳を更新する
- [x] `SoundCues` のテスト → 実装、オートロード `Sfx`
- [x] ボタンのクリック音のテスト → 実装
- [x] 試合の得点・笛のテスト → 実装（`MatchScreen`）

## フェーズ2: 品質チェックと修正

- [x] `tools/run-tests.sh` がすべて通る（67 スイート・911 件。2026-10-30）
- [x] 変異の確認（狙ったスイートだけ。9件中8件を検出。残りの1件（つなぎ直しの確認を外す）は、Godot が二重につながずエラーを出すだけで動きが同じ）
- [x] 実装の検証（review-implementation。4.6/5、[必須] なし。[推奨] 1〜3 を直した）

## フェーズ3: ドキュメント更新

- [x] 仕様書の更新（＋ repository-structure の assets/sounds/）（component-design・screen-03・screen-12・architecture-overview）
- [x] 実装後の振り返りを記録（`retrospective.md`）
