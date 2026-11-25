## MVP の対戦相手（component-design.md §3.3）。CpuPlanner（アルゴリズム8）に、注入された調整値と乱数生成器を渡す。
class_name CpuOpponent
extends OpponentPolicy

var _catalog: ContentCatalog
var _cpu: CpuConfig
var _rng: RandomNumberGenerator


## rng は App が1つだけ作ったもの（テストではシードを固定したもの）。
func _init(catalog: ContentCatalog, cpu: CpuConfig, rng: RandomNumberGenerator) -> void:
	_catalog = catalog
	_cpu = cpu
	_rng = rng


func choose_turn(state: MatchState, side: GameEnums.TeamSide) -> TurnChoice:
	return CpuPlanner.choose_turn(state, side, _cpu, _rng)


func choose_setup() -> TeamSetup:
	return CpuPlanner.choose_setup(_catalog, _rng)


func choose_styles() -> TeamStyles:
	return CpuPlanner.choose_styles(_rng)
