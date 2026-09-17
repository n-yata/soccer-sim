# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

### 必須ルール
- **全てのタスクを`[x]`にすること**
- 「時間の都合により別タスクとして実施予定」は禁止
- 「実装が複雑すぎるため後回し」は禁止
- 未完了タスク（`[ ]`）を残したまま作業を終了しない

### タスクスキップが許可される唯一のケース
実装方針の変更・アーキテクチャ変更・依存関係の変更により、タスクが不要または実行不可能に
なった場合のみ。スキップ時は理由を明記する:
```markdown
- [x] ~~タスク名~~（実装方針変更により不要: 具体的な技術的理由）
```

---

## フェーズ1: スコア概算ロジック（`radarScoreEstimator.ts`）

- [x] `src/types/formation.ts` に `estimateStats` が使う型が既存のもの（`FormationTag`,
      `FormationStats`）で足りるか確認する（不足があれば追加しない。既存型で表現できることを
      設計の前提としている）
- [x] `src/data/radarScoreEstimator.ts` を新規作成する
  - [x] タグ→軸の加減算テーブル定数を定義する（`formationTags.ts`のしきい値定数と同様、
        JSDocで各値の意図を記述する。数値は開発者本人がレビューする前提で暫定値を置く）
  - [x] `estimateStats(currentTags: FormationTag[], originalTags: FormationTag[], baseStats: FormationStats): FormationStats`
        を実装する（新たに立った/消えたタグの差分だけを加減算し、軸ごとに合計してから
        最後に1回だけ0-100へクランプする）
- [x] `src/data/radarScoreEstimator.test.ts` を新規作成する
  - [x] タグ差分が無い場合、`estimateStats`が`baseStats`と完全一致することを検証する
  - [x] 特定タグの追加で該当軸が期待通り増減することを検証する
  - [x] 特定タグの削除で該当軸が期待通り増減することを検証する
  - [x] 複数タグが同一軸に影響する場合の境界値（0未満・100超になるケース）でクランプが
        正しく働くことを検証する

## フェーズ2: 自由配置ピッチ図（`FreeLayoutPitchDiagram.vue`）

- [x] `src/components/freeLayoutCoordinates.ts` を新規作成する（座標変換をDOM非依存の
      純粋関数として切り出し、jsdom環境でも直接検証できるようにする。設計変更点として
      design.mdには明記していなかったが、CTM依存のドラッグロジックとテスト容易性を
      両立するため実装時に追加した）
  - [x] 実座標(0-100)→SVG座標への線形マッピング関数と、その逆変換関数を実装する
  - [x] ピッチ範囲(0-100)へのクランプ関数を実装する
- [x] `src/components/freeLayoutCoordinates.test.ts` を新規作成する
  - [x] 座標変換の往復（0-100→SVG→0-100）が元の値に戻ることを検証する（A/B双方）
  - [x] クランプ関数の境界値（下限・上限）を検証する
- [x] `src/components/FreeLayoutPitchDiagram.vue` を新規作成する
  - [x] props: `formationA: Formation`, `formationB: Formation` を受け取るSVG描画を実装する
        （viewBoxは`MatchupPitchDiagram`と統一感のあるサイズにする）
  - [x] Aチームの選手（`<circle>`）に`pointerdown`/`pointermove`/`pointerup`を実装し、
        `setPointerCapture`でドラッグ追従させる
  - [x] ドラッグ中の座標をピッチ範囲(0-100)にクランプしてから
        `update-position(positionId: string, x: number, y: number)` をemitする
  - [x] Bチームの選手は固定表示のみとし、ドラッグハンドラを付与しない
- [x] `src/components/FreeLayoutPitchDiagram.test.ts` を新規作成する
  - [x] Bチームの選手に`pointerdown`をシミュレートしても`update-position`がemitされないことを検証する
  - [x] Aチームのみドラッグ可能クラスが付与されることを検証する
  - [x] 実座標からのSVG描画位置がfreeLayoutCoordinatesの変換と一致することを検証する

## フェーズ3: 比較画面への統合（`ComparisonPage.vue`）

- [x] 自由配置モードのトグルUI（ボタンまたはスイッチ）を追加する
- [x] `isFreeLayoutMode: Ref<boolean>` と `freePositionsA: Ref<Position[] | null>` を追加する
- [x] トグルON時に `freePositionsA` を `formationA.value.positions` のコピーで初期化する
- [x] `effectiveFormationA` computed を実装する（`freePositionsA`があれば positions を
      差し替えたFormationを返す）
- [x] `matchup` computed を実装する（`freePositionsA`が無ければ既存の`getMatchup`、
      あれば`generateMatchup(effectiveFormationA, formationB)`を都度呼ぶ。設計時点の
      名称案`effectiveMatchup`ではなく、既存の`matchup`変数をそのまま置き換えることで
      呼び出し側（テンプレート・`runSimulation`・学習進捗記録）の変更を最小化した）
- [x] `radarSeries` のAチーム側の値を、`freePositionsA`がある場合は
      `estimateStats(getTags(effectiveFormationA), getTags(formationA), formationA.stats)`
      に差し替える
- [x] テンプレートで `isFreeLayoutMode` により `MatchupPitchDiagram` と
      `FreeLayoutPitchDiagram` を出し分ける（`v-if`/`v-else`）
- [x] `FreeLayoutPitchDiagram` の `update-position` イベントを受け、`freePositionsA` 内の
      該当Positionを更新するハンドラを実装する
- [x] リセットボタンを追加し、押下時に `freePositionsA` を元の
      `formationA.value.positions` のコピーで再初期化する（モードは維持）
