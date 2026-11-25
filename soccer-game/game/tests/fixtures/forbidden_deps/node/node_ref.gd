# 禁止依存の検査の自己確認用（ノード）。tools/run-tests.sh が --self-check node で、
# このカテゴリの全ルールが当たり、「# expect」の付いた行がすべて検出され、ほかのカテゴリが当たらないことを確かめる。
# ルールや書き方を足したら、ここにも「# expect」付きで足す
extends Node  # expect


func use_tree() -> void:
	var tree: SceneTree = get_tree()  # expect
	var by_path: Node = $"Path/To"  # expect
	var by_unique_name: Node = %UniqueName  # expect
	var main_loop: MainLoop = Engine.get_main_loop()  # expect
	var singleton: Object = Engine.get_singleton("Time")  # expect
	var created: Variant = ClassDB.instantiate("Timer")  # expect
	var expression := Expression.new()  # expect
	print(tree, by_path, by_unique_name, main_loop, singleton, created, expression)
