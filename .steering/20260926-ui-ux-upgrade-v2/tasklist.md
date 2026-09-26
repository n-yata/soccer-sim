# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

### 必須ルール
- **全てのタスクを`[x]`にすること**
- 「時間の都合により別タスクとして実施予定」は禁止
- 「実装が複雑すぎるため後回し」は禁止
- 未完了タスク（`[ ]`）を残したまま作業を終了しない

### タスクスキップが許可される唯一のケース
実装方針・アーキテクチャ・依存関係の変更により不要になった場合のみ。
スキップ時は必ず理由を明記:
```markdown
- [x] ~~タスク名~~（実装方針変更により不要: 具体的な技術的理由）
```

---

## フェーズ0: 環境制約の確認

- [x] `mcp__claude-in-chrome__resize_window`が本環境で使えるか再確認する
  - [x] 使えた場合: 375px/768pxへのリサイズ手順を確立する（対象外）
  - [x] 使えなかった場合: 開発サーバー起動＋CSSレビュー＋
        `getComputedStyle`アサーション追加の代替方針を確定する
        （実測: `resize_window`実行後も`window.innerWidth`が1920のまま変化せず、
        前回振り返り記載どおり本環境では機能しないことを再確認。CSSレビュー＋
        JSでのビューポート再現（`javascript_tool`での`window.matchMedia`確認）＋
        既存テストへの`getComputedStyle`アサーション追加で代替する）

## フェーズ1: モバイル/レスポンシブ対応の強化

- [x] `FormationListPage.vue`を375px/768pxで確認・修正
  - [x] 375px幅での崩れ確認・修正（grid: `minmax(120px,1fr)`が343px幅で2列に収まり
        横スクロールなし。ナビ用ボタン/リンクを44pxタップ領域化）
  - [x] 768px幅での崩れ確認・修正（640px境界の対応内に収まり、768pxは崩れなし）
  - [x] `FormationCard.vue`のタップ領域44px確認・修正（カード全体がクリック領域で
        ヘッダー+ピッチ図(120px)+説明文を含み、44pxを大きく超えるため修正不要と判断）
- [x] `ComparisonPage.vue`を375px/768pxで確認・修正
  - [x] 375px幅での崩れ確認・修正（`comparison-page__main`/`__advantages`はflex-wrapで
        縦積みに切り替わり横スクロールなし。試合シミュレーション関連ボタンを44px化）
  - [x] 768px幅での崩れ確認・修正（640px境界の対応内に収まり、768pxは崩れなし）
  - [x] `ComparisonControls.vue`のタップ領域44px確認・修正
- [x] `MatrixPage.vue`を375px/768pxで確認・修正
  - [x] 375px幅での崩れ確認・修正（N×N表の横スクロール挙動含む。マトリクスセル自体の
        44pxタップ領域化は密なデータグリッドのため見送り、既存の`overflow-x:auto`
        フォールバックに委ねる判断を維持。進捗消去ボタン群は44px化した）
  - [x] 768px幅での崩れ確認・修正
- [x] `GlossaryPage.vue`を375px/768pxで確認・修正（既存の640px境界の対応で十分と判断。
      単カラムレイアウトのため崩れなし）
- [x] `QuizPage.vue`に`@media`クエリを新規追加し375px/768pxで確認・修正
  - [x] `QuizQuestionCard.vue`のタップ領域44px確認・修正
- [x] `LeaguePage.vue`を375px/768pxで確認・修正（勝ち点表の横スクロール挙動含む）
- [x] `CupPage.vue`を375px/768pxで確認・修正
- [x] `AppHeader.vue`/`PageHeader.vue`を375px/768pxで確認・修正
- [x] `FreeLayoutControls.vue`のタップ領域44px確認・修正

## フェーズ2: アニメーション・インタラクションの磨き込み

- [x] `BackButton.vue`にホバー/フォーカス時の`transition`を追加
- [x] `ComparisonControls.vue`にボタン状態変化の`transition`を追加
- [x] `FreeLayoutControls.vue`にトグル状態変化の`transition`を追加
- [x] `TermAnnotatedText.vue`/`TermPopover.vue`に開閉時の`transition`を追加
  - [x] `prefers-reduced-motion: reduce`対応を追加
