# 要求内容

## 概要

別リポジトリで開発していた戦術ゲーム（soccer-game。Godot 4.7.2）を、このリポジトリへ履歴ごと移して一元管理し、
ブラウザで遊べる PWA として GitHub Pages の `/soccer-sim/game/` に公開する。

## 背景

シャビの要望「このプロジェクトで soccer-game を遊べるようにしたい。PWA アプリで遊べるようにしたい」（2026-11-26）。
決定事項（同日、シャビ）:

- 公開範囲: GitHub Pages で一般公開する
- PWA の範囲: ゲーム単体を PWA にする（ラボ全体は PWA にしない）
- ソースの置き場所: soccer-game のソースをこのリポジトリへ移し、ここで管理する（CI で書き出す）

## 実装対象の機能

### 1. soccer-game の取り込み
- `git subtree add` で履歴ごと `soccer-game/` に置く（AGENTS.md・docs・ステアリングもそのまま）

### 2. ブラウザ版の書き出し
- Godot の Web 書き出し（スレッドなし版。GitHub Pages は COOP/COEP ヘッダーを付けられない）
- Godot 標準の PWA 書き出し（manifest・Service Worker・オフライン）
- 日本語フォント（Noto Sans JP のサブセット）の同梱。ブラウザには端末フォントへのフォールバックが無く、
  同梱しないと日本語が表示されない

### 3. 公開
- `main` への push で、ラボのビルドに続けて CI がゲームを書き出し、`dist/game/` として一緒にデプロイする
- 手元でも同じスクリプトで書き出し、開発サーバーで遊べる

## 受け入れ条件

### 取り込み
- [ ] soccer-game の全ファイルが `soccer-game/` にあり、履歴が辿れる
- [ ] 公開してよい内容である（秘匿情報・署名鍵・個人のパスが履歴に無い）

### ブラウザ版
- [ ] ブラウザでタイトル→試合準備→試合画面まで進め、日本語が表示される
- [ ] Service Worker が登録され、manifest が書き出される（ホーム画面に追加できる）
- [ ] 文言の全文字がフォントのサブセットにある（`tools/subset_noto_sans_jp.py --check`）
- [ ] ゲームの既存テストが通る（`tools/run-tests.sh`）

### 公開
- [ ] CI が Godot・テンプレートをハッシュで検証してから書き出す
- [ ] ラボの lint・型チェック・テスト・ビルドがゲームの取り込みで壊れない

## スコープ外

- ラボの画面からゲームへの導線（ワイヤーフレーム・画面設計の更新を伴うため、別の PR で行う）
- PWA のアイコンのデザイン（今は Godot の既定のアイコン）
- CI でのゲームのテスト実行
- Android 版の書き出し・配布の変更

## 参照ドキュメント

- `docs/specs/1_requirements/architecture-overview.md` - デプロイ・公開先
- `docs/specs/1_requirements/repository-structure.md` - ディレクトリ構造・CI
- `soccer-game/docs/specs/1_requirements/architecture-overview.md` - ゲームの技術スタック・フォントの方針
