# コミット前レビューレポート

## 第1回（2026-09-12）

- 対象: `learning-experience` の未コミット差分全体（FR-07/08/09 の実装・`ComparisonControls.vue` への切り出し・関連ドキュメント更新）
- 結果: Critical 0件 / High 0件 / Medium 4件 / Low 6件

## コミット前レビュー結果

対象: `C:\develop\workspace-claude\soccer-sim-worktrees\learning-experience` の未コミット差分全体（FR-07/08/09 の実装 9 ファイル + 変更 6 ファイル + 仕様書 12 ファイル）。`git diff` で確認したところ、`src/App.vue` / `MatchupPitchDiagram.vue`・`.test.ts` / `formations.ts`・`.test.ts` / `matchups.ts`・`.test.ts` / `main.ts` は内容差分ゼロ（CRLF/LF 正規化のみ）で、`git diff --stat` にも現れませんでした。検証として `npm test`（82 passed / 11 files）、`npm run typecheck`、`npm run lint` をすべて green で確認済み。

### Critical（即時対応必須）

なし。

### High（優先対応）

なし。セキュリティ必須4項目・OWASP該当項目のいずれにも指摘はありません（詳細は「問題なし」参照）。

### Medium（対応推奨）

- **[バグ/テスト] `FormationMiniPitch` の `aria-label` が唯一の利用箇所で無効化されている**
  `FormationCard.vue` は `<FormationMiniPitch class="formation-card__pitch" :formation="formation" aria-hidden="true" />` と呼び出しており、`aria-hidden` は単一ルートの `<svg>` にフォールスルーします。一方 `FormationMiniPitch.vue` 側のルート `<svg>` は `role="img"` と `:aria-label="`${formation.name}の選手配置図`"` を持っています。`aria-hidden="true"` が勝つため、支援技術には `role`/`aria-label` が一切届きません。`FormationMiniPitch.test.ts` の「aria-labelにフォーメーション名が含まれる」（設計書 No.33）は単体では通りますが、実利用経路の挙動を保証していない空振りテストになっています。
  → どちらかに寄せる。装飾扱いでよいなら `FormationMiniPitch.vue` から `role="img"` と `:aria-label` を落とし、テスト No.33 も設計書ごと削除する。読み上げさせたいなら `FormationCard.vue` の `aria-hidden="true"` を外す（カード自体が `role="button"` + テキストを持つので、後者は冗長読み上げになりやすい。装飾側を推奨）。

- **[バグ/テスト] `ComparisonControls.test.ts` が実ブラウザで到達不能な経路を検証している**
  前提データが 2 件（`4-4-2` / `4-3-3`）しかないため、No.43 は `formationBId="4-3-3"` の状態で `#comparison-select-a` に `"4-3-3"` を `setValue` しています。これは同テスト No.45 が `disabled` であることを検証している当の option です。jsdom は disabled option への `setValue` でも `change` を発火するので緑になりますが、実ブラウザでは起こり得ない操作で、「有効な option を選ぶと emit される」ことを検証できていません。
  → 前提 `formations` に 3 件目（例 `4-2-3-1`）を足し、`await wrapper.find("#comparison-select-a").setValue("4-2-3-1")` のように disabled でない選択肢で emit を検証する。No.44 も同様。

- **[運用] NFR-02 の不変条件に自動テストが無い**
  `soccerTerms.ts` 冒頭コメントと `functional-overview.md` は「説明文は他のサッカー用語を使わずに書く」を不変条件として宣言していますが、`soccerTerms.test.ts` が検証しているのは「term が正本の実文言に登場すること」だけで、説明文側の不変条件は無検査です。実データをスクリプトで全走査したところ現時点で違反はゼロ（＝テストを足せば即 green）なので、今なら安全に回帰テストとして固定できます。

- **[運用] `screen-03-glossary.md` の props/state 表が実装と食い違っている**
  設計書は `GlossaryPage` の内部 state を「`computed`: `categories`, `termsByCategory`」と記載していますが、実装は `groupedTerms` という単一の computed です。他のセクション（`categoryOrder` の固定順・空カテゴリ除外・`<dl>/<dt>/<dd>` 構造）は実装と正確に一致しているだけに、この 1 箇所だけが drift しています。
  → 表を「`computed`: `groupedTerms`（カテゴリと該当用語の配列）」に修正。

