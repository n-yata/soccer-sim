# コミット前レビューレポート

## 第1回（2026-09-18）

- 対象: worktree `feature-free-layout-mode` の未コミット差分全量
  （`ComparisonPage.vue`/`.test.ts`、新規 `FreeLayoutControls.vue`・`FreeLayoutPitchDiagram.vue`・
  `freeLayoutCoordinates.ts`・`radarScoreEstimator.ts` と各テスト、
  `docs/specs/1_requirements/` 3件、`.steering/20260918-自由配置モード/` 3件）
- 結果: Critical 0件 / High 0件 / Medium 3件 / Low 5件

## コミット前レビュー結果

対象: worktree `feature-free-layout-mode` の未コミット差分全量（`ComparisonPage.vue`/`.test.ts`、新規 `FreeLayoutControls.vue`・`FreeLayoutPitchDiagram.vue`・`freeLayoutCoordinates.ts`・`radarScoreEstimator.ts` と各テスト、`docs/specs/1_requirements/` 3件、`.steering/20260918-自由配置モード/` 3件）。読み取りのみ、ファイルは一切変更していない。新規・変更テスト5ファイル 67件はローカルで全green。

### Critical（即時対応必須）

なし

### High（優先対応）

なし

### Medium（対応推奨）

- **[バグ] ポインタキャプチャ喪失時のスティッキードラッグ** — `FreeLayoutPitchDiagram.vue:96-113`。`setPointerCapture?.()` はオプショナル呼び出しで、キャプチャが張れない／`lostpointercapture` で失われた環境では SVG 外で `pointerup` しても `draggingPositionId` が `null` に戻らない。その後ボタンを押していない状態で SVG 上にポインタを戻すと、選手が追従して動き続ける（`pointerup` ハンドラは SVG にしか張っていない）。ボタン押下状態の検査を入れるのが最小修正。
- **[バグ] 非可逆な CTM での NaN 伝播** — `FreeLayoutPitchDiagram.vue:84-108` + `freeLayoutCoordinates.ts:39-41`。`ctm.inverse()` は非可逆行列（要素が `display:none`・幅0でレイアウトされた瞬間など）でも例外を投げず NaN 成分を返す。`clampToPitchRange` は NaN を素通しするため、NaN 座標が `freePositionsA` に入る。以降 `deriveTags` の閾値比較はすべて false 側に倒れ、タグが静かに消えて優位ポイント・総合判定が誤る。
- **[バグ] 自由配置モードと試合シミュレーションの整合が取れていない** — `ComparisonPage.vue:195-208`。`runSimulation` は自由配置反映済みの`matchup.value`と、元のstats/positionsの`formationA.value`を混ぜて渡す。さらに`simulationResult`は組み合わせ切替でしかクリアされないため、シミュレーション表示中に自由配置モードへ入る／選手を動かすと、更新後のピッチ図・レーダー・総合判定の隣に古いシミュレーション結果が残り、画面全体として矛盾する。

### Low / 改善提案

- **[バグ] 同一ルールが左右で発火したときの文言タイブレークが順序依存** — `matchupGenerator.ts`の`pickIndexAvoiding`は「先に処理したa側」を優先する。通常表示は正準順で生成されたキャッシュを見るのに対し、自由配置モードはroute の並び順のまま`generateMatchup(a, b)`を呼ぶため、逆順ペアではトグルON直後（配置未変更でも）一部の優位ポイントの言い回しが変わりうる（方向自体は正しく、実害は文言のみ）。
- **[バグ] フォールバック文だけ元statsを見る** — ルールが1件も当たらない配置になったときの`fallbackFor`は元statsの最大軸を使うため、レーダー表示と根拠文がわずかにずれる場合がある。
- **[バグ] 新規タグ追加時に無言で0デルタ** — `radarScoreEstimator.ts`のテーブル型が`Partial<Record<...>>`のため、将来タグを追加してもテーブルへの追記漏れが型エラーにならない。
- **[運用/アクセシビリティ] キーボード操作手段がない** — ドラッグのみで配置変更でき、キーボードでの代替操作がない（既存要件にa11y要求が無いため申し送りに留める）。
- **[バグ/仕様] Aチームは自陣ハーフから出られない** — `depthToCx`の設計上、ハーフウェーラインを越える配置は試せない。仕様として意図どおりならFR-15に明記しておくとよい。

