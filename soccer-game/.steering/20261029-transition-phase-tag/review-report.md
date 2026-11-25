# コミット前レビューレポート

## 第1回（2026-10-29）
- 対象: 作業ツリーの未コミットの変更（`game/ui/common/match_texts.gd`・`game/ui/screens/s03_match/match_screen.gd`・`game/tests/ui/match_texts_test.gd`・`game/tests/ui/match_screens_test.gd`・`docs/specs/3_detail-design/screen/screen-03-match.md`）
- レビュー役: サブエージェント（opus）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 2件

## コミット前レビュー結果
対象: 作業ツリーの未コミット差分5ファイル。`MatchTexts.phase_tag()` を2行にした変更、PhaseTag の中央ぞろえ、テスト2本、screen-03-match.md の注記。

### Critical
指摘なし

### High
指摘なし

### Medium
指摘なし

### Low / 改善提案
1. **[運用] screen-common.md に1行のタグを前提にした記述が残っている。** `docs/specs/3_detail-design/screen/screen-common.md:35` は、ヘッダーの幅を確かめる最長の文言として `NEG.TRANSITION ネガティブトランジション` を1行の形で挙げている。規則そのものは今も正しいが、今の表示は2行。「（2行で表示。screen-03-match.md）」のように一言足すと、次に読む人が迷わない。
   - `docs/specs/2_basic-design/screen-design.md:193` は「英字に日本語の局面名を添える」という書き方なので、2行でも矛盾しない。
   - `.steering/20261019-match-screen/design.md:40` は過去の作業記録なので直さなくてよい。
2. **[品質] 新しいテストの高さのアサーションに失敗時の文言がない。** 幅の側は `override_failure_message(phase_tag.text)` で、どのタグで失敗したかがわかる。高さの側にも同じ文言を付けると、どのタグで超えたかがすぐわかる。動きには影響しない。

### 問題なし
- **セキュリティ:** 差分は表示文字列・UI の配置・テスト・仕様書の注記だけ。URL・シークレット・アカウント情報のハードコードはない。外部入力の経路も、認証・認可も、ログや情報漏洩の要素もない。
- **ほかの呼び出し元:** `MatchTexts.phase_tag` を本番コードで呼んでいるのは `match_screen.gd` だけ。`phase_text()` を使っているのはテストだけで、改行が入っても壊れない。S-08（チュートリアル）はまだ実装がなく、仕様（「S-03 と同じ表示」）が2行になっても矛盾しない。`TagLabel` を使うほかの画面は `phase_tag` を使っておらず、`horizontal_alignment` の変更は PhaseTag だけ。
- **レイアウト:** Label は自動折り返しをしないので、最小の幅は長いほうの行の幅になる。高さは TopBar の `custom_minimum_size.y = 96` との最大値になり、テストの `y <= 96` は恒真ではない。
- **テストの妥当性:** 「≡」ボタンを含めた上部バーの幅を、4つのタグすべてで測っている。上限は 1280 − 48（左右の余白）。トランジションの局面から測り始めることも確かめている。
- **性能:** 文字列の定数を変えただけ。
- **後方互換:** `phase_tag` の文字列は保存データに使われていない。

### 未検証
- Godot とテストは実行していない（依頼元の「全テスト成功」「修正前の形で落ちる」をそのまま受け取った）。
- 実機の日本語フォントでの実寸、21:9 など横に長い端末での見た目、2行のタグの縦の詰まり具合は目で確かめていない。

### 総合評価
Critical / High はなし。コミットしてよい。

### 対応
- Low 1（直した）: screen-common.md の該当箇所に「英字と日本語の2行で表示する」と足した
- Low 2（直した）: 高さのアサーションにも失敗時の文言（タグの文）を付けた

## レビュー完了（2026-10-29）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し: なし
