# 設計書

## アーキテクチャ概要

```
soccer-sim（このリポジトリ）
├── src/ …… フォーメーションラボ（Vue）→ vite build → dist/
└── soccer-game/game/ …… Godot プロジェクト → Web 書き出し → dist/game/
                                    ↓
            GitHub Pages: /soccer-sim/（ラボ） /soccer-sim/game/（ゲーム・PWA）
```

ゲームの PWA はスコープ `/soccer-sim/game/` の Service Worker を持ち、ラボには影響しない。

## コンポーネント設計

### 1. Web の書き出し設定（`soccer-game/game/export_presets.cfg.example` の preset.1「Web」）
- スレッドなし（`variant/thread_support=false`）: GitHub Pages は COOP/COEP を付けられないため
- PWA 有効、表示は fullscreen・横向き、背景色はテーマの bg
- 本物の `export_presets.cfg` は Android の署名パスワードを持つため gitignore のまま。CI は example を写して使う

### 2. 書き出しスクリプト（`soccer-game/tools/export-web.sh <出力先>`）
- `export_presets.cfg` が無ければ example を写す。あっても Web プリセットが無ければ、足し方を示して失敗する
- 取り込み（`--import`）→ `--export-release "Web"`
- Godot は `GODOT_BIN`、無ければ PATH の `godot`（`run-tests.sh` と同じ）

### 3. 日本語フォント（`soccer-game/tools/subset_noto_sans_jp.py`・`game/assets/fonts/noto-sans-jp/`）
- 文言を持つファイル（`.gd` のコメントを除く・`.tscn`/`.tres` の `;` コメントを除く・`content/*.json`）の全文字＋英数記号・かな
- woff2（各約 130KB）。name テーブル（著作権表示・OFL）は残す
- テーマの `default_font` を Regular に。Barlow の見出しは FontVariation で包み、日本語を Bold で表示する

### 4. CI（`.github/workflows/deploy-pages.yml`）
- ラボのビルドの後に、Godot（linux.x86_64）とテンプレート（tpz）を公式から取得し、SHA512 を固定値で検証
- テンプレートは web_nothreads_release.zip だけを置く。どちらも actions/cache（キーは版）で再取得を避ける
- `export-web.sh dist/game`

## テスト戦略

- ゲーム: 既存の `tools/run-tests.sh`（フォント変更で文字幅に依存するテストが崩れないか）
- フォント: `subset_noto_sans_jp.py --check`
- ブラウザ: ローカル配信（サブパス `/soccer-sim/game/`）を headless Chrome で起動し、画面遷移・Service Worker 登録・コンソールのエラーを確認
- ラボ: `npm run lint` / `typecheck` / `test` / `build`

## ディレクトリ構造

```
soccer-game/                      # 取り込んだゲーム（独自の AGENTS.md・docs・.steering を持つ）
  game/assets/fonts/noto-sans-jp/ # 新規: サブセット2つ・OFL.txt
  tools/export-web.sh             # 新規
  tools/subset_noto_sans_jp.py    # 新規
public/game/                      # 手元の書き出し先（gitignore）
```

## セキュリティ考慮事項

- 公開リポジトリへ移すので、取り込む履歴に秘匿情報・署名鍵・個人のパスが無いことを確認した
- CI で取得するバイナリは SHA512 を固定値で検証する（改ざん・すり替え対策）
- `export_presets.cfg`（署名パスワード）は引き続きコミットしない

## パフォーマンス考慮事項

- wasm 約 39MB・pck 約 5MB。Pages の gzip で転送は約 10MB。初回以降は Service Worker のキャッシュから起動
