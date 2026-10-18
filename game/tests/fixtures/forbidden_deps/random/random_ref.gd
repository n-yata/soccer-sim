# 禁止依存の検査の自己確認用（グローバルな乱数・ドメイン内での乱数生成器の作成）。
# ルールや書き方を足したら、ここにも「# expect」付きで足す
extends RefCounted


func roll() -> int:
	var values: Array[int] = [1, 2, 3]
	values.shuffle()  # expect
	var picked: int = values.pick_random()  # expect
	var generator := RandomNumberGenerator.new()  # expect
	randomize()  # expect
	var from_seed: int = rand_from_seed(1).size()  # expect
	return randi() + generator.randi() + picked + from_seed  # expect