### Low / 改善提案

- **[バグ] ルートパスの組み立てに `encodeURIComponent` が無い** — 現行 id は静的値のみで実害はないが、将来 id に `/` や `?` を含む値が入るとルートが静かに壊れる。`router.replace({ name, params })` 形式にすればエンコードは vue-router 側が担保する（申し送り。今回のデータ範囲では発現しないため未対応）。
- **[バグ] `<select>` の片方向バインド** — `onSelectA/B` の早期returnは `v-if` の外側でしか成立せず実質到達不能。意図的である旨のコメントが無いと誤読されうる（申し送り）。
- **[性能/UX] 総合判定に `:key` が無い** — 入れ替え・切替時、ピッチのスライドインは再生されるが判定文のポップインは再生されない（演出の非対称。実害は小さく申し送り）。
- **[運用] SPAフォールバックの申し送り** — `/glossary` 追加により直リンク可能URLが増えた。静的ホスティング時のSPAフォールバック設定は本差分より前からの既存前提（申し送り）。
- **[運用] retrospective.md 未作成** — レビュー後に作成予定（本レポートの後続工程）。
- **[運用] 行末コード正規化のみの6ファイル** — `.gitattributes`によりblobは同一。実害なし。

### 問題なし

- **セキュリティ①ハードコーディング/シークレット**: URL・APIキー・クラウドアカウント情報・認証情報の混入なし。`.gitignore`は適切。
- **セキュリティ②認証・認可**: 該当なし（バックエンド・認証機構を持たない静的SPA）。
- **セキュリティ③インジェクション**: `v-html`皆無。全テキストは`{{ }}`補間。`route.params`は`getFormationById`の許可リスト照合を通らないと描画されない。
- **セキュリティ④情報漏洩**: エラー表示は固定文言のみ。
- **バグ・正しさ**: 空配列時の描画、同一フォーメーション指定時のフォールバック、`getMatchup`のA/B反転、座標変換方向を確認。恒真アサーションなし。
- **性能**: 差分が持ち込んだ計算量増は軽微。N+1・全件取得・ループ内I/O該当なし。
- **運用**: 要件定義書〜単体テスト仕様書まで一貫して追従済み。`glossary.md`と`soccerTerms.ts`の役割分離が明記され二重管理を回避。`replace`採用理由がコード・設計書双方に残る。

### 未検証

- 実ブラウザでの表示確認（レイアウト崩れ、`prefers-reduced-motion`有効時の挙動）。
- 本番デプロイ環境での`/glossary`直アクセス（SPAフォールバック設定）。ホスティング構成がリポジトリ内に存在せず確認不能。

### 総合評価

Critical・Highの指摘はなし。現状のままコミットしても安全。Medium 4件のうち、テストが実挙動を保証できていない2件（aria-label無効化・ComparisonControls.test.tsの空振り）を対応する。

### 対応

- **aria-label無効化**: `FormationMiniPitch.vue`から`role="img"`/`:aria-label`を削除し装飾専用コンポーネントとして明確化。`FormationMiniPitch.test.ts`のaria-label検証テストと、対応する設計書・単体テスト仕様書の記載を削除した。
- **ComparisonControls.test.tsの空振り**: 前提`formations`に3件目（`4-2-3-1`）を追加し、disabledでない選択肢（`4-2-3-1`）への変更でemitを検証する形に修正した。
- **NFR-02の不変条件テスト**: `soccerTerms.test.ts`に「各用語の説明文に他の登録用語が登場しない」検証を追加した。
- **screen-03-glossary.mdのprops/state表**: 実装（`groupedTerms`という単一のcomputed）に合わせて修正した。
- Low/改善提案は実害が小さいため申し送りとし、今回は対応しない。

## レビュー完了（2026-09-12）

- 最終ラウンド: 第1回
- 新たなCritical / High: なし（初回から無し）
- 積み残し（Medium / Low を申し送る場合）:
  - ルートパス組み立てのencodeURIComponent不足（Low。実害なし、`router.replace({name, params})`化で改善余地）
  - select早期returnの到達不能性を示すコメント不足（Low）
  - 総合判定への`:key`不足によるポップイン非再生（Low。演出の非対称のみ）
  - SPAフォールバック設定は本差分のスコープ外（デプロイ手順は未整備。既存の`/compare/:a/:b`にも共通する前提）

