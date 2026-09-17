# 実装後の振り返り

## 作業概要

比較画面(`ComparisonPage.vue`)に「自由配置モード」（FR-15）を追加した。Aチームの選手を
ドラッグして配置を変えると、タグ・優位ポイント・総合判定・レーダーチャート(Aチームのみ)が
リアルタイムで再計算される。永続化はしない。新規: `radarScoreEstimator.ts`（タグ差分から
スコアを概算する純粋関数）、`freeLayoutCoordinates.ts`（座標変換の純粋関数）、
`FreeLayoutPitchDiagram.vue`（自由配置用ピッチ図）、`FreeLayoutControls.vue`（トグル・
リセットUI）。既存の`ComparisonPage.vue`に状態管理と出し分けを追加した。

**追記（2026-09-18・インシデント対応）**: mainへのマージ直後にmainリポジトリ本体（`.git`含む）が
消失するインシデントが発生し、生き残っていた別worktreeのスナップショットからmainを再構築、
本機能のコード一式をこのセッションの会話履歴から再現して復旧した。詳細は本ファイル末尾の
「インシデント対応」節を参照。

## 実装完了日

2026-09-18

## 対象リポジトリ・コミット

- 対象リポジトリ: 本リポジトリ（単一リポジトリ構成）
- ブランチ: 復旧後は`master`（root-commit）に直接コミット。インシデントにより
  `feature/free-layout-mode`ブランチ・worktreeは失われている（詳細は「インシデント対応」参照）

## コミット前レビュー（review-pre-commit）の結果

- 実施日: 2026-09-18
- 結果: Critical 0件 / High 0件 / Medium 3件 / Low 5件
- Critical / High への対応: 指摘なし
- Medium 3件への対応: 全て修正済み（ポインタキャプチャ喪失時のスティッキードラッグ、
  非可逆CTMによるNaN座標の伝播、自由配置モードと試合シミュレーション結果の不整合。
  いずれも修正内容を検証するテストを追加した）
- Low 5件: 実害が限定的なため積み残し（詳細は`review-report.md`「レビュー完了」欄）
- レポート全文: [review-report.md](./review-report.md)

## 計画と実績の差分

**計画と異なった点**:
- design.mdでは想定していなかった`freeLayoutCoordinates.ts`（座標変換の純粋関数を
  DOM非依存で切り出す設計）を実装時に追加した。理由: `FreeLayoutPitchDiagram.vue`の
  ドラッグロジックが`getScreenCTM`等のDOM APIに依存すると、jsdom環境（未実装のAPI）で
  座標変換そのものをテストできない。純粋関数として切り出すことで、往復変換・境界値を
  DOM非依存にテストできるようにした。
- `matchup` computed の名称は design.md 時点の案`effectiveMatchup`ではなく、既存の
  `matchup`変数をそのまま置き換える形にした。呼び出し側（テンプレート・`runSimulation`・
  学習進捗記録）の変更を最小化するため。
- design.mdには無かった`FreeLayoutControls.vue`への切り出しを、review-implementationの
  指摘（`ComparisonPage.vue`のファイルサイズ規約超過）を受けて追加した。

**新たに必要になったタスク**:
- `review-implementation`（実装検証）で発見された、`ComparisonPage.test.ts`の再計算検証
  テストが恒真テストになっていた問題への対応（トグルON直後とemit後の値比較、タグが
  実際に変わる座標移動を使う形に書き直し）
- `FreeLayoutPitchDiagram.test.ts`への実ドラッグ配線（`pointerdown`→`pointermove`→
  `getScreenCTM`スタブ→emit）テストの追加（当初のテストはBチーム側の早期returnしか
  検証できていなかった）
- `review-pre-commit`で発見されたMedium3件（スティッキードラッグ・NaN伝播・
  シミュレーション結果の不整合）への対応と、それぞれの検証テスト追加
- （インシデント対応後に追加）mainリポジトリ全体の再構築、および本機能コード一式の
  会話履歴からの再現

**技術的理由でスキップしたタスク**: なし（全タスク完了）

## 学んだこと

**技術的な学び**:
- jsdomは`SVGGraphicsElement.getScreenCTM`/`createSVGPoint`を実装していない。DOM座標変換に
  依存するドラッグロジックをテストする際は、(1) 変換ロジック自体を純粋関数として切り出して
  直接テストする、(2) 実配線のテストは`getScreenCTM`等をテスト側でスタブする、の2段構えが
  必要だった。
- 「トグルON直後の値」と「emit前後の値」を比較する形でないと、estimateStatsのような
  「差分が無ければ入力と完全一致する」設計の再計算ロジックは、参照比較（`not.toBe`）だけの
  テストが恒真化する（review-implementationの指摘で発覚）。
