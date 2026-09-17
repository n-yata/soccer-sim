# コミット前レビューレポート

## 第1回（2026-09-11）
- 対象: `src/components/FormationCard.vue`, `src/components/MatchupPitchDiagram.vue`,
  `src/pages/FormationListPage.vue`, `src/pages/ComparisonPage.vue`, `src/main.ts`,
  `docs/specs/2_basic-design/screen-design.md`、新規 `src/styles/tokens.css` と
  `.steering/20260911-ui-redesign-sporty/`
- 結果: Critical 0件 / High 1件 / Medium 3件 / Low 4件

## コミット前レビュー結果

対象: `C:\develop\workspace-claude\soccer-sim-worktrees\feature\ui-redesign-sporty` の未コミット差分
（`src/components/FormationCard.vue`, `src/components/MatchupPitchDiagram.vue`, `src/pages/FormationListPage.vue`, `src/pages/ComparisonPage.vue`, `src/main.ts`, `docs/specs/2_basic-design/screen-design.md`、新規 `src/styles/tokens.css` と `.steering/20260911-ui-redesign-sporty/`）

渡された `review_diff.txt` は鵜呑みにせず、ワークツリーで `git diff` / 実ファイルを直接突き合わせて検証済み。差分内容は一致しており、隠された変更ファイルはない（`git status` のトラッキング対象も差分6ファイルのみ）。

### Critical（即時対応必須）
- なし

### High（優先対応）
- **[運用] 仕様書が存在しないワイヤーフレームページを参照している**: `docs/specs/2_basic-design/screen-design.md` が `wireframe-formation-list-v2(刷新後)` / `wireframe-comparison-v2(刷新後)` を参照し、`.steering/.../design.md` も「wireframes.drawio の刷新後ページで使用した配色をそのまま採用」と書いているが、`docs/specs/2_basic-design/wireframes.drawio` に存在するページは `wireframe-formation-list` と `wireframe-comparison` の2つだけ（`git status` でも drawio は未変更）。設計正本がリンク切れの状態でコミットされる。→ drawio に v2 ページを追加してからコミットするか、参照記述を実態に戻す。

### Medium（対応推奨）
- **[バグ/コンテンツ] 引き分けでもトロフィーが出る**: `ComparisonPage.vue` の `.comparison-page__verdict::before { content: "🏆 " }` がクラス非依存のため、`overallEdge === "even"`（見出しは「互角」）の場合も 🏆 が表示され、「どちらかが勝った」と誤読させる。→ `--A` / `--B` のみに `::before` を付け、`--even` は別記号（⚖ 等）か無しにする。
- **[バグ/A11y] 凡例ピルのコントラスト不足**: `.comparison-page__legend-item--red` は `--color-team-b #ef4444` を `--color-team-b-bg #fef2f2` 上に 13px で描画しており、コントラスト比が約 3.8:1 で WCAG AA を下回る。→ 赤系のテキスト色を濃色に落とす。
- **[バグ] 選択時のレイアウトジャンプ**: `FormationCard` は選択時に border 1px→3px かつ `::before` で「✓ 選択中」行を追加するため、カード高さが増えてグリッド行全体が跳ねる。→ 枠は常時 3px にする、チェック行のスペースを常時確保する。

### Low / 改善提案
- **[バグ/A11y] 疑似要素が読み上げ名に混入**: `::before` の `content` がアクセシブルネーム計算に含まれる実装があり、「✓ 選択中 4-4-2」と冗長に読み上げられる可能性がある。
- **[バグ] SVG グラデーション ID がグローバル**: `id="matchupPitchGradient"` は scoped style の対象外。将来同一ページに複数描画すると ID 重複になる。
- **[運用] CSS 変数のフォールバック無し**: `tokens.css` の読み込みが失敗すると枠線・影が丸ごと消える。
- **[性能] 影響は軽微**: ストライプ・白線の静的追加、drop-shadowフィルタは選手円（最大22個）のみで計算量・I/Oの増加はなし。

### 問題なし
- セキュリティ①〜④: シークレット・URL・アカウント情報の混入なし、認証認可・インジェクション該当箇所なし
- 「ロジック未変更」の主張: 検証の結果おおむね正しい（`colXByTeam`/`buildTeamItems`/`toggleSelection`/`watch`等は無変更）
- テスト/静的検査: `npx vitest run` 47件パス、`vue-tsc --noEmit`エラーなし、`eslint .`指摘なし

### 未検証
- 実ブラウザでの視覚確認（未実施、値からの静的算出）
- wireframes.drawioのv2ページ追加時の内容整合（ページ自体が存在せず確認不能）

### 総合評価
Critical: なし / High: 1件（仕様書のワイヤーフレーム参照がリンク切れ）。実行時のsecurity・性能リスクは認められず、「ロジック未変更」の主張も裏付けが取れた。High・Medium対応後に再レビューが必要。

### 対応
- High: main側の作業ツリーに未コミットで存在していた `wireframes.drawio`（v2ページ追加済み）をworktreeへコピー
- Medium（トロフィー）: `--A`/`--B`のみに`::before`を限定し、`--even`は⚖️に変更
- Medium（コントラスト）: 凡例のcolorを`#1d4ed8`/`#b91c1c`の濃色に変更
- Medium（レイアウトジャンプ）: `box-sizing: border-box`+border常時3pxに変更（この時点では不十分、Round2で再指摘）

---

## 第2回（2026-09-11）— 修正後の再レビュー

対象: 前回指摘4件の修正箇所のみ
（`docs/specs/2_basic-design/wireframes.drawio`, `src/pages/ComparisonPage.vue`, `src/components/FormationCard.vue`）。

### Critical（即時対応必須）
- なし

