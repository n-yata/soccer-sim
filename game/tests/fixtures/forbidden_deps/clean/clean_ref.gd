# 禁止依存の検査の自己確認用（誤検出しないこと）。
# コメントと文字列の中の get_tree() / FileAccess / Time. / randi() は検出しない
extends RefCounted


func describe() -> String:
	return "Node を get_tree() で探し、Time.get_ticks_msec() と randi() を使う、と書いた文字列"
