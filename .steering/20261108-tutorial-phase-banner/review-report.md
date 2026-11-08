# コミット前レビューレポート

## 第1回（2026-11-08）
- 対象: ステージ済みの差分（`git diff --cached -M`、15ファイル。phase_banner.gd の ui/common への移動を含む）。別セッションの未ステージの変更・_tmp ファイルは対象外
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 3件

## コミット前レビュー結果

対象: `git diff --cached -M` のステージ済み差分のみ（14エントリ／15ファイル）。
- コード: `game/ui/common/phase_banner.gd`（s03_match から移動）と `.uid`、`game/ui/screens/s03_match/match_screen.gd`、`game/ui/screens/s08_tutorial/tutorial_screen.gd`
- テスト: `game/tests/ui/phase_banner_test.gd`、`game/tests/ui/tutorial_screen_test.gd`
- ドキュメント: docs/specs 5件、`.steering/20261108-tutorial-phase-banner/` 3件

未ステージの差分と `_tmp` ファイルは見ていない。ファイルは一切書き換えていない。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
- [バグ・正しさ／保守] テストの doc コメントの付き先がずれている（`tutorial_screen_test.gd`）
  - 新しいテスト `test_the_phase_banner_shows_when_the_phase_changes_between_steps` を、既存のコメント「## 最後まで進むと単純化の一覧が出て、「完了」で完了フラグを保存してタイトルへ」と、その対象の関数 `test_the_last_step_shows_the_scope_and_complete_saves_the_flag` の間に差し込んでいる。
  - その結果、既存のコメントが新しいテストの説明の1行目になり、`test_the_last_step_...` は説明を失っている。
  - → 既存の1行を `test_the_last_step_...` の直前へ戻す。新しいテストのコメントは「## 局面の帯（2026-11-07）…」から始める。
- [バグ・正しさ（テストの頑健性）] 新しいテストの `while true:` は、段階が進まないと止まらない
  - 止まるのは「盤面の無い段階」に来たときだけ。
  - 次の2つの場合は `_on_next_pressed` が何もせず、`step_index()` が変わらないまま回り続ける。全体実行は timeout 180 秒で落ちるが、どこで固まったかが分からない。
    - 将来、同梱データの最後の段階に盤面が付いた場合
    - `_play_current_step` が判定理由まで進められずに `_can_next` が偽のままの場合
  - 既存の `test_the_last_step_...` の while も同じ形だが、今回足した側は止まる条件がデータに依存するぶん踏みやすい。
  - → 回数に上限を付け、進んだことを確かめる。例:
    ```gdscript
    for _i: int in _steps().size():
        var before: int = screen.step_index()
        ...（本体はそのまま。盤面の無い段階で break）
        screen.next_button().pressed.emit()
        assert_int(screen.step_index()).override_failure_message("段階が進まない").is_equal(before + 1)
    ```
- [運用（ドキュメント）] `.steering/20261107-phase-banner/design.md` に古い置き場（`s03_match/phase_banner.gd`）が残っている。
  - 過去の作業記録なので直さなくてよい。仕様書（docs/specs）側は全部 `common/` に直っていることを確かめた。

### 問題なし
- **セキュリティ①ハードコーディング**
  - 差分に URL、エンドポイント、API キー、トークン、パスワード、クラウドのアカウント ID、ARN は無い。
  - ドキュメント（docs/specs、.steering）にも、実在の URL や機密は書かれていない。
  - 追加された定数・文字列は、UI の文言とノード名だけ。
- **セキュリティ②〜④**
  - 認証・認可：オフラインの単体ゲームで、保護リソースは無い。差分にも該当なし。
  - インジェクション：外部入力や保存ファイルの読み込みは無い。帯の文言は `MatchTexts` の固定文言を Label に出すだけ。
  - 情報漏洩：ログ出力の追加は無い。
  - OWASP A01〜A10：差分に該当する攻撃面は無い。依存の追加も無い。