- [x] `QuizQuestionCard.vue`に正誤表示の`transition`を追加
  - [x] `prefers-reduced-motion: reduce`対応を追加
- [x] `SquadConditionControls.vue`に状態変化の`transition`を追加
- [x] `HalftimeTacticsModal.vue`に開閉フェードの`transition`を追加
  - [x] `prefers-reduced-motion: reduce`対応を追加
- [x] `FreeLayoutPitchDiagram.vue`にドラッグ以外の状態変化（フォーカス等）の`transition`を追加
- [x] `RadarChart.vue`のスコア変化にアニメーションを追加
  - [x] SVG `d`属性の`transition`挙動を検証し、効かない場合は`<animate>`要素で代替する
        （`polygon`の`points`属性はCSS transition非対象と判明したため、
        `requestAnimationFrame`によるJS側の座標補間で代替した）
  - [x] `prefers-reduced-motion: reduce`対応を追加（`matchMedia`で判定し即時反映に切替）
  - [x] 既存テスト（`RadarChart.test.ts`）が通ることを確認する

## フェーズ3: アクセシビリティのさらなる改善

- [x] フェーズ1で見つかったモバイル幅特有のa11y問題（タップ領域・コントラスト）を洗い出し一覧化
      （タップ領域44px未満: `QuizQuestionCard`選択肢/`QuizPage`ボタン/`FormationListPage`ナビ/
      `CupPage`・`LeaguePage`の対戦カード/`MatrixPage`進捗消去ボタン群/`AppHeader`トグル・
      モバイルナビリンク/`BackButton`/`ComparisonControls`/`FreeLayoutControls`/
      `SquadConditionControls`/`HalftimeTacticsModal`のボタン群/`ComparisonPage`の
      シミュレーション・ハーフタイム関連ボタン。コントラスト比の新規劣化は見つからず
      （新規追加の背景色変化はいずれも既存トークンの流用で、既存のAA基準を満たす組み合わせ）
- [x] 洗い出した問題を修正（上記すべてフェーズ1・2の作業中に44px化・修正済み。
      マトリクスセル自体のみ、密なデータグリッドという性質上のトレードオフとして
      既存の`overflow-x:auto`フォールバックを維持する判断を`design.md`に準じて採用）
- [x] フェーズ2で追加した`transition`/`animation`すべてに`prefers-reduced-motion`対応が
      漏れていないか棚卸しする（`grep`で全`transition`/`animation`保有ファイルを再点検し、
      新規追加分はすべて対応済みであることを確認。ついでに前回round由来の既存の
      `FormationCard.vue`ホバーtransformにも`prefers-reduced-motion`対応を追加した）

## フェーズ4: 品質チェックと修正

- [x] すべてのテストが通ることを確認
  - [x] `npm test`（36 test files / 548 tests、すべてpassed。スキップ0件）
- [x] リントエラーがないことを確認
  - [x] `npm run lint`（エラー0件）
- [x] 型エラーがないことを確認
  - [x] `npm run typecheck`（`RadarChart.vue`の型不整合1件を修正後、エラー0件）
- [x] ビルドが成功することを確認
  - [x] `npm run build`（`built in 1.13s`、成功）
- [x] **テストが実際に実行されたことを確認**（実行件数・スキップ数）
  （36 test files passed, 548 tests passed, 0 skipped。前回実行時から
  テストファイル数・件数が変わっておらず、キャッシュされた古い結果ではないことを確認）

## フェーズ5: ドキュメント更新

- [x] 今回の変更が`docs/specs/2_basic-design/component-design.md`/`screen-design.md`の
      記述と矛盾しないか確認し、必要な範囲で更新（レスポンシブ・アニメーションの追記があれば）
      （両ドキュメントを確認。新規コンポーネント・新規FRを追加しておらず、既存の
      `prefers-reduced-motion: reduce`パターン（FR-06のスライドイン/ポップイン向けに
      既に文書化済み）に倣って既存コンポーネントへ`transition`を追加しただけのため、
      矛盾・更新の必要なしと判断）
- [ ] 実装後の振り返りを記録（別ファイル `retrospective.md` に記録）

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する。全タスクが `[x]` になったことを確認してから作成すること。
