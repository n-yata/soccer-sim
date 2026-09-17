# 設計書

## アーキテクチャ概要

ロジック・状態管理・ルーティングには一切手を入れず、**見た目（CSS・SVG風の装飾要素）のみ**を
変更する。デザイントークン（色・角丸・影）を1箇所に集約し、各コンポーネントの scoped style から
CSS変数として参照する構成にする（現状トークン管理場所が無く、色コードがコンポーネントごとに
直書きされているため、今回の刷新を機に一元化する）。

```
src/
  styles/
    tokens.css        ← 新規。デザイントークンを :root の CSS変数として定義
  main.ts              ← tokens.css を import
  App.vue
  components/
    FormationCard.vue  ← カードスタイル刷新
    MatchupPitchDiagram.vue ← ピッチ・選手アイコン刷新
  pages/
    FormationListPage.vue   ← ヘッダー・グリッド・フッター刷新
    ComparisonPage.vue      ← 戻るボタン・凡例・総合判定・優位ポイント刷新
```

## デザイントークン（`src/styles/tokens.css`）

wireframes.drawio の刷新後ページで使用した配色をそのまま採用する。

| 変数名 | 値 | 用途 |
|---|---|---|
| `--color-primary` | `#16A34A` | ヘッダーグラデーション開始色 |
| `--color-primary-end` | `#0D9488` | ヘッダーグラデーション終了色 |
| `--color-accent` | `#FF6B35` | 選択中カードの強調色 |
| `--color-accent-bg` | `#FFF4EC` | 選択中カードの背景 |
| `--color-team-a` | `#2563EB` | フォーメームA（青） |
| `--color-team-a-bg` | `#EFF6FF` | チームA系の淡背景 |
| `--color-team-b` | `#EF4444` | フォーメーションB（赤） |
| `--color-team-b-bg` | `#FEF2F2` | チームB系の淡背景 |
| `--color-pitch` | `#3CB043` | ピッチ地の明色 |
| `--color-pitch-dark` | `#1B5E20` | ピッチ地のグラデーション濃色 |
| `--color-text` | `#111827` | 基本テキスト |
| `--color-text-sub` | `#6B7280` | 補助テキスト |
| `--color-border` | `#E5E7EB` | カード枠線 |
| `--radius-card` | `14px` | カード角丸 |
| `--shadow-card` | `0 2px 8px rgba(0,0,0,0.08)` | カード影 |

既存の `functional-overview.md`「表示仕様」の「青/赤で区別する」という決定は維持しつつ、
実際の色コードのみ本トークンに合わせて更新する（決定内容自体は変わらないため
`functional-overview.md` は更新不要）。

## コンポーネント設計

### 1. `FormationCard.vue`

**責務**: フォーメーション名を表示するカード。選択状態を見た目で表現する（ロジックは既存のまま）。

**実装の要点**:
- 通常時: 白背景・`--color-border` の細枠・`--shadow-card`・`--radius-card`
- 選択中（`.selected`）: `--color-accent` の太枠・`--color-accent-bg` 背景・チェックマーク（`::before` 等の疑似要素、または既存テキストの前に付与）
- props/emit は変更しない

### 2. `FormationListPage.vue`

**責務**: ヘッダー・カードグリッド・フッターのレイアウトとスタイル。

**実装の要点**:
- ヘッダー領域を新設し、グラデーション背景＋タイトル（⚽アイコン）＋サブタイトルを配置
- グリッドの余白・カード間隔をワイヤーフレームに合わせて調整
- フッター注記をピル型バッジ化
- `toggleSelection` / `navigateToComparison` 等の既存ロジックは無変更

### 3. `MatchupPitchDiagram.vue`

**責務**: 2フォーメームの選手配置をピッチ図として描画する（座標計算ロジックは既存のまま）。

**実装の要点**:
- ピッチ背景: 芝生ストライプ（縦帯の明暗を交互に）＋グラデーション＋白線（外枠・センターライン・
  センターサークル・ペナルティエリア）を SVG または CSS で追加
- 選手円: 枠線を太く・白フチ・影付きにし、配色を `--color-team-a` / `--color-team-b` に更新
- 選手の座標計算ロジック（GK-DF-MF-FWの深さ配置等）には一切手を入れない

### 4. `ComparisonPage.vue`

**責務**: 戻るボタン・タイトル・凡例・総合判定・優位ポイントのレイアウトとスタイル。

**実装の要点**:
- 戻るボタンをピル型・影付きに
- 凡例をカラーチップ（ピル型バッジ）に変更
- 総合判定エリア（`overallEdge` に応じた既存の `A`/`B`/`even` クラス分岐は維持）をチームカラーの
  グラデーションカードに変更し、絵文字（🏆 等）を追加
- 優位ポイントのカードをチームカラー枠線付きカードに変更
- `verdictHeadline` などの算出ロジックは無変更

## データフロー

変更なし（既存の `computed` / `getFormationById` / `getMatchup` のロジックに手を入れない）。

## テスト戦略

### 既存テストへの影響確認
- `FormationCard.test.ts` / `FormationListPage.test.ts` は DOM 構造・class・テキストを見ている
  可能性があるため、スタイル変更に伴い構造（要素追加等）が変わる場合はテストの期待値を確認し、
  壊れていれば「表示内容は変わらないことの検証」として最小限の追随修正を行う（新規のテスト
  ケース追加は不要。スタイルはテスト対象外）。

### 手動確認
- `npm run dev` で実際に一覧画面・比較画面を表示し、ワイヤーフレーム（v2ページ）のトンマナと
  比較する。

## 依存ライブラリ

追加なし。

## 実装の順序

1. `src/styles/tokens.css` 新規作成 + `main.ts` へ import 追加
2. `FormationCard.vue` のスタイル刷新
3. `FormationListPage.vue` のスタイル刷新（ヘッダー・フッター追加）
4. `MatchupPitchDiagram.vue` のピッチ・選手アイコン刷新
5. `ComparisonPage.vue` のスタイル刷新
6. 既存テスト実行・型チェック・リント・ビルド確認
7. `npm run dev` での目視確認

## セキュリティ考慮事項

なし（静的スタイル変更のみ、ユーザー入力を扱わない）。

## パフォーマンス考慮事項

なし（CSS/SVG装飾の追加程度で、描画コストへの影響は軽微）。

## 将来の拡張性

デザイントークンを CSS変数に一元化したことで、将来的なテーマ変更（ダークモード等）や
配色調整が `tokens.css` の変更のみで完結するようになる。