---

## 第2回（2026-09-12）— マージコミット `9c16afe` の追いレビュー

- 対象: マージコミット `9c16afe`（`feature/learning-experience` → `main`）が持ち込んだ差分全33ファイル（`git diff bc78a7f 9c16afe`）
- 結果: Critical 0件 / High 0件 / Medium 2件 / Low 4件
- 実施の経緯: 本マージはコンフリクト5ファイルを解消してコミットされたが、**コミット前レビューを経ずにコミットされた**（第1回はマージ前のブランチ差分が対象）。証跡を欠いたままにしないため、コミット後に同一観点で追いレビューを実施した。
- 重点確認: コンフリクト解消により FR-07（相性マトリクス）と FR-08〜10（一覧プレビュー・比較画面回遊性・用語集）の一方が欠落していないか、矛盾した記述・到達不能ルート・重複定義が残っていないか

## コミット前レビュー結果

対象: マージコミット `9c16afe`（`feature/learning-experience` → `main`）が `bc78a7f` に対して持ち込んだ差分 全33ファイル。特にコンフリクト解消5ファイル（`functional-overview.md` / `repository-structure.md` / `requirements-definition.md` / `FormationListPage.vue` / `router/index.ts`）の機能欠落・矛盾・到達不能ルートを重点確認。検証として `npx vitest run`（**12ファイル / 93テスト 全green**）、`vue-tsc --noEmit`（エラーなし）、`eslint src`（指摘なし）を実施。

### Critical（即時対応必須）

なし。

### High（優先対応）

なし。セキュリティ必須4項目・OWASP該当項目に指摘なし。

### コンフリクト解消の検証結果（最重点項目）

**両機能とも欠落なし。矛盾・到達不能ルート・重複定義なし。**

- `src/router/index.ts`: `/matrix`（FR-07）と `/glossary`（FR-08〜10）が**両方存在**し、パス・name とも重複なし。`MatrixPage` / `GlossaryPage` の import も両方残存。到達不能ルートなし。
- `src/pages/FormationListPage.vue`: 「相性表を見る」ボタン（FR-07 導線）と「📖 用語集」リンク（FR-10 導線）が**両方**ヘッダーに配置され、`__header-actions` に再構成されている。既存の `goToMatrix` は保持。旧 `subtitle` の位置移動も HTML 的に整合（重複要素なし）。
- `requirements-definition.md`: FR-07 は新設された「4.1.3 相性俯瞰系」へ移設され**消えていない**。FR-08/09/10 も追加済み。§4.3 画面対応表に相性マトリクス画面（FR-07）・用語集画面（FR-10）が両方記載。
- `functional-overview.md`: 画面一覧・画面遷移図・モジュール構成図のいずれにも `MatrixPage` と `GlossaryPage` の両方が残存。UC は UC-02（相性俯瞰）・UC-03（用語確認）へリナンバリング済み。
- `repository-structure.md`: `MatrixPage.vue`（FR-07）・`GlossaryPage.vue`（FR-10）とも記載あり。
- コンフリクトマーカー（`<<<<<<<` / `=======` / `>>>>>>>`）の残骸は `docs` / `src` / `.steering` に**1件もなし**。

### Medium（対応推奨）

- **[運用] `screen-design.md` の画面数記述がマージ解消で誤りになっている**
  `docs/specs/2_basic-design/screen-design.md:15` が「`FormationListPage` ⇔ `ComparisonPage` ⇔ `GlossaryPage`）が正本。本プロダクトは**3画面のみ**の単純な遷移のため、本節で追加の提出品質図は作らない」となっている。実際のルートは `/`・`/compare/:a/:b`・`/matrix`・`/glossary` の**4画面**で、`MatrixPage` が遷移説明から抜けている。マージ前は「2画面」（`/matrix` 追加時に更新漏れ）、今回のコンフリクト解消で用語集分だけ +1 して「3画面」になっており、誤りが一段深くなった。
  → 修正案: 「`FormationListPage` ⇔ `ComparisonPage` ⇔ `MatrixPage` ⇔ `GlossaryPage`）が正本。本プロダクトは4画面のみ…」に訂正。あわせて `screen-design.md` に「相性マトリクス画面」の節が**存在しない**（`画面3` は用語集）点、`3_detail-design/screen/` と `4_unit-test/` にもマトリクス画面のドキュメントが無い点は FR-07 コミット（`bc78a7f`）由来の既存欠落だが、本マージで画面系ドキュメントを触っているため同時に埋めるのが望ましい。

