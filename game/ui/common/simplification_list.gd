## 単純化カタログの一覧（screen-common.md §5 の SimplificationList。FR-23）。チュートリアルの最後の段階と、ゲームの表現範囲（S-10）で
## 共用する。1件を1枚のカード（名前・ゲームでの扱い・実戦では）にし、2列に並べる。値は LibraryService.simplifications()。
class_name SimplificationList
extends GridContainer

const IN_GAME_PREFIX: String = "ゲームでは: "
const IN_REAL_PREFIX: String = "実戦では: "


func _init() -> void:
	name = "SimplificationList"
	columns = 2
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("h_separation", 16)
	add_theme_constant_override("v_separation", 16)


func show_items(simplifications: Array[SimplificationDef]) -> void:
	MatchScreenLayout.clear(self)
	for simplification: SimplificationDef in simplifications:
		add_child(_card(simplification))


## カードごとの文（名前・ゲームでは・実戦では）。テストと画面の確認用。
func card_texts() -> Array[Array]:
	var texts: Array[Array] = []
	for card: Node in get_children():
		if card.is_queued_for_deletion():
			continue
		var lines: Array[String] = []
		for label: Node in card.find_children("*", "Label", true, false):
			lines.append((label as Label).text)
		texts.append(lines)
	return texts


func _card(simplification: SimplificationDef) -> Control:
	var card := PanelContainer.new()
	card.name = simplification.id
	card.theme_type_variation = &"SurfaceCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 8)
	card.add_child(lines)
	MatchScreenLayout.text(lines, "Name", &"CardTitleLabel").text = simplification.name
	MatchScreenLayout.text(lines, "InGame", &"").text = IN_GAME_PREFIX + simplification.in_game
	MatchScreenLayout.text(lines, "InReal", &"MutedLabel").text = IN_REAL_PREFIX + simplification.in_real
	return card