- **バグ・正しさ**
  - `PhaseBanner.follow`：「最初は出さない／変わったら出す／変わらなければ消す」の3通りを、単体テストで出る・出ないの両方向から確かめている。`forget` で最初の状態に戻ることも確かめている。
  - 試合画面の動きは変わっていない。
    - `enter` の `_last_phase = -1` が `forget()` になった。帯も消すようになったが、`_init` で作った帯は表示されていないので副作用は無い。
    - `_on_turn_started` の `_show_phase_change` が `follow` になった。
    - `_on_reveal_started` の `dismiss` はそのまま残っている。
    - 試合では開示のたびに帯が消えるので、`follow` の「変わらなければ消す」が実際に効くことは無い。開示を経ずに `turn_started` が来る経路があったとしても、古い帯が残るより消えるほうが正しい。
  - チュートリアルの扱いは次のとおり。
    - `enter` で `forget`。2回目の `enter` は早期 return するので、前の局面が意図せず消えることは無い。
    - `_on_turn_started` で `follow`、`_on_reveal_started` と `_show_scope` で `dismiss`。
    - 帯は `_build` 内で `_dialog` より前に add_child しているので、確認のダイアログが上になる。
    - `mouse_filter = IGNORE` なので、帯の下の手の選択や「次へ」を止めない。
  - `_phase_banner` は `_init` から呼ばれる `_build` で作られ、`enter` より前にある。null 参照にはならない。
  - ファイルの移動は `.uid` ごと similarity 100% の rename になっている。参照は `class_name` だけで、ステージ済みのツリーにパス直書きの参照（.tscn や preload）は残っていない（`git grep --cached` で確かめた）。
  - テストは恒真テストではない。
    - チュートリアルのテストは、期待値を段階定義（`step.turn_kind` と `possession`）から求めた局面の変化で決めており、実装をコピーしていない。
    - 変化が4回以上あることも確かめているので、空振りしない。
    - tasklist には、開示で消す処理を外すと4件落ちたこと（変異の確認）が記録されている。
- **性能**：ターンや段階ごとに Tween を1つ作るだけ。ループ内の I/O や件数で伸びる処理は無い。
- **運用**
  - 新しい設定値やログは無い。revert で戻せる（ファイル移動を含め、1コミットに収まる）。
  - 仕様書（screen-03-match、screen-08-tutorial、screen-common、screen-design、component-design）が、新しい `follow` / `forget` と置き場に合わせて更新されている。

### 未検証
- テストを実際には流していない。読み取りのみの指示のため。「1274 件成功」は依頼元の申告による。
- `tutorial_screen_test.gd` の `_play_current_step`（既存のヘルパー）の中身は読んでいない。新しいテストが判定理由まで進むかどうかは、この関数の既存の動きを前提にしている。
- 実機での見た目（帯が説明の吹き出しに 1.2 秒かぶる点）は確かめていない。tasklist のスクリーンショットの記録による。

### 総合評価
**Critical / High の指摘なし。** コミットしてよい。Low の2件（コメントの付き先のずれ、while ループに上限が無いこと）は、コミット前に直すのが手軽。直さない場合は申し送りとする。

### 対応
- Low 1（コメントの付き先）: 直した。既存の1行を `test_the_last_step_...` の直前へ戻した。
- Low 2（while に上限が無い）: 直した。段階の数だけ回し、毎回1つ進んだことと、盤面の無い最後の段階に着いたことを確かめる形にした。スイートを流して 8 件成功。
- Low 3（過去の作業記録の古い置き場）: 直さない。過去の作業の記録で、仕様書は直っている。
- 未検証のテスト実行: レビューの前にインデックスの中身で全体を流した（1274 件成功・152 秒）。Low の修正の後にも流し直した（tasklist）。

## レビュー完了（2026-11-08）
- 最終ラウンド: 第1回（Critical / High が無いので再レビューはしない。Low 2件は直した）
- 新たな Critical / High: なし
- 積み残し: Low 3（過去の作業記録の古い置き場。直さない）