### High（優先対応）
- **[運用/バグ] drawio の旧ページ「残置」が実際には破壊されている（修正が持ち込んだ新規欠陥）**: `screen-design.md` は「旧デザインは `wireframe-comparison` に残置」と明記しているが、コピーしてきた drawio では旧ページが draw.io により再シリアライズされ、2件の内容が消えている（旧34セル → 新33セル）。
  - `note` セル（「実装: src/components/MatchupPitchDiagram.vue」参照）が丸ごと削除
  - `verdict` セルの本文が「3-5-2がやや優位」だけに短縮され、根拠テキストが消えている
  - 併せて旧ページの全セルIDが再採番されている
  → 旧2ページは HEAD の内容をそのまま戻し、v2の2ページだけを追加する形に作り直すこと。

### Medium（対応推奨）
- **[バグ] 選択時のレイアウトジャンプが半分しか直っていない**: `box-sizing: border-box` + border 常時 3px で枠幅による変動は解消したが、`::before { display: block; margin-bottom: 4px; }` が選択時にカード内へ1行を追加するため、カード高さは依然として増える。
  → 「✓ 選択中」の行スペースを常時確保する（`position: absolute` でカード内に重ねて配置し、カードに `position: relative` を付ける）。

### Low / 改善提案
- **[運用] 改行コードの扱い**: `.gitattributes` 無し・autocrlf有効のため、次にdraw.ioで保存したときに全行差分になりうる。`*.drawio text eol=lf` を推奨。
- **[A11y] ⚖️ の読み上げ**: 装飾目的の絵文字だが、見出しテキスト「互角」が別途あるため情報欠落はなし。

### 問題なし
- 🏆/⚖️の出し分け（前回Medium）: 修正済み
- 凡例のコントラスト（前回Medium）: 修正済み（`#1d4ed8` on `#eff6ff` ≈ 6.9:1、`#b91c1c` on `#fef2f2` ≈ 6.6:1、いずれもWCAG AA適合）
- drawioの参照切れ（前回High）: 参照自体は解消（ただし上記Highの副作用あり）
- セキュリティ・性能: 差分にシークレット・URL等の混入なし、性能影響なし
- 静的検査: `npx vitest run` 47件パス、`vue-tsc --noEmit`エラーなし、`eslint .`指摘なし

### 未検証
- 実ブラウザ／draw.ioでの目視確認は未実施
- v2ワイヤーフレームの座標・余白と実装のピクセル値の厳密突き合わせは未実施

### 総合評価
Critical: なし / High: 1件（修正が新たに持ち込んだdrawio旧ページの内容欠落）。Medium 3件のうち🏆出し分けとコントラストは完全に解消。レイアウトジャンプはMedium 1件が未解決。このままコミットするのは非推奨。

### 対応
- High: `git show HEAD:docs/specs/2_basic-design/wireframes.drawio` で取得したオリジナルをそのまま使い、旧2ページ（セルID・内容とも完全一致）を復元。v2の2ページはそのまま維持
- Medium（レイアウトジャンプ）: `.formation-card`に`position: relative`を追加、`.formation-card.selected::before`を`position: absolute; top: 8px; left: 0; right: 0;`に変更しフローから除外

---

## 第3回（2026-09-11）— 修正後の再レビュー

対象: Round 2 の指摘2件の修正箇所のみ（`docs/specs/2_basic-design/wireframes.drawio`, `src/components/FormationCard.vue`）。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
- **[バグ/表示] 選択バッジとフォーメーション名の余白がほぼゼロ（計算上）**: `top: 8px`の絶対配置によりバッジと名前の行ボックスが計算上2px前後重なる可能性。実際の字形では中央寄せのため衝突は限定的。→ 目視確認の結果、実際には十分な余白があり問題なし（下記「対応」参照）。
- **[運用] 改行コード（前回からの持ち越し・未対応）**: `.gitattributes`での固定を推奨（申し送り）。

### 問題なし
- drawio旧ページの復元（前回High）: 完全に直っている。HEAD版とバイト単位で完全一致（raw-identical=True）。`note`セル・`verdict`完全本文の復活を確認
- v2ページの維持: Round2で確認したものと同一、実装との配色整合も維持。drawioの差分は純粋な追加のみ（既存行の削除なし）
- レイアウトジャンプ（前回Medium）: 解消。`position: relative`+絶対配置により、選択してもカードのボックスサイズは変わらない
- スコープの逸脱なし: 他のファイルはRound2から差分行数が変わっていない
- セキュリティ: 追加は`position`系プロパティとdrawioのXMLのみ、シークレット等の混入なし
- 静的検査: `npx vitest run` 47件パス、`vue-tsc --noEmit`エラーなし、`eslint .`指摘なし、`vite build`成功

### 未検証
- 実ブラウザでの目視確認（Round3時点）は未実施と報告されたが、レポート確定後にメイン側で実施済み（下記「対応」参照）

### 総合評価
**Critical: なし / High: なし / Medium: なし。コミットしてよい。**

### 対応
- Low（選択バッジの余白）: Chromeでの目視確認（ズームスクリーンショット）を実施。「✓ 選択中」と「4-4-2」の間に十分な余白があり、重なりや窮屈さは無いことを確認。追加修正は不要と判断
- Low（改行コード）: `.gitattributes`未整備のまま申し送り（実害は現時点でなし。次回drawio編集時に整備を検討）

---

## レビュー完了（2026-09-11）
- 最終ラウンド: 第3回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）:
  - `.gitattributes` に `*.drawio text eol=lf` が未整備（Low）。次回 `wireframes.drawio` を draw.io で編集・保存する際に全行差分になる可能性があるが、悪用可能な欠陥ではなく検出テストの対象外
