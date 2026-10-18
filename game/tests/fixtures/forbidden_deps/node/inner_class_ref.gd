# 禁止依存の検査の自己確認用（ノード: 内部クラスの extends）。行頭以外の extends も検出することを確かめる
extends RefCounted


class InnerTimer extends Timer:  # expect
	pass
