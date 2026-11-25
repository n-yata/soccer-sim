# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）
- タスクが大きすぎる場合は、サブタスクに分割して1つずつ完了させる

---

## フェーズ1: LibraryService

- [x] `tests/application/library_service_test.gd` を書き、失敗することを確かめる
- [x] `LibraryService` と `App.library` を作り、テストを通す

## フェーズ2: 共通の部品

- [x] `screen_header_test.gd`・`mini_pitch_test.gd`・`formation_card_test.gd` を書き、失敗することを確かめる
- [x] テーマに `MiniPitch` の色と `SectionTitleLabel`・`CheckMarkLabel` を足す
- [x] `ScreenHeader`・`MiniPitch`・`FormationCard` を作り、テストを通す（`FormationCard.show()` は `CanvasItem.show()` とぶつかるため `show_formation()` にした。陣形名の型の変化形 `FormationNameLabel` も足した）

## フェーズ3: 試合準備の画面

- [x] `match_setup_screen_test.gd` を書き、失敗することを確かめる
- [x] `MatchSetupScreen` を作り、テストを通す
- [x] `MainShell.SCREEN_SCENES` に S-02 を登録し、タイトル（「CPU 対戦」が押せる）と MainShell（押すと試合準備に切り替わる）のテストを足す（「行き先が無い」テストは S-03 に置き換えた。131件）

## フェーズ4: 実際の画面での確認

- [x] PC で、タイトル → 試合準備 → 選ぶ → 戻る、を撮る（16:9・20:9）
  - 一時的なオートロードで操作を流し込み、`--write-movie` で撮った。選択中の黄色の縁と ✓、Esc でタイトルへ戻る（handled=true）ことを確かめた
  - ミニピッチのハーフウェイラインが中盤の数字と重なって読みにくかったので、線をやめた
- [x] エミュレーターで、試合準備を開いて戻る操作でタイトルへ戻る（アプリは閉じない）ことを確かめる（「KICK OFF」をタップして試合準備が開き、戻る操作でログ1行 handled=true、タイトルの画面、プロセスは残った。アプリはアンインストールした）

## フェーズ5: 文書の更新

- [x] `component-design.md`: `LibraryService` の作った関数、`App.library` の作り方、名前の一覧（`ScreenHeader`・`MiniPitch`・`FormationCard` は既にある）
- [x] `screen-02-match-setup.md`: 作る順序（解説欄・試合開始・`STARTING` は後の作業）
- [x] `screen-common.md` §5: `FormationCard` のルートが `Control` で、中に全面のボタンを置く理由

## フェーズ6: 品質チェックとコミット

- [x] `tools/run-tests.sh` が成功する（137件）
- [x] 実装レビュー（review-implementation）を行い、指摘を直す（総合 4.0/5、[必須] なし。1回目は利用上限で中断し、同じエージェントで再開した。[推奨] 4件・[提案] 3件はすべて対応: 実際の押下（トグルの反転）を再現するテストを足し、トグルを戻す行を消す変異が検出されることを確認、カードを陣形 ID で結び付けて人数を1回だけ求める、Doc comment、design.md の更新、間隔 16px・カードの高さ、陣形0件のテスト）
- [x] コミット前レビュー（review-pre-commit）を行い、新たな Critical / High が無くなるまで直す
- [x] 振り返りを `retrospective.md` に記録する
- [x] main へコミットする（ファイルを名指しでステージする）
