# コミット前レビューレポート

## 第1回（2026-09-26）
- 対象: Bチームの自由配置対応・自由配置の座標永続化の新規実装差分（tracked 8ファイル + 新規2ファイル。`.steering/`配下の計画書は対象外）
- 結果: Critical 0件 / High 0件 / Medium 4件 / Low 6件

## コミット前レビュー結果

対象: `soccer-sim-worktrees/feature-free-layout-b-and-persistence` の作業差分全体
（`src/data/freeLayoutStorage.ts`（新規）、同テスト（新規）、`src/components/FreeLayoutPitchDiagram.vue`、
`src/pages/ComparisonPage.vue`、`src/types/formation.ts`、各テスト、`docs/specs/1_requirements/` 3件）。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし（セキュリティ必須4項目・OWASP該当の指摘はいずれも無し）

### Medium（対応推奨）

- **[バグ] A・Bが同一フォーメーションIDのとき保存データが共有され、表示と保存が食い違う**
  保存キーはフォーメーションID単位のため、A===Bの組み合わせでは理論上データが共有されうる。
  → 調査の結果、`ComparisonPage.vue`の`matchup`は同一ID同士では`getMatchup`が`undefined`を
  返すため、テンプレートの`v-if="formationA && formationB && matchup"`により
  自由配置モード自体（`FreeLayoutPitchDiagram`・トグルボタン）が描画されない
  （既存テスト「同一フォーメーション同士のIDでアクセスした場合、エラーメッセージが表示され
  ピッチ図は描画されない」で担保済み）。実際には到達不能な経路であることを確認したため、
  コードの変更は行わない。

- **[性能] `pointermove` ごとに localStorage 全ブロブの read-modify-write が走る**
  修正済み。`FreeLayoutPitchDiagram.vue`の`update-position`（表示更新用）と
  `update-position-end`（ドラッグ確定時=`pointerup`/`pointercancel`の1回のみ）を分離し、
  `savePositionOverride`の呼び出しを`update-position-end`側（`ComparisonPage.vue`の
  `onUpdatePositionEnd`）に移した。ドラッグ中の高頻度な同期I/Oを解消。

- **[バグ] `parseOverrides` が `__proto__` キーを弾いていない**
  修正済み。`DANGEROUS_KEYS`（`__proto__`/`constructor`/`prototype`）を読み込み時に
  フォーメーションID・ポジションIDの両方でスキップするガードを追加。プロトタイプ汚染で
  無関係なフォーメーションの座標を誤って拾う経路を塞いだ。テストも追加。

- **[バグ/テスト] `freeLayoutStorage.test.ts` の「消去が例外を投げても…」が空振りしている**
  修正済み。`clearFormationOverride`は対象キーが無いと早期returnしてsetItemに到達しない
  設計のため、テスト内で先に`savePositionOverride`を呼んでから例外モックを張るよう修正し、
  検証対象の経路を実際に通すようにした。

### Low / 改善提案

- **[バグ] 多タブでのlost update**: 個人用ローカル機能のため実害は小さいと判断し、対応しない（申し送り）。
- **[バグ] `EMPTY`を共有オブジェクトとして返している**: `Object.freeze`を追加し修正済み。
- **[バグ] `clampToPitchRange`の重複実装と挙動差**（NaN扱いが`freeLayoutCoordinates.ts`と異なる）:
  データ層はより厳格な防御が必要なため意図的な差異と判断し、対応しない（申し送り）。
- **[運用] 誤字「フォーメーム」**: 今回の差分内（`requirements-definition.md`・
  `functional-overview.md`・`architecture-overview.md`・`freeLayoutStorage.ts`）で修正済み。
- **[運用/UX] 重なった選手の掴み分け**: 既知の制約として申し送り（Bチームの描画が先のため、
  重なるとAが優先的に掴める）。
- **[バグ] シミュレーションと自由配置の整合（既存の踏襲）**: 既存の設計を踏襲したものであり、
  今回の差分が新たに作った欠陥ではないため対応しない（申し送り）。

### 問題なし
- セキュリティ必須4項目: シークレット/URL/クラウドアカウント情報のハードコードは無し
- localStorageに入るのはフォーメーションID・ポジションID・0-100の座標のみ、個人情報は含まない
- インジェクション/XSS: ストレージ由来の値は数値クランプを通ってSVG数値バインドにのみ流れる
- `applyOverrides`は元のpositions順序を保持、常に新しいオブジェクトを返しcanonical定義を汚染しない
- emitシグネチャ変更の整合、状態リセット漏れ無し、早期returnの妥当性
- 後方互換: 新キー追加のみ、`FreeLayoutPitchDiagram`の唯一の利用元は`ComparisonPage.vue`

### 総合評価
**Critical / High の指摘は無し。** Medium 4件のうち3件を修正、1件（A===B共有）は実際には
到達不能な経路であることを確認したため対応不要と判断。修正後、全テスト再実行し505件成功を確認。

### 対応
- pointermoveごとの同期I/O: `update-position`/`update-position-end`のイベント分離で修正済み
- `__proto__`汚染: `DANGEROUS_KEYS`ガードで修正済み、テスト追加
- 空振りテスト: 保存を先に行ってから例外モックを張る順序に修正済み
- A===B共有: 実際には到達不能と確認、コード変更なし
- 誤字: 今回差分内で修正済み
- `EMPTY`の凍結: 修正済み
- 残りのLow（多タブ・clampToPitchRangeの重複・掴み分け・既存の踏襲事項）: 実害小のため積み残し

## レビュー完了（2026-09-26）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Low）: 多タブでのlost update、`clampToPitchRange`の重複実装（意図的差異）、
  重なった選手の掴み分けの既知の制約、既存のシミュレーション/自由配置の整合の申し送り。
  いずれも実害が小さいと判断し、コード変更を伴わない申し送りとして記録済み。
