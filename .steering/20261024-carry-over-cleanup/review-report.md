# レビューレポート

## コミット前レビュー（review-pre-commit。2026-10-24）

- 対象: 変更 4 ファイル・未追跡 5 ファイル（コード・テスト・仕様書・steering）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 2件（どちらも対応不要）
- ハードコード検出: URL・エンドポイント、シークレット、AWS の情報、ドキュメント内の実 URL・キーは、いずれも 0件
- プライバシー: ローカルの絶対パス・ユーザー名・メールアドレス・claude.ai のリンクは 0件
- コミットしないファイル（export_presets.cfg・署名鍵・.env）は、変更対象に無く、.gitignore の対象
- 制御文字・NUL・BOM・行末の空白: 0件。`git diff --check` も 0件

| # | 重要度 | 指摘 | 対応 |
|---|---|---|---|
| L1 | Low | 要求書のスコープ外に、保存の検査の積み残しが書いてある | 対応不要（欠陥の所在や再現手順は書いていない）。保存の作業で拾う |
| L2 | Low | 一様な手で選べる手が無いと null を返す | 対応不要（resolve_turn が拒否し、テストが拒否を確かめて落ちる） |

## 実装レビュー（review-implementation。2026-10-24）

- 規約（coding-gdscript・coding-common・testing）の全文と照合した。
- 移す前後の関数を、先頭の `_` を外す改名だけをかけて突き合わせ、本体が一致すること、呼び出し箇所 6 か所がすべて置き換わったことを確かめた。
- 結果: Critical 0件 / High 0件 / Medium 1件 / Low 5件 / Info 1件

| # | 重要度 | 指摘 | 対応 |
|---|---|---|---|
| 1 | Medium | `component-design.md` §6 の名前の一覧に `MatchPositions` が無い | 足した（Godot の組み込みクラスと重ならない） |
| 2 | Low | 公開にした `release_fixes` に doc コメントが無い | 足した |
| 3 | Low | クラスの doc の「next（判定前の状態の写し）を書き換える」が、create_match の経路では不正確 | 直した |
| 4 | Low | `component-design.md` の写し戻しの主体が `MatchRules` のまま | 「実体は `MatchPositions`」を書き足した |
| 5 | Low | 「11種類すべて」の確認の余裕が見えない | 種類ごとの回数を数え、失敗メッセージに内訳を出すようにした。実測で最小 13 回（LONG_BEHIND） |
| 6 | Low | `picked` が型なしの Dictionary | `Dictionary[String, int]` にした |
| 7 | Info | review-report.md・retrospective.md が無い | 作った |
| 補足 | — | `component-design.md` §6 の一覧に `MovePreview` も無い（前の作業からの抜け） | 今回の範囲外。積み残しとして伝える |

## レビュー完了

- 新たな Critical / High は無い。指摘を直したあと、全件のテスト 561件が成功した（2026-10-24）。
