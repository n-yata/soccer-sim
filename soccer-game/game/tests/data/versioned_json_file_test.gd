## VersionedJsonFile（component-design.md §4.3「破損・新しい版のときに元のファイルを失わない」）の直接のテスト。
## 中身の形は decode を差し替えて決める（"items" が配列なら読める）。退避の細かい手順（.bak を使う・同じ秒に2回退避する・
## 退避できない）は、利用者の RecordStore のテスト（tests/data/record_store_test.gd）でも確かめる。
## gdUnit の一時ディレクトリはスイートの中でテストごとに消えないので、テストごとに別の名前を使う。
extends GdUnitTestSuite

const FILE_NAME: String = "items.json"
const VERSION: int = 1

var _decoded_roots: int = 0


func before_test() -> void:
	_decoded_roots = 0


func _path(case_name: String) -> String:
	return create_temp_dir("versioned_json_file/" + case_name).path_join(FILE_NAME)


func _file(case_name: String) -> VersionedJsonFile:
	return VersionedJsonFile.new(_path(case_name), VERSION, _decode)


func _decode(root: Variant) -> Variant:
	_decoded_roots += 1
	var items: Variant = (root as Dictionary).get("items") if typeof(root) == TYPE_DICTIONARY else null
	return items if typeof(items) == TYPE_ARRAY else null


func _put(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_a_missing_file_is_empty_and_writable() -> void:
	var file: VersionedJsonFile = _file("missing")
	assert_object(file.load()).is_null()
	assert_int(file.load_state()).is_equal(VersionedJsonFile.LoadState.EMPTY)
	assert_bool(file.can_write()).is_true()


func test_what_was_written_is_read_back_without_parsing_again() -> void:
	var file: VersionedJsonFile = _file("written")
	var items: Array = [1, 2]
	assert_bool(file.write(JSON.stringify({"format_version": VERSION, "items": items}), items)).is_true()
	assert_array(file.load() as Array).is_equal(items)
	assert_int(file.load_state()).is_equal(VersionedJsonFile.LoadState.OK)
	# 書いた文字列と同じ中身なので、decode を呼ばずに覚えている値を返す
	assert_int(_decoded_roots).is_equal(0)
	# 別のインスタンスはファイルから読む
	var other: VersionedJsonFile = _file("written")
	assert_array(other.load() as Array).is_equal([1.0, 2.0])
	assert_int(_decoded_roots).is_equal(1)


## decode が null を返す中身は破損。退避して空として扱い、書いてよい（次は新しいファイル）
func test_content_that_does_not_decode_is_moved_aside() -> void:
	var path: String = _path("undecodable")
	_put(path, JSON.stringify({"format_version": VERSION, "items": "not an array"}))
	var file: VersionedJsonFile = _file("undecodable")
	assert_object(file.load()).is_null()
	assert_int(file.load_state()).is_equal(VersionedJsonFile.LoadState.CORRUPTED)
	assert_bool(FileAccess.file_exists(path)).is_false()
	var moved: Array[String] = []
	for file_name: String in DirAccess.get_files_at(path.get_base_dir()):
		if file_name.begins_with(FILE_NAME + SaveFileIO.CORRUPT_INFIX):
			moved.append(file_name)
	assert_array(moved).has_size(1)
	assert_bool(file.can_write()).is_true()


## 今の版より新しい版は、中身を decode せずに「新しい版」とし、書かない
func test_a_newer_version_is_not_decoded_and_not_writable() -> void:
	var path: String = _path("newer")
	var newer: String = JSON.stringify({"format_version": VERSION + 1, "items": [1]})
	_put(path, newer)
	var file: VersionedJsonFile = _file("newer")
	assert_object(file.load()).is_null()
	assert_int(file.load_state()).is_equal(VersionedJsonFile.LoadState.NEWER_VERSION)
	assert_bool(file.can_write()).is_false()
	assert_int(_decoded_roots).is_equal(0)
	assert_str(FileAccess.get_file_as_string(path)).is_equal(newer)


func test_version_of_reads_only_integer_versions() -> void:
	assert_int(VersionedJsonFile.version_of({"format_version": 3.0})).is_equal(3)
	assert_int(VersionedJsonFile.version_of({"format_version": 1.5})).is_equal(-1)
	assert_int(VersionedJsonFile.version_of({"format_version": "1"})).is_equal(-1)
	assert_int(VersionedJsonFile.version_of({"format_version": 1e300})).is_equal(-1)
	assert_int(VersionedJsonFile.version_of([])).is_equal(-1)
