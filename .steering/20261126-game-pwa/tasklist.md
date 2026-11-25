# タスクリスト

## フェーズ1: 取り込みと書き出しの成立

- [x] soccer-game の履歴に秘匿情報・署名鍵・個人のパスが無いことを確認
- [x] `git subtree add --prefix=soccer-game` で履歴ごと取り込む
- [x] Web プリセットを `export_presets.cfg.example` に追加
- [x] 手元で Web 書き出しができ、ブラウザで起動することを確認（日本語が豆腐になることを確認）

## フェーズ2: 日本語フォント

- [x] サブセット生成・検査スクリプト `soccer-game/tools/subset_noto_sans_jp.py`
- [x] サブセット（Regular・Bold）と OFL.txt を置く
- [x] テーマの既定フォントと Barlow の日本語フォールバック
- [x] ブラウザでタイトル→試合準備→試合画面まで日本語で表示されることを確認
- [x] ゲームのテストが通ることを確認（`soccer-game/tools/run-tests.sh`。1308件成功・154秒。ラボのテストと並行で流すと3分を超えて時間切れになる）

## フェーズ3: 書き出しの自動化と公開

- [x] `soccer-game/tools/export-web.sh` を作る
- [x] `npm run game:export`（`public/game/` へ書き出し）と `.gitignore`
- [x] ラボの lint・整形の対象から `soccer-game/`・`public/game/` を外す
- [x] `deploy-pages.yml` に Godot の取得（SHA512 検証・キャッシュ）と書き出しを追加
- [x] `npm run build` 後の `dist/` に近い形（サブパス配信）でゲームが起動することを確認（ラボとゲームが同じ dist から動き、SW はゲームのスコープだけ。2回目の訪問以降はオフラインでも起動。`/game/` で開くとオフラインでは起動しないため、案内は `index.html` まで含める）

## フェーズ4: 品質チェックと修正

- [x] `npm test`（36ファイル・560件成功）
- [x] `npm run lint`
- [x] `npm run typecheck`
- [x] `npm run build`
- [x] `python soccer-game/tools/subset_noto_sans_jp.py --check`
- [x] アプリ内のライセンス表示に Noto Sans JP を追加（OFL。テストを先に足して Red→Green）
- [x] ゲームの全テストを再実行（1308件成功）
- [x] ワークフローの YAML 構文を確認

## フェーズ5: ドキュメント更新

- [x] ラボ: `architecture-overview.md`（公開先に `/game/`）・`repository-structure.md`（構造・CI・手元の書き出し）
- [x] ゲーム: `architecture-overview.md`（ブラウザ版の配布・フォントの配置）・`repository-structure.md`（tools・fonts）・`LICENSES.md`（Noto Sans JP）
- [x] コミット前レビュー（`review-pre-commit`）→ `review-report.md`（2回。High 1件を修正して収束）
- [x] 実装後の振り返りを記録（`retrospective.md` → モード3）
