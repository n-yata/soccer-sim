# 振り返り（20261106-play-feedback）

## 実装の内容
- オフサイド
  - 攻守ターン: 判定前と判定時の2つの配置のどちらかでオフサイドなら OFFSIDE（`OpenPlayJudge`）。守備の手でラインが下がってもオンサイドにならない。
  - カウンター: 受け手を走り込む前の位置で、奪った時点のラインと比べる（`OffsideRule.counter_offside_area`）。判定・ヒント・プレビューが同じ関数を使う。
  - 盤面のオフサイドラインを、奪った側のトランジションでも出す（`ViewConverter.offside_line_zone`）。
- 試合準備（S-02）の解説: 欄を消し、「解説を見る」ボタンとポップアップ（`NotesPopup`）にした。戻る操作は、開いていれば先に閉じる。
- 1拍: 決定前のプレビューは [開始, 次のターン開始]（シュートは [開始, 判定時]）。開示は1拍で、得点だけ2拍（`MatchBoardPanel.reveal_keyframes`）。
- 仕様書: functional-overview・glossary・requirements-definition・repository-structure・component-design・screen-design・usecase（.drawio 2つも）・screen-02/03/common。

## 計画との差分
- 得点の開示を2拍に残した。レビューの Medium で、1拍だとシュート中に全員がキックオフへ歩き出し、ボールがゴールからセンターへ瞬間移動することがわかった。シャビの判断で案A。
- オフサイドの変更で、前のラインに頼っていた既存の場面のテスト（match_rules 2件・スルーパス・カウンターのメニュー）を、オンサイドになる場面に直した。

## 学んだこと
- **「拍を減らす」は、拍を前提にしていた別の処理（ボールの道筋の書き換え）を静かに殺す。** テストは2拍を直接組んで緑のまま、本番の経路だけ変わっていた。呼び出し元から通り道を読むこと。
- **await するテストが落ちると、後ろのテストが報告されない。** 変異 M13 が見えなかった。件数が減ったら -i で前のテストを外して確かめる。
- **変異はバッチにすると隠れることがある**（M3・M8）。疑わしいときは単独で回す。
- **Bash 経由の置き換えで `\` がまた消えた**（行継続）。GDScript の差し替えは Edit で。

## コミット前レビュー（review-pre-commit）の結果
- 2回で収束。第1回: Critical 0件・High 0件・Medium 1件・Low 3件。第2回: Critical 0件・High 0件・Medium 0件・Low 2件。
- Critical / High は無し。Medium は案Aで直し、Low は直すか意図を記録した。
- 全文は [review-report.md](./review-report.md)。

## 積み残し
- 試合の最後のターンが得点でキックオフへ置き直されない場合の、2拍目の見え方（前からある挙動）。
- 1拍で決まったら、使われ方が得点だけになった `board_settle_sec`・`board_beat_gap_sec` の扱いを見直す。
