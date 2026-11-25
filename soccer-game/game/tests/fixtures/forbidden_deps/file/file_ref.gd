# 禁止依存の検査の自己確認用（ファイル）。ルールや書き方を足したら、ここにも「# expect」付きで足す
extends RefCounted


func read_text() -> String:
	return FileAccess.get_file_as_string("res://content/formations.json")  # expect


func load_resource() -> Resource:
	return load("res://content/formations.json")  # expect


func load_image() -> Image:
	return Image.load_from_file("res://x.png")  # expect


func load_into_image() -> Error:
	return Image.new().load("res://x.png")  # expect