### 問題なし

- セキュリティ①〜④・OWASP該当項目: ハードコーディング・シークレット・URL直書きなし。認証・認可は該当なし。インジェクション経路（`v-html`等）なし。ログへの機密情報出力なし。`.gitignore`は既存のまま緩んでいない。`package.json`/`package-lock.json`に差分なし（`npm install`のworktree副作用は事前にrevert済み）。
- バグ: 座標変換は往復可逆・ゼロ除算なし（テストで確認済み）。`estimateStats`は軸ごとに合計後に一度だけクランプし二重計上なし、タグ無変化時は`baseStats`と完全一致。状態リセットは組み合わせ切替・トグルOFF・リセットボタン・アンマウントの各経路を確認、`freePositionsA`は深めのコピーで静的データを破壊しない。テストは恒真化していない。
- 運用: 追加は新規ファイルとComparisonPageへの加算のみで、revertで完全に戻せる。ドキュメント（FR-15・UC-06・モジュール構成図・リポジトリ構造）との整合が取れている。

### 未検証

- 実ブラウザでのポインタイベント挙動（キャプチャ喪失・タッチ／ペン入力）。jsdomでは`getScreenCTM`/`createSVGPoint`をスタブせざるを得ないため、Medium指摘は静的解析ベース。

### 総合評価

Critical / High の指摘はなし。Medium 3件（スティッキードラッグ、NaN伝播、シミュレーション結果の不整合）は「静かに誤る」型の欠陥のため、コミット前に対応することとした。

## 対応

- **[Medium] スティッキードラッグ**: `onPointerMove`の先頭で`event.buttons === 0`を検知し`onPointerUp()`を呼んで回復するよう修正。再現条件（ポインタキャプチャ喪失時のbuttons=0でのpointermove）をテストで固定した（`FreeLayoutPitchDiagram.test.ts`「ポインタキャプチャを喪失し...」）。
- **[Medium] NaN伝播**: `toPitchCoords`で`Number.isFinite`により変換後の座標が有限値か確認し、非有限ならnullを返して`update-position`をemitしないよう修正。テストで固定した（`FreeLayoutPitchDiagram.test.ts`「CTMが非可逆でNaN座標になった場合...」）。
- **[Medium] シミュレーション結果の不整合**: 自由配置トグルON時・`onUpdatePosition`実行時に`simulationResult.value = null`を設定し、古いシミュレーション結果を破棄するよう修正。テストで固定した（`ComparisonPage.test.ts`「自由配置トグルON時...」「配置変更(update-position)で...」）。
- **[Low 5件]**: いずれも実害は限定的（文言のズレ・将来の型安全性・a11y・仕様明確化）と判断し、今回は修正せず積み残しとする。再発防止のための追跡は行っていない（実害があった場合の再現手順は別途起票する）。

## レビュー完了（2026-09-18）

- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）:
  - マッチアップ文言のタイブレークが呼び出し順序に依存する点（実害は文言のみ、検出テストなし）
  - フォールバック文と自由配置モードのレーダー表示のわずかなズレ（検出テストなし）
  - `radarScoreEstimator.ts`のタグテーブル型が将来の追記漏れを検出しない（検出テストなし）
  - キーボードでの配置操作手段がない（a11y。既存要件に含まれないため対応保留）
  - Aチームが自陣ハーフを越えて配置できない仕様の明記（FR-15への追記は今回未実施）
