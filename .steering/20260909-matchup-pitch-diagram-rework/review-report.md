# コミット前レビューレポート

## 対象

main からの未コミット差分。`PitchDiagram.vue`（1フォーメーション×2枚重ね合わせ方式）を
廃止し、`MatchupPitchDiagram.vue`（2フォーメーションをまとめて受け取り、GK-DF-MF-FWの
非対称な列配置で1つのSVGに描画する新設計）に置き換えた一連の変更。

- 新規: `src/components/MatchupPitchDiagram.vue`, `src/components/MatchupPitchDiagram.test.ts`
- 削除: `src/components/PitchDiagram.vue`, `src/components/PitchDiagram.test.ts`
- 更新: `src/pages/ComparisonPage.vue`, `src/pages/ComparisonPage.test.ts`
- ドキュメント更新: component-design.md, screen-design.md, screen-02-comparison.md,
  test-screen-02-comparison.md, repository-structure.md, requirements-definition.md,
  wireframes.drawio

## 実施方法

サブエージェント(review-pre-commit)によるレビューを開始したが、週間APIリミットに達し
途中で終了したため、メインエージェントが直接、同じ4観点（セキュリティ・バグ・性能・運用）で
差分をレビューした。

## レビュー結果

### Critical / High

なし。

### 確認した項目

**セキュリティ**: ハードコードされたシークレット・URL・認証情報なし。外部通信・DB・
認証機構を持たない静的SPA。`v-html`不使用でXSSリスクなし。OWASP Top 10該当なし。

**バグ・正しさ**:
- `viewBox="-5 0 270 160"`に対し、`colXByTeam`の最大値（B.GK=260）は選手円の半径4を
  加えても264でviewBox右端（265）に収まる。他の列位置も同様に範囲内。
- `cy`の計算式（`10 + (index+0.5)/positions.length*140`）の値域はおよそ10〜150で、
  半径4を考慮してもviewBox高さ160に収まる。
- `key`属性（`${item.team}-${item.position.id}`）は、同一フォーメーション同士の比較
  （例: 4-4-2 vs 4-4-2）でもteam接頭辞により一意性が保たれる。
- GKのcyフォールバック値（80）は、DFラインが0人の場合にのみ使用されるが、実データ
  （`formations.ts`）では全フォーメーションにDFが1人以上存在するため到達しない。
- 新規追加した`MatchupPitchDiagram.test.ts`のテストは、実データの具体的な数値関係
  （4-3-3のDF列の昇順配置、3-5-2のCB(50,15)とGKのcy厳密一致など）を検証しており、
  型が保証することの再確認や実装コピーになる恒真テストではない。
- `ComparisonPage.test.ts`は、`PitchDiagram`への参照を`MatchupPitchDiagram`の
  `formationA`/`formationB` propsの検証に正しく置き換えている。

**性能**: 選手数は最大11人程度で、`buildTeamItems`の計算量に懸念なし。`items` computed
は`formationA`/`formationB`変更時のみ再計算される。

**運用**: `PitchDiagram.vue`削除後の参照漏れはない（`ComparisonPage.test.ts`の
インポートを含め全て`MatchupPitchDiagram`に置き換え済み、grepで確認済み）。ドキュメント
7ファイルの記述は新しい列配置ロジック（非対称なcolXByTeam、GKの中央CB合わせ）と一致している。

### 未検証

- ブラウザでの実描画（座標計算による静的検証のみ。ただし全フォーメーション組み合わせの
  距離検証テスト29件が実描画座標に基づいて実行され全パスしている）

## 品質チェック結果

- `npm run test`: 46件全パス
- `npm run lint`: 0 problems
- `npm run typecheck`: 0エラー
- `npm run build`: 成功

## 総合評価

Critical / High の指摘なし。コミット可能。