- [x] 既存の組み合わせ切替監視 `watch(() => [formationA.value?.id, formationB.value?.id], ...)`
      に相乗りし、組み合わせが変わったら `isFreeLayoutMode=false`, `freePositionsA=null`
      にリセットする処理を追加する

## フェーズ4: 品質チェックと修正

- [x] すべてのテストが通ることを確認
  - [x] `npm test`（434件pass。新規: radarScoreEstimator 5件、
        freeLayoutCoordinates 9件、FreeLayoutPitchDiagram 4件、
        ComparisonPage自由配置モード関連 6件を追加）
- [x] リントエラーがないことを確認
  - [x] `npm run lint`（エラー・警告無し）
- [x] 型エラーがないことを確認
  - [x] `npm run typecheck`（エラー無し）
- [x] ビルドが成功することを確認
  - [x] `npm run build`（成功）
- [x] **テストが実際に実行されたことを確認**（実行件数・スキップ数）
      → 26 test files / 427 tests、スキップ0件で全実行を確認済み

## フェーズ4.5: 実装検証（`review-implementation`）と対応

- [x] `review-implementation`（分離起動の`general-purpose`サブエージェント）で検証を実施
- [x] [必須] `ComparisonPage.test.ts`の再計算検証テストが恒真テストだった指摘に対応
      （トグルON直後とemit後の値を比較し、タグが実際に変わる座標移動を使う形に書き直した）
- [x] [推奨] `FreeLayoutPitchDiagram.test.ts`にドラッグの実配線
      （pointerdown→pointermove→getScreenCTMスタブ→emit）のテストを3件追加
      （通常ドラッグ・ピッチ外クランプ・pointerup後は再emitしない、の3ケース）
- [x] [推奨] `ComparisonPage.vue`の自由配置トグル・リセットUIを
      `src/components/FreeLayoutControls.vue`（新規、テスト付き）へ切り出し、
      ファイルサイズ規約（250行目安）への接近を図った（538行→501行。既存の
      アドバンテージ・シミュレーション表示等、本機能追加前から存在した記述量が
      大半を占めるため、250行以内への到達は本タスクのスコープ外とし、
      申し送りとしてretrospective.mdに残す）
- [x] 再検証: `npm test`（434件pass）/ `npm run lint` / `npm run typecheck` /
      `npm run build` が全て成功することを確認

## フェーズ4.6: コミット前レビュー（`review-pre-commit`）と対応

- [x] `review-pre-commit`（分離起動の`general-purpose`サブエージェント、opus）で
      セキュリティ・バグ・性能・運用の4観点レビューを実施。Critical/High: 0件、
      Medium: 3件、Low: 5件
- [x] `npm install`実行時にworktree特有の副作用で`package.json`/`package-lock.json`へ
      self-referencing dependency（`formation-lab: file:../../soccer-sim`）が混入していたのを
      発見・revertした（レビュー対象から除外することを確認）
- [x] [Medium] ポインタキャプチャ喪失時のスティッキードラッグを修正
      （`onPointerMove`で`buttons===0`を検知し回復。テストで固定）
- [x] [Medium] 非可逆CTMによるNaN座標の伝播を修正
      （`toPitchCoords`で`Number.isFinite`確認。テストで固定）
- [x] [Medium] 自由配置モードと試合シミュレーション結果の不整合を修正
      （トグルON時・`onUpdatePosition`時に`simulationResult`を破棄。テストで固定）
- [x] [Low 5件] は実害が限定的なため積み残しとし、`review-report.md`の
      「レビュー完了」欄に記録した
- [x] 修正後の再検証: `npm test`（438件pass）/ `npm run lint` / `npm run typecheck` /
      `npm run build` が全て成功することを確認
- [x] `review-report.md`を`.steering/20260918-自由配置モード/`へ出力した

## フェーズ5: ドキュメント更新

- [x] `docs/specs/1_requirements/requirements-definition.md`（FR一覧・スコープ§6.1/6.2）に
      FR-15を追記した（機能一覧・機能詳細と受け入れ基準・画面参考表・スコープ対象範囲・
      スコープ外の更新: 「自由配置機能」を「Bチームの自由配置」「座標の永続化」に分割）
- [x] `docs/specs/1_requirements/functional-overview.md`（画面設計・ユースケース一覧・
      モジュール構成図）に自由配置モードを追記した（比較画面の主な要素・表示項目表・
      UC-06・モジュール構成図へのradarScoreEstimator.ts追加と補足注記）
- [x] `docs/specs/1_requirements/repository-structure.md`（ディレクトリ構造）に
      新規ファイル（`radarScoreEstimator.ts`, `FreeLayoutPitchDiagram.vue`,
      `freeLayoutCoordinates.ts`, `FreeLayoutControls.vue`）を追記した
- [x] ドキュメント更新後の再レビュー: 記述のみの変更（コマンド・設定値・手順の変更なし）
      のため、自己確認で代替した（`git-workflow.md`の方針に従う）
- [x] 実装後の振り返りを記録（別ファイル `retrospective.md` に記録 → モード3）

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する。全タスクが `[x]` になったことを確認してから作成すること。

---

## 追記（2026-09-18・復旧作業）

mainへのマージ直後にmainリポジトリ本体が消失するインシデントが発生し、生き残っていた
別worktreeのスナップショットを基点にmainを再構築、本機能のコード一式をこのセッションの
会話履歴から再現して復旧した。詳細は同ディレクトリの`retrospective.md`「インシデント対応」
節、および記憶
（`project_20260918-main-branch-data-loss-incident.md`,
`feedback_git-worktree-destructive-sequencing.md`）を参照。
