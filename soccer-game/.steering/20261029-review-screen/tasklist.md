# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを`[x]`にすること。スキップは技術的理由のときだけ、理由を明記する

---

## フェーズ1: ドメイン（アルゴリズム10）

- [x] 値 `ReviewSummary`・`ReviewGoal`・`ReviewSegment` を作る
- [x] `ReviewAggregator` のテストを書く（失敗から始める）
  - [x] 数え方の表・局面・エリアの鏡像
  - [x] 得失点の遡り（上限・ハーフの境・続けての得点・1ターン目）
  - [x] 時間帯（連続・ハーフの境・方式変更）・NO_CONTEST だけ・0件
- [x] `ReviewAggregator` を実装してテストを通す

## フェーズ2: 設定値とアプリケーション

- [x] `PresentationConfig.review_lookback_turns`（初期値 3、範囲 0 以上）と `.tres`・`ConfigRepository` の確認・テスト
- [x] `RevealView` に `half`・`turn_number`、`ViewConverter.reveal` で入れる
- [x] `ReviewView` と `MatchController.review()`・テスト（変換は `ViewConverter.review` に置いた）

## フェーズ3: UI

- [x] `ReviewTexts`（札・時間帯・得点の見出し）とテスト
- [x] `TacticsBoard.show_tally` と描画・テスト（奥の行に収まるよう字を縮める。下限 11px は実測で決めた）
- [x] `MiniPitch` の2チーム表示・矢印・マスの大きさ・テスト（screen-common.md の「1−0」の形に合わせた）
- [x] `ReviewScreen`（4タブ・得点のカード・空の表示・戻る）と画面テスト（ヘッダーにタブを置く `ScreenHeader.add_to_right` を足した）
- [x] `ResultScreen` の「振り返り」ボタンとテスト
- [x] `MainShell.SCREEN_SCENES` に S-07

## フェーズ4: 品質チェックと修正

- [x] すべてのテストが通ることを確認
  - [x] `tools/run-tests.sh`（取り込み・禁止依存の検査・gdUnit4）（初回は main_shell_test が「未作成の画面」の例に S-07 を使っていて失敗 → S-08 へ。孤立ノード2件 → タブを組み立て時にヘッダーへ入れて解消）
- [x] **テストが実際に実行されたことを確認**（46/46 スイート・697/697 件）
- [x] 集計の変異の確認（集計のスイートだけ。10個すべて KILLED、約20秒）
- [x] PC のウィンドウで振り返り画面を開いて見た目を確認（スクリーンショット。タブが縮められて1つずつしか見えない・得失点の文が狭い・凡例の色が棒と結びつかない、の3点を直した。一時的なシーンは消した）

## フェーズ5: ドキュメント更新

- [x] 仕様書の「今回の範囲」の注記を更新（component-design.md の ReviewSummary・§3.5・§4.2、repository-structure.md、screen-common.md の MiniPitch・TacticsBoard・ScreenHeader、screen-07-review.md の幅と描き方）
- [x] 実装後の振り返りを記録（`retrospective.md`）