- **[運用] `component-design.md` の `FormationListPage` 責務が導線を片方しか列挙していない**
  責務に「用語集画面（`/glossary`）への導線を提供する（FR-10）」は追記された一方、実装に存在する `goToMatrix`（相性マトリクス画面への導線、FR-07）が責務にもインターフェースにも載っていない。`component-design.md` には `MatrixPage` の節自体が無い（既存欠落）。コンフリクト解消で FR-10 側だけ追記した結果、**同じヘッダー内の2導線のうち片方だけが設計書に存在する**という非対称が生まれている。
  → `FormationListPage` の責務に `- 相性マトリクス画面（/matrix）への導線を提供する（FR-07）` と `function goToMatrix(): void;` を追記。

### Low / 改善提案

- **[バグ/テスト] リンク検証テストが `wrapper.find("a")`（最初のアンカー）に依存**
  `src/pages/FormationListPage.test.ts` の「用語集画面へのリンクが'/glossary'を指す」、`src/pages/GlossaryPage.test.ts` の「一覧画面へのリンクが'/'を指す」がいずれも先頭 `<a>` を掴んでいる。今回は「相性表を見る」が `<button>` のため偶然一意だが、将来ヘッダーにアンカーを1つ足すとテストが**別要素を検証したまま緑のまま**になる。`ComparisonPage.test.ts` 側は `a.comparison-page__glossary-link` とクラス指定しており、そちらに揃えるのが安全。
- **[バグ] `ComparisonControls` は全組み合わせを選択可能にするが、マッチアップ網羅は暗黙前提**
  フォーメーション4件に対しマッチアップは6件で全ペア網羅済みのため**現時点で欠損ペアは無く、選択操作でエラー画面に落ちることはない**。ただし将来 `formations.ts` にフォーメーションを1件足すと、対応マッチアップを書くまでセレクト操作からエラー画面へ落ち、その画面には `ComparisonControls` が無いため**戻るしかない行き止まり**になる。`matchups.test.ts` に「全ペアが網羅されている」不変条件テストを置くと静かな欠損を防げる。
- **[運用] `requirements-definition.md` §4.2 の FR 見出し順が非連番**（FR-01, FR-02, FR-08, FR-03, FR-04, FR-05, FR-06, FR-09, FR-07, FR-10）。§4.1 のカテゴリ分けと対応しており読解は可能だが、顧客提出時は §4.1 のカテゴリ順どおりに並べ直すと追いやすい。
- 第1回の申し送り Low 4件（`encodeURIComponent` 不足、select 早期returnのコメント不足、総合判定への `:key` 不足、SPAフォールバック未整備）は本マージでも未対応のまま。いずれも実害は小さく、申し送り継続で妥当。

### 問題なし（確認済み項目）

- **セキュリティ① ハードコーディング/シークレット**: 差分全体を `api_key|secret|token|password|bearer|arn:aws|amazonaws|https?://` で走査し**該当ゼロ**。新規 `soccerTerms.ts` は日本語テキスト定数のみ。`VITE_*` の新規追加なし。ドキュメント（`.steering/` 含む）にも実URL・キーの記載なし。
- **セキュリティ② 認証・認可**: 該当なし（バックエンド・認証機構を持たない静的SPA）。保護リソースの追加なし。
- **セキュリティ③ インジェクション**: `src` 配下に `v-html` / `innerHTML` は**皆無**。用語・説明文・フォーメーション名はすべて `{{ }}` 補間（Vue が自動エスケープ）。`route.params` は `getFormationById` / `getMatchup` の静的配列照合（許可リスト方式）を通過しないと描画されず、不一致時はフォールバック画面。SQL・シェル・ファイルアップロードは差分に存在しない。
- **セキュリティ④ 情報漏洩**: エラー表示は固定文言「指定された組み合わせを表示できません」のみ。ログ出力の追加なし。
- **依存関係（A06）**: `package.json` / ロックファイルは本差分に**含まれず**、新規依存の追加なし。
- **バグ・正しさ**: `GlossaryPage` の空配列・空カテゴリ除外（テストあり）、`FormationMiniPitch` の座標変換 `cy = 100 - y`（上下反転方向をテストで検証）、`getMatchup` のA/B反転ロジック（既存・未変更）、`ComparisonControls` の相手側 `disabled` による同一ペア防止、`swap`/`onSelectA`/`onSelectB` の early return を確認。`expect(true).toBe(true)` 型の恒真アサーションなし。`soccerTerms.test.ts` は正本から独立に不変条件を検証しており、期待値の実装コピーになっていない。
- **ブラウザ履歴の整合**: 比較→比較の遷移が `router.replace` に統一され、`history.state.back` が保持されるため `goBack()` / ブラウザバックで一覧へ1回で戻れる（FR-09 の受け入れ基準を満たす）。テストで `replace` が呼ばれ `push` が呼ばれないことを検証済み。
- **性能**: 追加された計算はすべて静的データ（フォーメーション4件 × 11ポジション、用語18件）に対する O(n) の `filter`/`map` で、ループ内 I/O・N+1・全件取得後の絞り込みなし。件数が数千規模になるまで問題化しない。
- **切り戻し**: 追加は新規ファイルとルート1行が中心で、`git revert -m 1 9c16afe` で戻せる。

