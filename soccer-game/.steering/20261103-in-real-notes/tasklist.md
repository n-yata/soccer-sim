# タスクリスト: 解説の「実戦では」（FR-23）

## フェーズ1: データ
- [x] `styles.json` の POSSESSION と、`matchup_rules.json` の S01・S03・S05・S06・R07・R12・R02・R13・R14 に単純化 ID を付ける

## フェーズ2: 表示
- [x] `notes_view_test` に「実戦では」のテストを足す（先に落ちることを確かめる。存在しない API で落ちた）
- [x] `NotesView.show_notes` に単純化カタログを渡し、「実戦では」を出す
- [x] S-02・S-04・S-05 の呼び出しでカタログを渡す
- [x] `match_setup_screen_test` に保持型の「実戦では」のテストを足す

## フェーズ3: 品質チェック
- [x] 対象のスイートが通る（notes_view 7・S-02 17・S-04/S-05 18・content 7・repository 40・library 15・generator 9）
- [x] `tools/run-tests.sh` が 180 秒以内で通る（166秒・1095件・失敗0。1回目は読み込みのテストの単純化 ID の一覧が SIM-07 だけで落ちたので、カタログ全体に広げた）
- [x] 実装の検証（review-implementation）の推奨に対応（S-04 のつなぎ込みの確認を1行足した。S-04 の2つの欄の重なりは欄ごとに除くと明記した）

## フェーズ4: ドキュメント
- [x] 仕様書の更新（screen-common の NotesView・component-design の NotesView と §2.7 の注記・functional-overview のアルゴリズム9）
- [x] 振り返り（`retrospective.md`）
