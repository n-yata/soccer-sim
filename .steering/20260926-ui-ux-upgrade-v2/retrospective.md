# 実装後の振り返り

## 作業概要

UI/UXアップグレード第2弾。前回（`feature/ui-ux-upgrade`, 2026-09-26マージ済み）の申し送り
（375px/768px幅での実機目視確認が未実施のまま持ち越し）を踏まえ、モバイル/レスポンシブ対応の
強化（タップ領域44px化、`@media`クエリ追加）、アニメーション・インタラクションの磨き込み
（`transition`/`animation`追加、`prefers-reduced-motion`対応、RadarChartのrequestAnimationFrame
座標補間）、アクセシビリティのさらなる改善を行った。

## 実装完了日

2026-09-26

## 対象リポジトリ・コミット

- 対象リポジトリ: 本リポジトリ
- ブランチ: feature/ui-ux-upgrade-v2

## コミット前レビュー（review-pre-commit）の結果

- 実施日: 2026-09-26
- 結果（第1回）: Critical 0件 / High 1件 / Medium 6件 / Low 7件
- 結果（第2回・修正後の再レビュー）: 新たなCritical 0件 / 新たなHigh 0件 / 新規Low 7件
- Critical / High への対応: Highは1件（`ComparisonPage.vue`・`HalftimeTacticsModal.vue`で、
  `prefers-reduced-motion`の打ち消しがCSS記述順により後勝ちで無効化されていた）。両ファイルで
  reduceブロックを`<style>`末尾へ移動し`transform: none`を追記して解消。Medium 6件（RadarChartの
  ドラッグ追従負け・補間ロジックの未テスト・Safari非対応の`r`プロパティ・モーダルleave中の
  背面クリック吸収・`FormationListPage`のreduce漏れ・ドキュメント未反映）はすべて同一コミット内で
  対応済み。第2回で指摘された新規Low 7件のうち2件（`QuizPage`のtransform無効化漏れ、テストの
  スタブ後始末の堅牢化）はその場で対応し、残り5件は実害が極めて小さいため積み残しとした。
- レポート全文: [review-report.md](./review-report.md)

## 計画と実績の差分

**計画と異なった点**:
- design.md策定時点では想定していなかった「RadarChartのスコア変化アニメーション」を、
  requirements.mdの受け入れ条件に基づいて実装した。SVGの`<polygon>`の`points`属性はCSS
  transitionの対象外と判明したため、`requestAnimationFrame`によるJS側の座標補間で代替した。
- レビューで「自由配置モードのドラッグ中は毎pointermoveで補間がリセットされ追従負けする」
  という問題が発覚し、直前の変化から120ms未満の連続変化は補間せず即座に反映する
  ロジック（`RAPID_CHANGE_THRESHOLD_MS`）を追加した。計画段階では想定していなかった。
- `FreeLayoutPitchDiagram.vue`のホバー拡大表現で、当初CSSの`r`プロパティ（SVG2の
  ジオメトリプロパティ）を使ったが、レビューでSafari/iOS非対応と指摘され
  `transform: scale()` + `transform-box: fill-box`方式に変更した。

**新たに必要になったタスク**:
- `RadarChart.test.ts`への補間ロジック検証テスト6件の追加（レビュー対応。当初のtasklistには
  「既存テストが通ることを確認する」のみで、新規テスト追加は含まれていなかった）
- `docs/specs/2_basic-design/component-design.md`のRadarChart責務への補間仕様の追記
  （レビュー対応）

**技術的理由でスキップしたタスク**: なし（全タスク完了）

## 学んだこと

**技術的な学び**:
- SVGの`<polygon>`の`points`属性、`<circle>`の`r`/`cx`/`cy`属性はCSS transitionの対象外
  （前者は仕様上非対応、後者はSVG2のジオメトリプロパティとしてCSS化されているが
  Safari/iOSが未対応）。座標変化を滑らかにするにはJS側の補間（`requestAnimationFrame`）か、
  `transform`（`transform-box: fill-box`と組み合わせる）で代替する必要がある。
- `prefers-reduced-motion`の打ち消しブロックは、CSSカスケードの「同一詳細度なら後に書かれた
  ルールが勝つ」規則の影響を受ける。`<style>`の途中に書くと、それより後ろに追加した
  `transition`/`transform`宣言によって静かに無効化される。**必ず`<style>`の末尾に置く**か、
  追加のたびに位置を確認する必要がある。
- 高頻度に再計算される値（ドラッグ中のpointermoveなど）にアニメーション補間をそのまま
  適用すると、補間が常にリセットされ続けて「目標値に追いつけない」状態になる。
  連続変化を検知して補間をスキップする閾値ベースの対処が有効。

**プロセス上の改善点**:
- コミット前レビューをOpusモデルのサブエージェントで実施したところ、CSSカスケードの
  記述順に起因する非自明なHigh指摘（reduced-motionが後勝ちで無効化）を的確に検出できた。
  セキュリティ関連はopusを使う方針（CLAUDE.md）が、UI/UX変更でも高難度な指摘の検出に有効だった。
- 第1回レビュー後の修正を「Highだけ直して終える」のではなく、Medium・一部Lowまで同一コミットで
  対応したことで、第2回の再レビューが「新たな指摘なし」でスムーズに収束した。

## 次回への改善提案

- `prefers-reduced-motion`ブロックを追加する際は、実装のたびに「対象セレクタの`transition`/
  `transform`宣言より後ろにあるか」を機械的にチェックする習慣をつける（grepで行番号を
  比較する等）。今回のHigh指摘は、レビューがなければ気づかずコミットしていた可能性が高い。
- SVG要素にCSSアニメーションを追加する際は、対象プロパティ（`r`/`cx`/`cy`/`points`/`d`等）が
  ブラウザ間でCSSアニモータブルかどうかを実装前に確認する（Safari/iOSの対応状況は特に
  見落としやすい）。`transform`ベースの代替を最初から検討するとやり直しが減る。
- 今回も前回同様、375px/768pxでのブラウザ自動操作によるリサイズ（`resize_window`）が本環境では
  機能しないことを再確認した（`window.innerWidth`が変化しない）。この制約は環境固有かつ
  継続的なものと判断できるため、次回以降はCSSレビュー+`getComputedStyle`アサーションの方針を
  最初から採用してよい（`resize_window`の再確認自体を省略できる）。
