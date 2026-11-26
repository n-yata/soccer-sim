# タスクリスト

## フェーズ1: 土台

- [x] テストを先に書く（`MainShell` の縦の判定・基準解像度・上下の余白、`ScreenSwitcher` の向きの伝え方。Red を確認）
- [x] `AppScreen.set_portrait`・`_apply_orientation`、`ScreenSwitcher.set_portrait`、`MainShell` の切り替えと余白
- [x] `project.godot` の向き（Sensor）と、PWA の manifest の向き（any）

## フェーズ2: 3画面

- [x] テストを先に書く（3画面の縦の配置・横に戻す・試合画面で選んだ手が残る）
- [x] S-01 タイトル（カードを下に寄せ、余った高さはプロダクト名の区画へ。縦長の端末のテストを足した）
- [x] S-02 試合準備
- [x] S-03 試合（上部バー2段・`MatchBoardPanel.set_portrait`）
- [x] `HBoxContainer` を `BoxContainer` に（`vertical` を変えられないため。テストで見つけた）

## フェーズ3: 確認

- [x] `soccer-game/tools/run-tests.sh`（86スイート・1231件成功）
- [x] ブラウザ版を書き出し、390×844 でタイトル → 試合準備 → 試合 → 開示中に横へ回して戻す → 次のターン（エラーなし）
- [x] 回したときに画面が歪む不具合を直した（基準解像度の変更を `call_deferred` に）

## フェーズ4: ドキュメント

- [x] 要件定義書（対象プラットフォーム）・非機能要件（NFR-25）・リポジトリ構造（プロジェクト設定）
- [x] 画面設計（画面の向きと基本の配置・S-03 の縦）・`screen-common.md` §1.2・コンポーネント設計
- [x] 画面詳細（S-01・S-02・S-03）
- [x] ワイヤーフレーム（S-01〜S-03 に縦の枠）
- [x] コミット前レビュー（`review-pre-commit`）→ `review-report.md`（Critical / High なし。Medium 1・Low 2 を修正）
- [x] 振り返り（`retrospective.md`）
