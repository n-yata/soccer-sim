# コミット前レビューレポート

## 第1回（2026-10-29）
- 対象: 作業ツリーの未コミットの変更すべて（チュートリアル FR-12・FR-23。`.steering/20261029-tutorial/` を含む）
- レビュー役: サブエージェント（opus。セキュリティ観点を含むため）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 6件

## コミット前レビュー結果
対象: 作業ツリーにある未コミットのチュートリアル（FR-12・FR-23）の変更すべて。追跡済み 24 ファイルの差分と、新規のコード・静的データ・テスト・.steering/20261029-tutorial/。読み取りだけで確認した（ファイルの変更なし、Godot は起動していない）。

**Critical / High は無い。**

### Critical（即時対応必須）
指摘なし

### High（優先対応）
指摘なし

### Medium（対応推奨）
指摘なし

### Low / 改善提案
1. **[バグ] `TutorialScreen.enter` を2回呼ぶと、パネルが最初のコントローラーにつながったままになる**（`game/ui/screens/s08_tutorial/tutorial_screen.gd`）
   - 2回目の `enter` は新しいコントローラーを作る。しかし `MatchBoardPanel.bind` は2回目以降は何もしない。その結果、画面は新しい方で `start_tutorial_step` を呼び、パネルは古い方の `snapshot()` を描く。段階を進めると盤面が黙って食い違う。
   - シグナルの二重 `connect` は Godot がエラーを出して弾く。
   - 今は実害が無い。ScreenSwitcher は画面を毎回作り直し、`enter` は1回だけ。S-03 も同じ書き方。守るなら `if _controller != null: return` を先頭に置く。
2. **[運用] 段階が空のとき（静的データの誤り）でも「完了」で完了フラグが付く**
   - 静的データに誤りがあるとカタログ全体が空になり、陣形も0件になる。アプリ全体が使えないので影響は小さいが、直したあとにも「完了済み」が残る。`_steps.is_empty()` のときは `mark_tutorial_completed` を呼ばない方が安全。
3. **[運用] tutorial.json か simplifications.json に誤りが1件あると、陣形も含めて空のカタログになる**（`content_repository.gd`）
   - CPU 対戦まで使えなくなる。「一部だけ正しいデータで動き続けない」という設計どおりで、ファイルの先頭コメントとも合っている。防いでいるのは `tests/content/tutorial_content_test.gd` だけなので、同梱データを変えるときは必ずこのテストを回す前提になる。
4. **[正しさ] 選べる手が試合の規則で選べるかは、読み込み時に確かめていない**（形と範囲だけ）
   - 外れていると、開発版では assert で止まり、書き出し版では先頭の手に置き換わり、絞り込みが空なら進めなくなる。コンテンツのテストが網羅する前提なので、それが守られている限り問題ない。
5. **[保守] パネルの設定が `unbind` で戻らない**（`match_board_panel.gd`）
   - `_show_next`・`_options_filter`・`_is_interactive` は初期値に戻らない。パネルは画面ごとに作り直すので今は無害。使い回すようになったら戻す処理が要る。
6. **[性能・決定性] `App._rng` を本番とチュートリアルで共用している**
   - ScriptedOpponent は乱数を使わないので実害は無い。

