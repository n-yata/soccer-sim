## NotesView（screen-common.md §5。解説の欄）のテスト。続く同じ見出しを1つにまとめ、見出しと本文を並べる。
extends GdUnitTestSuite


func _note(label: String, text: String) -> MatchupNote:
	return MatchupNote.new(text, ["TP-10"] as Array[String], [] as Array[String], label)


func _view() -> NotesView:
	var view := NotesView.new()
	add_child(view)
	auto_free(view)
	return view


func test_consecutive_notes_with_the_same_label_share_one_heading() -> void:
	var view: NotesView = _view()
	view.show_notes([_note("陣形 4-4-2", "特徴: a"), _note("陣形 4-4-2", "強み: b"), _note("守備方式 ゾーン", "特徴: c")]
			as Array[MatchupNote])
	assert_array(view.headings()).is_equal(["陣形 4-4-2", "守備方式 ゾーン"])
	assert_array(view.texts()).is_equal(["・特徴: a", "・強み: b", "・特徴: c"])


func test_the_same_label_after_another_label_gets_a_new_heading() -> void:
	var view: NotesView = _view()
	view.show_notes([_note("A", "1"), _note("B", "2"), _note("A", "3")] as Array[MatchupNote])
	assert_array(view.headings()).is_equal(["A", "B", "A"])


func test_notes_without_label_have_no_heading() -> void:
	var view: NotesView = _view()
	view.show_notes([_note("", "1")] as Array[MatchupNote])
	assert_array(view.headings()).is_empty()
	assert_array(view.texts()).is_equal(["・1"])


func test_show_notes_replaces_what_was_shown() -> void:
	var view: NotesView = _view()
	view.show_message("案内")
	view.show_notes([_note("A", "1")] as Array[MatchupNote])
	assert_array(view.texts()).is_equal(["・1"])
	view.show_notes([] as Array[MatchupNote])
	assert_array(view.texts()).is_empty()
	assert_array(view.headings()).is_empty()


func test_show_message_shows_one_line_without_heading() -> void:
	var view: NotesView = _view()
	view.show_notes([_note("A", "1")] as Array[MatchupNote])
	view.show_message("陣形と方式を選ぶと、ここに解説が出ます")
	assert_array(view.headings()).is_empty()
	assert_array(view.texts()).is_equal(["陣形と方式を選ぶと、ここに解説が出ます"])


func test_body_labels_wrap() -> void:
	var view: NotesView = _view()
	view.show_notes([_note("A", "長い文")] as Array[MatchupNote])
	var bodies: Array[Node] = view.find_children("*", "Label", false, false)
	assert_int((bodies[bodies.size() - 1] as Label).autowrap_mode).is_equal(TextServer.AUTOWRAP_WORD_SMART)
