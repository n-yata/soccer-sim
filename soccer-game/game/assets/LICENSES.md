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

カットイン（`GoalPlayerModel`）の選手とゴールキーパーに使う。置き場所はすべて `models/goal_cut_in/`。
2026-11-10 から、体は**骨だけ**を使う（見た目は骨に付けた人形の部品で、素材の体の形・テクスチャは描かない）。
テクスチャは体の gltf が参照しているので置いたままにしている。
Quaternius の素材はどれも CC0 1.0（パブリックドメイン。表示の義務は無いが、作者名をここに残す）。

| ファイル | 元のファイル | 調達元 | バージョン | 作者 | 手を加えたこと |
|---|---|---|---|---|---|
| `Superhero_Male_FullBody.gltf`・`.bin`、`T_Superhero_Male_*.png`、`T_Eye_*.png` | `Base Characters/Godot - UE/Superhero_Male_FullBody.gltf` と同じフォルダのテクスチャ | itch.io の「Universal Base Characters」の Standard（`quaternius.itch.io/universal-base-characters`。同梱の `License_Standard.txt` が CC0。`License.txt` として置いた） | Standard（2026-11-07 に取得） | Quaternius | テクスチャを縮めた（2048px の肌・法線を 1024px、粗さを 512px。目の 256px は元のまま）。gltf の画像の参照を縮めたファイル名に直した |
| `T_Hair_1_*.png` | `Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/` のテクスチャ | 同上 | 同上 | Quaternius | テクスチャを 2048px から 1024px に縮めた。髪の形（`Hair_SimpleParted.gltf`・`.bin`）は 2026-11-10 に外した（体の gltf がテクスチャを参照するので、テクスチャだけ残る） |
| `animations.res`（Sprint・Idle・Roll） | `Unreal Engine/AL_Standard.fbx` | OpenGameArt の「Universal Animation Library」（`universal_animation_librarystandard.zip`。同梱の `License.txt` が CC0） | Standard（2026-11-07 に取得） | Quaternius | 使う動きだけを抜き出した。位置を cm から m に直し、体全体を動かす root の記録を外した |
| `animations.res`（Yes・Slide_Start・Slide_Exit） | `Unreal-Godot/UAL2_Standard.glb` | OpenGameArt の「Universal Animation Library 2」（`universal_animation_library_2standard.zip`。同梱の `License.txt` が CC0） | Standard（2026-11-07 に取得） | Quaternius | 使う動きだけを抜き出し、体全体を動かす root の記録を外した（Slide_Start・Slide_Exit は 2026-11-08 に足した。ボールを奪うスライディング） |
| `kick_motion.json` | `data/011/11_01.bvh`（soccer - kick ball） | CMU Graphics Lab Motion Capture Database の BVH 版（GitHub の meshula/cmu-mocap。同梱の `READMEFIRST.txt` の「USAGE RIGHTS」） | 2010 年の BVH 版（2026-11-07 に取得） | CMU Graphics Lab（BVH への変換は Bruce Hahne） | 下の「蹴る動きの抜き出し」 |

- CMU の動きの記録は、研究にも商用の製品にも使え、製品に含めてよい。ただし**データそのものを（変換した形でも）単体で
  売ってはならない**（mocap.cs.cmu.edu の利用条件「You may include this data in commercially-sold products, but you may not
  resell this data directly, even in converted form.」。2026-11-07 に確認）。`kick_motion.json` はゲームの中の演出として
  同梱するだけで、単体で配らない。BVH への変換者（Bruce Hahne）は制限を足していない（`READMEFIRST.txt`）。CMU が求める謝辞を残す: The data used in this project was obtained from mocap.cs.cmu.edu.
  The database was created with funding from NSF EIA-0196217.
- **蹴る動きの抜き出し**（作り直すときの手順）: 被験者 10・11 の「kick soccer ball」7本から、右足のつま先が最も速く
  振り抜きが大きい 11_01 を選んだ。BVH を順に計算して関節の位置を求め、蹴る向き（つま先が最も速い時刻の前後3フレームの
  水平の動き）を前、上を y とする体の空間（前 +z・左 +x）に直した。インパクト（最も速い時刻の手前 12 フレームのうち、
  つま先が最も低い時刻）の 0.5 秒前から 0.8 秒後までを 60 fps で取り、各時刻で次を記録した（前後1フレームの平均でならした）:
  - 手足・胴の向き（長さ 1）。キーと区間は `GoalCutInArt.KICK_KEYS` と同じ（胴は Hips → Neck、腿・すね・足は
    UpLeg → Leg → Foot → ToeBase、腕は Arm → ForeArm → Hand）
  - 腰と胸のひねり（左右の腿の付け根・肩を結ぶ線の、上から見た回り。胸は腰との差）、首の倒れ（Neck → Head と胴の向きの差）
  - 腰の水平の位置（インパクトからの差）。脚の長さ（腿 + すね）を素材の体（0.885 m）に合わせて縮めた
- 縮めたテクスチャ・抜き出した動きの元のファイルはリポジトリに置かない（合わせて約 200MB）。

## アドオン

| アドオン | 置き場所 | 調達元 | バージョン | ライセンス | 書き出しへの同梱 |
|---|---|---|---|---|---|
| gdUnit4 | `../addons/gdUnit4/` | godot-gdunit-labs/gdUnit4 のタグ `v6.2.2` のアーカイブの `addons/gdUnit4/` | 6.2.2 | MIT（`../addons/gdUnit4/LICENSE`） | しない（書き出し設定で除外。テスト用） |
