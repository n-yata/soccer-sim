# 設計

- `ChoicePanel`: ボタンの文字を「番号 + 枠の名前」だけにし、`columns = 2`。ヒントと行き先の引数を外す
- `MoveDetailView`（新規。`ModalOverlay` を継承）: 見出し・本文・「閉じる」。`open(title, lines)` は空の行を出さない。`MatchBoardPanel` の最後の子に置く
- `MatchBoardPanel`:
  - `TargetInfo` とスクロールの処理をやめる
  - 主ボタンを `PrimaryRow`（HBox）に入れ、左に「詳細」（幅 128px・高さは主ボタンと同じ 112px）を置く。高さを足さないので、手のボタンの下に余白が残る
  - 手を選んだときに詳細の見出しと行（`MatchTexts.choice_target_line`・ヒントの札と人数・`MatchTexts.target_rule`）を作り、「詳細」を押せるようにする
  - ターンの頭で押せなくしてポップアップを閉じ、判定理由の表示で隠す
- `tutorial.json`: 攻撃の段階の説明を、ボタンに行き先が出ない形に合わせる
- テスト: ボタンの文字、詳細の開閉と中身、画面の実寸でボタンがスクロールなしで見えること
