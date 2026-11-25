# 設計（20261110-chibi-cut-in）

## 部品
| 部品 | 層 | 変更 |
| --- | --- | --- |
| `GoalPlayerModel` | UI | 素材の体は骨だけを使い、描く形（skinned mesh）を消す。骨ごとに `BoneAttachment3D` を置き、基準の姿勢の骨の間に部品（球の頭・カプセルの胴・手足・スパイク）を付ける。顔（目と光・眉・口・ほっぺ）は輪郭なし・陰なしの小さな楕円。材質は2階調（`DIFFUSE_TOON`）＋輪郭（`next_pass` で外へ膨らませた裏面を黒く塗る）。縦じまは胴の材質の模様（2色の画像を周りに 8 回）。髪型 `HairStyle { FRINGE, SPIKY, MOHAWK }`。テスト用に `part_material(part)`・`shirt_colors()` |
| `GoalStage3D` | UI | 髪型を渡す（ボールを持つ側 FRINGE、奪いに来る選手 SPIKY、キーパー MOHAWK） |
| `GoalCutInArt.SHOTS` | UI | 蹴る瞬間のカットの画角 44→50 度、目線 +0.15m（大きな頭の上が切れたため） |
| 素材 | 素材 | `Hair_SimpleParted.gltf`・`.bin` を外す。体の gltf とテクスチャは骨のために残す |

## 外したもの
- ユニフォームのシェーダー（`KIT_SHADER`。頂点の基準の位置を UV2 に入れて塗り分ける）と `with_rest_positions`・`body_material`。
- 髪の素材（`HAIR_SCENE`）と肌・法線・粗さのテクスチャの読み込み。

## 頭身
脚・腕の長さは骨のまま（足がボールに当たる位置・キーパーの手の位置・軸足の位置合わせが今のまま正しい）。人形らしさは頭（半径 0.3m）で出す。
