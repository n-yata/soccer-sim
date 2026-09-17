# コミット前レビューレポート

## 第1回（2026-09-12）

- 対象: worktree `soccer-sim-worktrees/learning-reinforcement`（ブランチ `feature/learning-reinforcement`）の未コミット差分全件（FR-11/FR-12/FR-13の実装・テスト・ドキュメント一式）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 6件

## コミット前レビュー結果

対象: worktree `soccer-sim-worktrees/learning-reinforcement`（ブランチ `feature/learning-reinforcement`）の未コミット差分全件 — 変更17ファイル + 新規19ファイル（FR-11 用語インライン注釈 / FR-12 クイズ / FR-13 学習進捗）。`git diff HEAD` と新規ファイル全文、テスト・型・lint の実行結果を確認した。

検証実行（読み取り専用、ファイル変更なし）:
- `npx vitest run` → **18 files / 218 tests all pass**
- `npx vue-tsc --noEmit` → エラーなし
- `npx eslint .` → 指摘なし

### Critical（即時対応必須）

なし。

### High（優先対応）

なし。

### Medium（対応推奨）

なし。

### Low / 改善提案

1. **[バグ] `sortByLengthDesc` のキャッシュが配列の破壊的変更に追従しない** — `src/data/termAnnotation.ts:7-15`
   `WeakMap<readonly SoccerTerm[], SoccerTerm[]>` を配列の**参照**でキャッシュしているため、`soccerTerms` に `push`/`splice` で用語を追加した場合（同一参照のまま中身が変わる）、古い並び替え結果が返り続け、新しい用語が永久に注釈されない。現状 `soccerTerms` は初期化後に変更されないので実害はないが、「静かに誤る」種類の欠陥。

2. **[性能] 進捗判定が配列の線形探索** — `src/data/learningProgress.ts:93`, `src/pages/MatrixPage.vue`（`viewedCount` / `isViewed`）
   `isPairViewed` は `viewedPairs.includes` なので、N×N のセル描画と `viewedCount` の二重ループで O(N²·P)（P=記録件数）。現状 N=6・P≤15 で無害だが、フォーメーション追加だけで拡張する設計（NFR-03）なので N が二桁になると再描画ごとに効いてくる。

3. **[性能] `annotateText` は 1 文字ごとに全用語を線形走査** — `src/data/termAnnotation.ts:38-45`
   O(文字数 × 用語数)。現状（18語・数十文字・比較画面で十数インスタンス）は無視できる水準で、`computed` によるメモ化も効いているため対応不要。

4. **[運用] `MatrixPage` の進捗はマウント時 1 回しか読まない** — `src/pages/MatrixPage.vue`
   通常導線（マトリクス→比較→戻る）は再マウントされるため正しく更新される。ただし bfcache 復帰や、マトリクスを開いたまま別タブで比較した場合は「確認済み」が反映されない。

5. **[運用] `localStorage` スキーマの移行方針が未記載**
   キーに `v1` が入っているのは良い判断（`formation-lab.learning-progress.v1`）。一方で v2 へ上げた際の旧キー削除方針がドキュメントに無い。

6. **[品質] クイズの優劣判定設問は正解分布が偏っている（データ起因）**
   `matchups.ts` の `overallEdge` は現在 `"B"`×3 / `"even"`×3 のみで `"A"` が存在しない。学習体験としては「A が優位」の設問が一切出ない（今回の差分の欠陥ではなく、既存データの偏り）。

### 問題なし（確認済み）

**観点1: セキュリティ**
- ハードコーディング: 新規・変更ファイルに API キー・トークン・URL・クラウドアカウント情報の埋め込みなし。ドキュメント側にも実 URL・鍵の記載なし。
- 認証・認可: バックエンド無しのフロント単体アプリで、保護リソース・エンドポイントの追加なし。`localStorage` はオリジン内の自分のデータのみ。該当なし。
- インジェクション/XSS: `v-html`・`innerHTML`・`eval` の使用ゼロ。`TextSegment` を**文字列連結ではなく構造体**で返し、描画は `v-for` + `{{ }}` の補間に閉じている設計で、用語データにHTMLが混入しても実行されない。ルートパラメータは`getFormationById`/`getMatchup`の照合を通し、解決できない場合は記録も描画もしない。
- 情報漏洩: `localStorage` に入るのは`"3-5-2__4-4-2"`形式のフォーメーションID対のみで、個人情報・秘匿値なし。読み出し時にJSON破損・型不一致・重複を全て弾いており（`parseProgress`）、テスト済み。

