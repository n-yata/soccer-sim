# 振り返り: 開発環境の構築

## 何をしたか
- `repository-structure.md`「セットアップ手順」1〜6 を実施し、実際のコマンド・設定項目名・結果を同じ節に記録した。
  - Godot 4.7.2・gdUnit4 6.2.2・JDK 17・Android SDK（build-tools 36.0.0、android-36、NDK 28.1、CMake 3.10.2）。最小 API 24・対象 API 36（`architecture-overview.md`）
  - `game/project.godot`（Compatibility、1280×720・`keep_height`・Sensor Landscape、型の警告をエラー、ETC2/ASTC）、gdUnit4 の同梱
  - `.gitignore` の Godot・gdUnit4 のレポート・署名鍵の除外を、両方向で1パスずつ確かめた。クリーンな状態からの再インポートはエラー 0 件
  - `export_presets.cfg.example` を手で書き、デバッグ版の APK を書き出した。JSON が入り、テストと gdUnit4 が入らないこと、API 35 のエミュレーターで起動することを確かめた
  - 基準端末は未定のまま持ち越した（`non-functional-requirements.md` §2）
- 持ち越していた3つの確認をした。
  - クラス名の衝突: 0 件（124個を、組み込みクラス・Variant の型名・シングルトン・gdUnit4 のクラス名の 1,294 個と突き合わせた）。`component-design.md` §6
  - フォント: Noto Sans JP 2.004・Barlow Condensed 1.422 とも RFN なし。台帳 `game/assets/LICENSES.md` を作った
  - INTERNET 権限: デバッグ版・リリース版（デバッグ用の鍵で署名）とも `uses-permission` が 0 件。NFR-10 の確かめ方とあわせて記録した

## コミット前レビュー（review-pre-commit）の結果
- 第1回: Critical 0 / High 0 / Medium 1 / Low 4。
  - Medium（Noto Sans JP の元のファイル約9.2MB が履歴に残る）は、シャビの判断でファイルを置かないことにした。
  - Low は、文書の食い違い2件を直し、2件を申し送った。
- 全文: [review-report.md](./review-report.md)

## 申し送り
- Noto Sans JP は、サブセットを作る作業で置く。そのとき `OFL.txt` に著作権表示を足し、商標の表示（Noto）と名前の扱いを確かめる。
- 最初の機能の作業で次をする。
  - メインシーンを作る。
  - 書き出した APK を起動するスモーク確認を、手順か CI に入れる（書き出しで外した gdUnit4 のクラスを、本番のコードが誤って参照していないかを見るため）。
- 3D 演出の作業と基準端末で、3D 用のシェーダーが GPU の uniform の上限に収まるかを確かめる（`architecture-overview.md` の Compatibility レンダラーの行）。
- アイコン（書き出しのとき「No project icon specified」と出る）は、公開の準備で作る。
- エミュレーター（Pixel_Fold_API_35）に確認用のアプリ `com.example.soccergame` が残っている。

## 学び
- **「入っている」は中身まで見て判断する**: 書き出しのテンプレートは、ディレクトリがあったので導入済みと記録した。しかし、入っていたのは Windows 用だけだった。計画を立てる段階の調べでは、目的の作業に要るファイル（Android 用の `.apk`）があることまで確かめる。
- **テストが0件の確認は、成功を何も示さない**: gdUnit4 は、テストが0件だと終了コード 0 で終わるが、レポートを出さない。ランナーが動くことは、成功と失敗の両方を一時的なテストで起こして確かめた。突き合わせの使い捨てスクリプトも、わざと衝突する名前で検出されることを確かめてから結果を信じた。
- **エミュレーターの描画は、既定のままでは実機の代わりにならない**: ソフトウェア描画では 3D のシェーダーが失敗し、文字も消えた。表示を確かめるときはホストの GPU を使う。同時に、失敗の内容（uniform の上限）は、性能の低い実機で同じことが起きうる兆候として記録した。
- **一度コミットすると消せないものは、レビューの段階で止める**: 大きなバイナリは、後で差し替えても履歴に残る。サブセットにする予定のものは、最終形になってから追跡する。