### 未検証

- **実ブラウザでの表示確認**: レイアウト崩れ、`/glossary` リンクの白文字×緑背景のコントラスト比（`.formation-list-page__glossary-link` は半透明枠線＋白文字で、同ファイル内のコメントが「半透明の白オーバーレイでは AA 未達」と指摘した配色に近い構成）、`prefers-reduced-motion` 有効時の挙動。ヘッドレス実行のみのため目視検証は未実施。
- **本番デプロイ環境での `/glossary` 直アクセス**（SPAフォールバック）。ホスティング構成ファイルがリポジトリ内に存在せず確認不能（既存の `/compare/:a/:b`・`/matrix` にも共通する前提）。
- **`.steering/` 配下のドキュメント本文の内容妥当性**: コンフリクトマーカー・機密情報の有無のみ確認し、記述内容の精査は差分レビューの範囲外とした。

### 総合評価

**Critical 0件 / High 0件。** 懸念されたコンフリクト解消による機能欠落は**発生しておらず**、FR-07（相性マトリクス）と FR-08〜10（一覧プレビュー・比較画面回遊性・用語集）はコード・ルーティング・ドキュメントのすべてで共存している。到達不能ルート・重複定義・マーカー残骸もなし。テスト93件・型チェック・Lint すべて green。

Medium 2件はいずれもドキュメントの記述精度（「3画面」という誤記と、設計書上の FR-07 導線の記載漏れ）であり、コードの動作には影響しない。マージ自体は問題なく、追って上記ドキュメントを訂正すれば整合が取れる。

### 対応

- **`screen-design.md` の画面数誤記**: 「3画面のみ」→「4画面」に訂正し、遷移説明に `MatrixPage` を追加した。
- **`component-design.md` の FR-07 導線記載漏れ**: `FormationListPage` の責務に相性マトリクス画面への導線を追記し、インターフェースに `goToMatrix(): void` を追加した。
- Low 4件は実害が小さいため申し送りとし、今回は対応しない。ただし「リンク検証テストが先頭アンカー依存」は次作業（学習体験の強化）でヘッダーにアンカーが増える可能性が高いため、その作業内でクラス指定へ寄せる。

## レビュー完了（2026-09-12 / 第2回）

- 最終ラウンド: 第2回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）:
  - リンク検証テストの先頭アンカー依存（Low。次作業でクラス指定へ寄せる）
  - `matchups` 全ペア網羅の不変条件テスト不在（Low。フォーメーション追加時に行き止まりが発生しうる。データ追加と同時に固定する）
  - `requirements-definition.md` §4.2 の FR 見出し順が非連番（Low。可読性のみ）
  - 第1回からの申し送り4件（encodeURIComponent 不足、select 早期returnのコメント不足、総合判定の `:key` 不足、SPAフォールバック未整備）は継続
  - `screen-design.md` / `3_detail-design/screen/` / `4_unit-test/` に相性マトリクス画面（FR-07）の節が存在しない（`bc78a7f` 由来の既存欠落。ドキュメント整備として別途対応する）