**観点2: バグ・正しさ**
- 境界値: 用語0件/空文字/用語が空文字（無限ループ回避）/フォーメーション1件（誤答が作れず出題しない）/マッチアップ0件/`limit <= 0`（負数slice への化けを防止）— いずれも実装とテストの双方で処理済み。
- 例外の握り潰し: `localStorage`周りの`try/catch`は「画面を壊さない」ための意図的な握りで、根拠がコメントに残っている。
- 状態のリセット: `restart()`が`questions`/`currentIndex`/`answers`をまとめて作り直し、回答を index ではなく設問idで持つため再挑戦で前回回答が混ざらない。
- 処理順序: `TermAnnotatedText`のdocumentリスナはopen/close遷移時のみ着脱し、`onBeforeUnmount`でも除去。`props.text`変更時に必ず閉じるため、A/B入替で`openIndex`が別用語を指す不整合も防げている。
- テストの空振り: 恒真アサーションなし。クイズ画面のテストは問題数を画面表示から読み取っており、`ComparisonPage.test.ts`は`reactive`なrouteスタブとwrapperの確実なunmountでwatcherの残留汚染を防いでいる。本番コードへのテスト用分岐は無し。

**観点3: 性能**
- ループ内の重いI/Oなし。`localStorage`アクセスは画面マウント時と記録時のみ。
- `annotateText`は`computed`でメモ化され、入力は静的データ由来で上限がある。

**観点4: 運用**
- 後方互換: `FormationMiniPitch`の`label`は任意propで、未指定時は従来どおり`aria-hidden="true"`のまま（既存の`FormationCard`の挙動は不変）。`MatrixPage`の既存セル遷移・色分けロジックと`ComparisonPage`の既存表示は維持され、既存テストも全て緑。
- 切り戻し: 追加ルート`/quiz`と新規モジュールは独立しており、revertで戻せる。
- ドキュメント: 要件定義（FR-11/12/13・UC-04/05）、機能概要、リポジトリ構造、コンポーネント設計、画面設計、画面詳細設計（screen-04/05）、単体テスト仕様（test-screen-04/05）まで一貫して更新されており、実装との対応が取れている。

### 未検証

- **ブラウザ実機での表示確認**（ポップオーバーの位置・行末折り返し、`.matrix-page__cell`を`display:flex`に変えたことによるセルの見た目）。Chrome拡張機能が本セッションで接続できず、開発サーバ起動によるビジュアル確認は未実施。CSSの妥当性は静的読解のみ。
- **実機のプライベートモード/ストレージ無効環境での挙動**。jsdom上のモックでの例外系テストは確認済みだが、実ブラウザでの再現は未実施。

### 総合評価

**Critical: なし / High: なし。コミットしてよい。**

テスト・型チェック・lintがすべて通っており、セキュリティ必須4項目（ハードコーディング・認証認可・インジェクション・情報漏洩）に該当する指摘はない。特に「`TextSegment`を構造体で返して`v-html`を使わない」「`localStorage`を信用せず読み出し時に全面検証する」「`window.confirm`を避けたインライン2段階確認」は、いずれも根拠がコメントに残った良い判断。Low 6件はいずれも申し送りで足りるが、うち「静かに誤る」性質を持つ1・2は低コストで対応可能なため修正する。

### 対応

- **1（`sortByLengthDesc`のキャッシュ追従漏れ）**: キャッシュキーに用語配列の件数（`size`）を含め、件数が変わればキャッシュを作り直す方式に変更した。
- **2（進捗判定の線形探索）**: `MatrixPage.vue`で`progress.value.viewedPairs`を`Set`化した`computed`を追加し、`isViewed`/`viewedCount`の判定をO(1)に変更した。
- 3・4・5・6は実害が小さいため申し送りとし、今回は対応しない。

## レビュー完了（2026-09-12）

- 最終ラウンド: 第1回
- 新たなCritical / High: なし（初回から無し）
- 積み残し（Low を申し送る場合）:
  - `annotateText`の線形走査（Low。用語数が大幅に増えた場合の性能。現状無視できる水準）
  - `MatrixPage`の進捗がマウント時1回のみの読み込み（Low。bfcache復帰・別タブ操作時の反映漏れ）
  - `localStorage`スキーマのバージョン移行方針が未記載（Low。運用ドキュメントへの追記）
  - クイズの優劣判定設問がデータ起因で`overallEdge: "A"`のケースを出題しない（Low。既存データの偏りであり今回の実装の欠陥ではない）
