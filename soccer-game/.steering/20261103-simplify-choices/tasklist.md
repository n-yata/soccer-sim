# タスクリスト

## ドメイン
- [x] GameEnums に BACK_PASS・CLOSE_DOWN・BLOCK_SHOT を足す（TurnChoice・MoveOptions.needs_target の対応も）
- [x] MoveRules: バックパス・ボールに寄せる・シュートコースを塞ぐを選べる手に足す（defense_options にボールを渡す）
- [x] OpenPlayJudge: 手で読みを決める・バックパスは NO_CONTEST
- [x] MatchRules._ball_after: NO_CONTEST で運ぶ先があればそこへ
- [x] MoveMenu（新規）: 画面に出す手を選ぶ・枠の対応
- [x] MoveHints: 新しい手のヒント（バックパスは人数を比べない）
- [x] CpuPlanner: 候補を MoveMenu に・方式の癖

## アプリケーション
- [x] MatchController: 利用者の手を MoveMenu に

## 画面
- [x] MatchTexts: 手の名前・枠の名前・一言
- [x] ChoicePanel: 選べる手だけを、番号・行き先・ヒント付きで並べる
- [x] MatchBoardPanel: SELECT_TARGET をなくし、手を押すと READY。盤面に自分の行き先を出す
- [x] BallFlight・JudgeReasonFormatter: バックパス

## コンテンツ
- [x] tutorial.json の文と allowed_actions

## テスト
- [x] move_menu_test を足す
- [x] 既存テストをメニューの手に合わせて直す
- [x] 全体テスト（180 秒以内。161 秒）と --with-balance（入れ替わりの目安の上限を超えた。retrospective.md に記録）

## ドキュメント
- [x] functional-overview.md・component-design.md・screen-03-match.md・glossary.md
