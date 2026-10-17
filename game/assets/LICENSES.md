# ライセンス台帳

アプリに同梱する外部の素材とアドオンの、調達元・バージョン・ライセンスの記録（`architecture-overview.md`「依存関係管理」）。
外部のものを足す・更新するときは、ファイルを置く同じコミットでこの台帳を更新する。

## フォント

| 書体 | 置き場所 | 調達元 | バージョン | ライセンス | 著作権表示 | 予約フォント名（RFN） |
|---|---|---|---|---|---|---|
| Noto Sans JP（Regular・Bold） | **未配置**（サブセットの作業で `fonts/noto-sans-jp/` に置く） | notofonts/noto-cjk のリリース `Sans2.004` の `16_NotoSansJP.zip` | 2.004 | SIL OFL 1.1（同じ zip の `LICENSE`） | © 2014-2021 Adobe (http://www.adobe.com/). | なし |
| Barlow Condensed（SemiBold・Bold） | `fonts/barlow-condensed/` | jpt/barlow のタグ `1.422`（コミット `697600fc`）の `fonts/ttf/` | 1.422 | SIL OFL 1.1（`fonts/barlow-condensed/OFL.txt`） | Copyright 2017 The Barlow Project Authors (https://github.com/jpt/barlow) | なし |

- RFN は、OFL の本文とフォントの name テーブル（著作権表示・ライセンスの記述）に「with Reserved Font Name」が無いことで確かめた（2026-10-18）。
  サブセットにしても、OFL 上は名前を変える必要はない。
- Noto Sans JP の配布元の `LICENSE`（OFL の本文）は、著作権表示の行を含まない。著作権表示はフォントの name テーブルにある。
  置くときは `OFL.txt` の先頭に上の表の著作権表示を足し、アプリ内のライセンスの表示にも両方を載せる。
- Noto Sans JP の name テーブルには「Noto is a trademark of Google Inc.」という商標の表示がある。これは OFL の RFN とは別で、
  サブセットの名前の扱いは、サブセットのスクリプトを作る作業で確かめる。
- Noto Sans JP は、元のファイル（2つの太さで約9.2MB）を Git の履歴に残さないため、サブセットを作る作業で初めて置く（2026-10-18 シャビ決定）。
  RFN の有無は、元のファイル（2.004）の OFL の本文と name テーブルで確かめた結果。Barlow Condensed は小さいので元のファイルを置いている。
  画面で使う文字に絞ったサブセットは、静的データの文言がそろってから作る（`architecture-overview.md` のフォントの注記）。

## アドオン

| アドオン | 置き場所 | 調達元 | バージョン | ライセンス | 書き出しへの同梱 |
|---|---|---|---|---|---|
| gdUnit4 | `../addons/gdUnit4/` | godot-gdunit-labs/gdUnit4 のタグ `v6.2.2` のアーカイブの `addons/gdUnit4/` | 6.2.2 | MIT（`../addons/gdUnit4/LICENSE`） | しない（書き出し設定で除外。テスト用） |