- `PointerEvent`は`buttons`プロパティのデフォルト値が0であるため、`vue-test-utils`の
  `trigger("pointermove", {...})`では明示的に`buttons: 1`を渡さないと「ボタンを押していない
  状態のpointermove」として扱われる。本番のドラッグ判定ロジックに`buttons`チェックを
  追加した後は、既存テストの`trigger`呼び出しも合わせて更新が必要だった。
- `npm install`をこの開発環境で実行すると、対象ディレクトリ名に関わらず
  `"formation-lab": "file:"`（自己参照）という不正な依存が`package.json`/
  `package-lock.json`へ混入することがある（原因不明の環境固有の現象。少なくとも2回、
  異なるディレクトリで再現した）。`npm install`後は必ず`package.json`のdependenciesを
  確認し、混入していれば元に戻す運用が必要。

**プロセス上の改善点**:
- `review-implementation`→修正→`review-pre-commit`→修正、という2段階の検証で、
  異なる観点（スペック準拠・テストの実効性 / セキュリティ・静かに誤るバグ）の指摘を
  それぞれ拾えた。恒真テストの指摘は前者、NaN伝播・スティッキードラッグは後者でしか
  見つからなかった可能性が高く、2段階を省略しない価値があった。

## 次回への改善提案

- ドラッグ・座標変換を伴うUIコンポーネントを新規実装する際は、最初から座標変換ロジックを
  DOM非依存の純粋関数に分離する設計を design.md の時点で明記しておくと、実装フェーズでの
  手戻り（今回のfreeLayoutCoordinates.ts追加）を避けられる。
- `PointerEvent`を使うドラッグ実装のテストでは、`buttons`プロパティを明示的に指定する
  ことをテスト作成時のチェックリストに含めるとよい（デフォルト0で「ボタンを離した状態」と
  誤って検証してしまう罠がある）。
- **mainへのマージ直後は、次のコマンドを打つ前に必ず単独で`git status`等の確認を挟み、
  確認と破壊的操作（`worktree remove`, `branch -d`等）を同一の`&&`チェーンに入れない。**
  詳細は下記「インシデント対応」を参照。

---

## インシデント対応（2026-09-18）

### 何が起きたか

`feature/free-layout-mode`をmainへマージした直後、確認を挟まず
`git worktree remove ... && git branch -d ... && ...`を`&&`で連投したところ、
このコマンドの実行開始時点で`main`リポジトリ本体（`.git`含む全ファイル）が
既に消失していた。リモートリポジトリが設定されておらず、外部バックアップも
存在しなかったため、mainの全コミット履歴（15件以上の過去のfeature実装の変遷）が
実質的に復旧不能になった。

原因の技術的な特定は完全にはできていない。セッション中に複数回観測された
「Shell cwd was reset to ...」という、指示していないタイミングでの作業ディレクトリの
巻き戻しが、この事象と関連している可能性が最も高いと判断した（Bashツールの実行基盤が
呼び出しの合間に作業ディレクトリ・ファイルツリーを暗黙に同期し直す挙動を持っている
可能性がある）。詳細な調査記録は記憶
（`feedback_git-worktree-destructive-sequencing.md`）に残した。

### 復旧の方法

1. Recycle Bin・VSS（Volume Shadow Copy）を確認したが、前者は無関係な古い削除物のみ、
   後者は管理者権限が無く確認不可だった。
2. `soccer-sim-worktrees/`配下に、別セッションが作成した2つのworktree
   （`feature/ogp-support`, `feature-league-simulation`）が生き残っていることを発見した。
   いずれも`.git`ポインタの参照先（main側の`.git/worktrees/...`）は失われていたが、
   チェックアウト済みのファイル自体は残っていた。
3. 両worktreeを比較し、`feature/ogp-support`が独自の機能変更をまだ含んでいない
   （`.steering`に自身の作業ディレクトリが無い）クリーンな状態であることを確認し、
   これをmain再構築の基点に採用した。
4. `feature/ogp-support`のファイル一式（`.git`除く）を新しい`soccer-sim`ディレクトリへ
   コピーし、`npm install`・`npm test`・`npm run lint`・`npm run typecheck`・
   `npm run build`で健全性を確認したうえで`git init`し、単一のroot-commitとして記録した。
   （過去の詳細なコミット履歴は失われたが、コード自体はこの時点のmain相当の内容を
   復元できた）
5. 本機能（自由配置モードFR-15）の実装内容は、このセッションの会話履歴に全ファイルの
   最終content・全編集内容が残っていたため、それを基に再現した。再現後、
   `npm test`・`npm run lint`・`npm run typecheck`・`npm run build`の結果が
   インシデント前と完全に一致すること（ビルド成果物のファイルハッシュまで一致）を
   確認し、再現の正確性を検証した。

### 再発防止（メモリへ記録済み）

- `feedback_git-worktree-destructive-sequencing.md`: mainへのマージ直後に破壊的コマンドを
  `&&`で連投しない、という具体的な回避策
- `project_20260918-main-branch-data-loss-incident.md`: 本インシデントの経緯と、
  当面の間git履歴が失われている旨の申し送り