### 問題なし
- **セキュリティ① ハードコーディング**: URL・エンドポイント、キー・トークン・パスワード、ARN・12桁 ID を grep した。対象は新規のコード、`game/content/*.json`、`.steering/20261029-tutorial/`、docs の差分。該当なし。定数は UI の寸法、データの上限値、正規表現だけ。
- **セキュリティ② 認証・認可**: オフラインの単体ゲームで、該当しない。
- **セキュリティ③ インジェクション**: JSON は型・正規表現・長さ・件数・列挙値の範囲で検証している。誤りがあれば空のカタログになる。表示は `Label`（BBCode を解釈しない）だけ。
- **セキュリティ④ 情報漏洩**: ログにはファイル名と行番号しか出ない。
- **OWASP A08（データ完全性）**: 中断データの書式は変わっていない。`ACTION_ENUMS` を TurnChoice へ移したが中身は同じで、`SuspendedMatchEncoder.ACTION_ENUMS` は別名として残っている。
- **本番の試合からの切り離し**: `new_tutorial_controller` は `store` と `user_data` に null を渡す。SuspendKeeper の保存・削除は `_store == null` のとき何もしない。MatchFinalizer は記録しない。画面の要求は何もしない関数に渡る。App の `match_controller` には触れていない。ScriptedOpponent は台本と陣形を写して返す。`create_scene` は陣形と `ball_area` を写す。カタログの段階を共有していても書き換えられることは無い。
- **MatchBoardPanel の S-03 への影響**: 既定値（`show_next=true`、絞り込みなし、操作できる）では従来の動きと同じ。差は「`start_turn` が主ボタンを表示に戻す」「空の SideTopSlot・SideBottomSlot が増えた」の2つで、どちらも S-03 では無害。`show_next=false` のときは SHOW_RESULT に入ってから `turn_ready_to_leave` を出し、主ボタンを隠すので LEAVING には入らない。
- **TutorialScreen**: `exit` で3本のシグナルを確かめてから切り、`unbind` している。確認ダイアログは CONNECT_ONE_SHOT。段階を進めると、吹き出し・次へ・タグ・帯・単純化の一覧が初めからになる。最後の段階より先へ進まない。
- **タイトルの reparent**: 親が同じなら reparent しない。`move_child` の位置の計算は正しい。再開カードを先に決めてから KICK OFF の高さを決める。
- **テストの user://**: 新しいテストはどれも一時ディレクトリへ差し替えている。content_repository_test は一時ディレクトリへ本物の新しいファイルを写すように直してある。
- **後方互換**: `ContentCatalog._init` の引数が増えたが既定値があり、既存の呼び出しは壊れない。
- **性能**: 起動時に小さな JSON を2つ読むだけ。

### 未検証
- テストと変異の実行（依頼元の結果に任せた）。
- 同梱の tutorial.json の手が実際の規則で選べるか（`tests/content/tutorial_content_test.gd` に任せた）。
- Godot 4.7 の `Node.reparent` が owner を保つかの実機での確認。
- タイトルのカードの見た目。
- docs と .steering の文面がほかの仕様と食い違っていないか（機密情報が無いことだけを確かめた）。

### 総合評価
Critical / High は無いので、コミットに進んでよい。指摘は Low の6件で、実際に効くのは2件（1: `enter` の2回呼びを防ぐ、2: 段階が空のときは完了フラグを付けない）。

### 対応
- **Low 1（直した）**: `TutorialScreen.enter` の先頭で、コントローラーを持っていれば何もしない。テスト `test_a_second_enter_keeps_the_current_step` を足し、守りを外す変異で落ちることを確かめた
- **Low 2（直した）**: 段階が無いときは「完了」でも完了フラグを付けない。テスト `test_without_steps_complete_does_not_mark_the_tutorial_done` を足し、変異で確かめた
- **Low 3（直さない）**: 静的データの誤りでカタログ全体を空にするのは設計どおり（一部だけ正しいデータで動き続けない）。同梱データを変えたら `tests/content/tutorial_content_test.gd` を回す前提は、component-design.md §4.1 の注記に書いた
- **Low 4（直さない）**: 段階の手が規則で選べるかは、同梱データの検証テストで全段階・全手・全運ぶ先を確かめている（読み込みでは確かめない設計。component-design.md §4.1）
- **Low 5（直さない）**: パネルは画面ごとに作り直す。使い回すようになったら、`unbind` で口の設定を戻す
- **Low 6（直さない）**: ScriptedOpponent は乱数を使わない
- あわせて実装検証（review-implementation。sonnet）の指摘に対応した: S-08 の `CoachText`（`Label` にした理由と強調の見送り）を仕様書に書いた、単純化カタログと `simplifications.json` の書き写しを両方に注記した、`tutorial_screen.gd` が 300 行を超える理由をファイルの先頭に書いた、`title_text()` を `ScreenHeader.title_text()` 経由にした、`SuspendedMatchEncoder.ACTION_ENUMS` の別名を消した、`TurnChoice.family_for` と `MoveOptions.restricted_to` の境界のテストを足した
- 第1回で Critical / High は無く、直したのは Low だけなので、規則どおり再レビューは行わない（テストと変異で確かめた）

## レビュー完了（2026-10-30）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し: Low 3〜6（上のとおり。いずれも悪用できる欠陥ではない）
