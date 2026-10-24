## 判定例（functional-overview.md「判定例」JE-01〜07）の場面の配置を作るテストの補助。
## 判定例の配置は、陣形の座標のエリアをそのまま使った配置（アルゴリズム1の、重なりを散らす前）。
## 2026-10-24 に基本配置で重なりを散らすようにしたが、判定例は判定の規則を示すものなので、場面は変えずに配置で示す。
class_name JudgeExampleLayouts
extends RefCounted


## formation の GK を除く選手を、座標のエリアにそのまま置いた配置（固定なし。基本エリアも同じ）。
static func at_coordinates(formation: FormationDef) -> TeamLayout:
	var players: Array[PlayerState] = []
	for slot: PlayerSlotDef in formation.players:
		if not slot.is_goalkeeper():
			players.append(PlayerState.new(slot.id, BaseLayoutDeriver.area_of(slot.x, slot.y)))
	return TeamLayout.at_base(players)
