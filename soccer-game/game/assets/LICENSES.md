# ライセンス台帳

アプリに同梱する外部の素材とアドオンの、調達元・バージョン・ライセンスの記録（`architecture-overview.md`「依存関係管理」）。
外部のものを足す・更新するときは、ファイルを置く同じコミットでこの台帳を更新する。

## フォント

| 書体 | 置き場所 | 調達元 | バージョン | ライセンス | 著作権表示 | 予約フォント名（RFN） |
|---|---|---|---|---|---|---|
| Noto Sans JP（Regular・Bold） | `fonts/noto-sans-jp/`（サブセット。woff2） | notofonts/noto-cjk のリリース `Sans2.004` の `16_NotoSansJP.zip` | 2.004 | SIL OFL 1.1（同じ zip の `LICENSE`） | © 2014-2021 Adobe (http://www.adobe.com/). | なし |
| Barlow Condensed（SemiBold・Bold） | `fonts/barlow-condensed/` | jpt/barlow のタグ `1.422`（コミット `697600fc`）の `fonts/ttf/` | 1.422 | SIL OFL 1.1（`fonts/barlow-condensed/OFL.txt`） | Copyright 2017 The Barlow Project Authors (https://github.com/jpt/barlow) | なし |

- RFN は、OFL の本文とフォントの name テーブル（著作権表示・ライセンスの記述）に「with Reserved Font Name」が無いことで確かめた（2026-10-18）。
  サブセットにしても、OFL 上は名前を変える必要はない。
- Noto Sans JP の配布元の `LICENSE`（OFL の本文）は、著作権表示の行を含まない。著作権表示はフォントの name テーブルにある。
  置くときは `OFL.txt` の先頭に上の表の著作権表示を足し、アプリ内のライセンスの表示にも両方を載せる。
- Noto Sans JP の name テーブルには「Noto is a trademark of Google Inc.」という商標の表示がある。これは OFL の RFN とは別で、
  サブセットでも名前は変えない（2026-11-26。RFN が無いので OFL 上の義務は無く、商標の表示を含む name テーブルをそのまま残して
  出所を示す。Google Fonts 自身も同じ名前のままサブセットを配っている）。
- Noto Sans JP は、元のファイル（2つの太さで約9.2MB）を Git の履歴に残さないため、サブセットだけを置く（2026-10-18 シャビ決定）。
  RFN の有無は、元のファイル（2.004）の OFL の本文と name テーブルで確かめた結果。Barlow Condensed は小さいので元のファイルを置いている。
- Noto Sans JP のサブセットは `tools/subset_noto_sans_jp.py` で作る（2026-11-26。ブラウザ版で端末のフォントが使えないため、この時に置いた）。
  手を加えたこと: 文言の文字と英数記号・かなに絞り、ヒントを除き、woff2 にした。name テーブル（著作権表示・ライセンスの記述）は残す。
  `OFL.txt` は配布元の `LICENSE` の先頭に、上の表の著作権表示を足したもの（Barlow の `OFL.txt` に揃えて「©」を「Copyright」と書いた）。

## 効果音

置き場所はすべて `sounds/`。どれも CC0 1.0（パブリックドメイン。表示の義務は無いが、作者名をここに残す）。

| ファイル | 元のファイル | 調達元 | バージョン | 作者 | 手を加えたこと |
|---|---|---|---|---|---|
| `click.ogg` | `Audio/click_001.ogg` | OpenGameArt の「Interface Sounds」（`kenney_interfaceSounds.zip`。同梱の `License.txt` が CC0） | 1.0（2020-02-11） | Kenney（www.kenney.nl） | なし |
| `goal_for.ogg` | `OGG/jingles_SAX/jingles_SAX02.ogg` | OpenGameArt の「85 Short music jingles」（`jingleSounds_Kenney.zip`。同梱の `license.txt` が CC0） | 版の表記なし（2026-10-30 に取得） | Kenney（www.kenney.nl） | なし |
| `goal_against.ogg` | `OGG/jingles_SAX/jingles_SAX01.ogg` | 同上 | 同上 | 同上 | なし |
| `whistle.ogg` | `218318 splicesound referee-whistle-blow-gymnasium.wav` | Wikimedia Commons（元は freesound の 218318。Commons のライセンス欄が CC0） | 2026-10-30 に取得 | SpliceSound | 先頭 1.5 秒に切り、最後の 0.4 秒をフェードアウト、モノラルの Ogg Vorbis にした |

- 調達元のページ（2026-10-30 に確認）: Kenney の2つは OpenGameArt の各ページのライセンス欄と zip の中のライセンスの文、
  笛は Wikimedia Commons のファイルのページ（`File:218318 splicesound referee-whistle-blow-gymnasium.wav`）のライセンス欄。
- 差し替えるときは、同じファイル名で置き換えてこの表を直す（どの場面で鳴らすかは `SoundCues` が持つ）。

## 3Dモデル・動き

なし。得点・ボールを奪った・シュートを止めたときの3Dのカットインに使っていた素材（Quaternius の CC0 の体・動き、CMU の
モーションキャプチャの蹴る動き。置き場所は `models/goal_cut_in/`）は、カットインと一緒に 2026-11-27 に外した
（Android で動かなかったため。シャビ判断）。調達元・加工の記録は、Git の履歴のこの節（2026-11-26 までの版）にある。

## アドオン

| アドオン | 置き場所 | 調達元 | バージョン | ライセンス | 書き出しへの同梱 |
|---|---|---|---|---|---|
| gdUnit4 | `../addons/gdUnit4/` | godot-gdunit-labs/gdUnit4 のタグ `v6.2.2` のアーカイブの `addons/gdUnit4/` | 6.2.2 | MIT（`../addons/gdUnit4/LICENSE`） | しない（書き出し設定で除外。テスト用） |
