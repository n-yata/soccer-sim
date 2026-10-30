## 効果音（オートロード名 Sfx。オートロード名と衝突しないよう class_name は別の名前）。音はすべて SE バスで鳴らすので、
## 設定の効果音音量（AudioBuses）がそのまま効く。素材の調達元・ライセンスは game/assets/LICENSES.md「効果音」。
## ボタンのクリック音は、木に入った BaseButton の pressed に自分でつなぐ（画面ごとに足さない）。
## Sfx より先に木に入ったボタンはつながらない（今は App がボタンを作らず、メインシーンはオートロードの後に読まれる）。
## オートロードの順序を変える・App が UI を持つときは、それまでに木にあるボタンもつなぐこと。
## 試合の得点・笛は MatchScreen が play で鳴らす。
class_name SoundCues
extends Node

enum Cue { CLICK, GOAL_FOR, GOAL_AGAINST, WHISTLE }

## 音 → ファイル。差し替えるときは同じ名前で置き換え、台帳を直す
const STREAM_PATHS: Dictionary = {
	Cue.CLICK: "res://assets/sounds/click.ogg",
	Cue.GOAL_FOR: "res://assets/sounds/goal_for.ogg",
	Cue.GOAL_AGAINST: "res://assets/sounds/goal_against.ogg",
	Cue.WHISTLE: "res://assets/sounds/whistle.ogg",
}

## 鳴らした音（テストが場面ごとの音を確かめる）
signal cue_played(cue: Cue)

var _players: Dictionary = {}


func _ready() -> void:
	# 値を添字に使わず、名前から値を引く（enum に値を明示しても名前とずれない）
	for key: String in Cue.keys():
		var cue: int = Cue[key]
		var player := AudioStreamPlayer.new()
		player.name = key
		player.stream = load(STREAM_PATHS[cue] as String) as AudioStream
		player.bus = AudioBuses.SE_BUS
		add_child(player)
		_players[cue] = player
	get_tree().node_added.connect(_on_node_added)


## 鳴らす。同じ音が鳴っている途中なら頭から鳴らし直す。
func play(cue: Cue) -> void:
	(_players[cue] as AudioStreamPlayer).play()
	cue_played.emit(cue)


## 音を鳴らすプレーヤー（テストが、読み込んだファイルとバスを確かめる）。
func player_for(cue: Cue) -> AudioStreamPlayer:
	return _players[cue] as AudioStreamPlayer


func _on_node_added(node: Node) -> void:
	var button: BaseButton = node as BaseButton
	# 木から外して入れ直したボタン（カードの並べ替えなど）は、すでにつないである
	if button != null and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	play(Cue.CLICK)
