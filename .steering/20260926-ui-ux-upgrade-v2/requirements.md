# 要求内容

## 概要

前回のUI/UXアップグレード（`feature/ui-ux-upgrade`, 2026-09-26マージ済み）で対応しきれなかった、
モバイル幅での実機確認・レスポンシブ対応の穴、インタラクション/アニメーションの質感、
アクセシビリティの積み残しをまとめて解消する第2弾。

## 背景

前回の振り返り（`.steering/20260926-ui-ux-upgrade/retrospective.md`）で、以下が次回への
申し送りとして残っている。

- モバイル幅（375px/768px）での実機目視確認が、ブラウザ自動操作の`resize_window`が本環境で
  機能しない制約により未実施のまま持ち越しになった。
- 新規コンポーネントを作る際の依存関係ルール確認の徹底。

加えて、現状の実装を機械的に棚卸しした結果、以下のギャップが判明している（`grep`による
`@media`/`animation`/`transition`/`prefers-reduced-motion`の出現数調査、2026-09-26実施）。

- `QuizPage.vue`は`@media`クエリを1つも持たず、モバイル幅での崩れが未検証。
- `CupPage.vue`/`FormationListPage.vue`/`GlossaryPage.vue`/`LeaguePage.vue`/`MatrixPage.vue`/
  `AppHeader.vue`/`PageHeader.vue`は`@media`が1件のみ（640px境界のみ対応、768px帯の中間幅は
  未検証）。
- `RadarChart.vue`（アニメーション付きのSVG描画）・`HalftimeTacticsModal.vue`（モーダル）・
  `FreeLayoutPitchDiagram.vue`（ドラッグ操作）・`ComparisonControls.vue`・`BackButton.vue`・
  `TermAnnotatedText.vue`/`TermPopover.vue`・`QuizQuestionCard.vue`・`SquadConditionControls.vue`が
  `transition`を1つも持たず、状態変化（フォーカス・ホバー・開閉）が瞬間切り替えになっている。
- `prefers-reduced-motion`への対応は`ComparisonPage.vue`/`MatchSimulationPanel.vue`/
  `MatchupPitchDiagram.vue`の3ファイルのみ。アニメーションを追加する箇所は必ず対で実装する必要がある。

## 実装対象の機能

### 1. モバイル/レスポンシブ対応の強化

- 375px（狭小スマホ幅）・768px（タブレット幅）の2ブレークポイントで、既存の全画面
  （`FormationListPage`/`ComparisonPage`/`MatrixPage`/`GlossaryPage`/`QuizPage`/`LeaguePage`/`CupPage`）
  のレイアウト崩れ（横スクロール発生・要素の重なり・タップ領域不足）を洗い出し、修正する。
- ブラウザ自動操作でのウィンドウリサイズが本環境で機能しない制約を踏まえ、
  `resize_window`が使えるか最初に確認し、使えない場合は開発サーバー起動+Chrome DevToolsの
  レスポンシブモード相当（`javascript_tool`での`viewport`再現、または実ブラウザでの手動確認）で代替する。
- タップ領域は44x44px以上を目安に確保する（既存の`ComparisonControls`/`FreeLayoutControls`等の
  ボタン類を対象に点検）。

### 2. アニメーション・インタラクションの磨き込み

- `transition`を持たない対話的コンポーネント（上記ギャップ一覧）に、状態変化
  （ホバー・フォーカス・開閉・選択）に対する適切な`transition`を追加する。
- アニメーション（`animation`/キーフレーム）を新規追加する箇所には、既存の
  `ComparisonPage.vue`のパターンに倣い`@media (prefers-reduced-motion: reduce)`を対で実装する。
- 既存の`RadarChart.vue`の描画更新（フォーメーション切替時のスコア変化）に、値の変化が
  視覚的に追えるトランジションを追加する。

### 3. アクセシビリティのさらなる改善

- モバイル幅で新たに発生するタップ領域・コントラスト比の問題を点検し、`docs/specs/1_requirements/
  non-functional-requirements.md`（該当なければ`requirements-definition.md`のNFR）のa11y基準に
  照らして修正する。
- `prefers-reduced-motion`未対応のアニメーション追加箇所は、追加と同時に対応させる（後回しにしない）。

## 受け入れ条件

### モバイル/レスポンシブ対応の強化
- [ ] 375px幅で全7画面を確認し、横スクロールが発生しないこと
- [ ] 768px幅で全7画面を確認し、レイアウト崩れ（要素重なり・はみ出し）がないこと
- [ ] 主要な操作ボタン（比較画面のA/B切替、クイズの選択肢、フォーメーションカード等）が
      タップ領域44x44px以上を満たすこと
- [ ] 既存のVitestテスト（`getComputedStyle`アサーション含む）がすべて通ること

### アニメーション・インタラクションの磨き込み
- [ ] 前述のギャップ一覧に挙げた対話的コンポーネントに`transition`が追加されていること
- [ ] 新規追加した`animation`/`transition`のうち視差・動きを伴うものすべてに
      `prefers-reduced-motion: reduce`時の無効化・簡略化が実装されていること
- [ ] `RadarChart.vue`のスコア変化にアニメーションが追加され、既存のスナップショット的な
      挙動を壊さないこと（既存テストが通ること）

### アクセシビリティのさらなる改善
- [ ] モバイル幅で新たに発生したa11y上の問題（あれば）が修正されていること
- [ ] 新規追加したアニメーションがすべて`prefers-reduced-motion`に対応していること

## 成功指標

- 定量: 上記受け入れ条件の全チェックボックスが満たされること。既存テストスイート
  （`npm test`）がすべてパスすること。
- 定性: 375px/768px幅での実機（またはそれに準ずる方法）目視確認が完了し、
  前回持ち越しになった申し送り事項が解消されること。

## スコープ外

以下はこのフェーズでは実装しません:

- 新規画面・新規機能（FR番号を持つ機能追加）の実装
- カラーパレット・ブランディングの刷新（前回`feature/ui-ux-upgrade`で対応済みの方向性を維持する）
- パフォーマンスチューニング（`architecture-overview.md`によりNFR対象外）

## 参照ドキュメント

- `docs/specs/1_requirements/requirements-definition.md`
- `docs/specs/1_requirements/architecture-overview.md`
- `docs/specs/1_requirements/repository-structure.md`
- `.steering/20260926-ui-ux-upgrade/retrospective.md`（前回の申し送り事項）
