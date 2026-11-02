extends GdUnitTestSuite


func test_read_text_of_known_path_returns_content() -> void:
	var source := MemoryDataSource.new({"units.json": "{\"schema_version\": 1}"})

	var text := source.read_text("units.json")

	assert_str(text).is_equal("{\"schema_version\": 1}")
	assert_int(source.last_error).is_equal(OK)


func test_read_bytes_of_missing_path_is_empty_with_not_found() -> void:
	var source := MemoryDataSource.new({"units.json": "{}"})

	var bytes := source.read_bytes("ai.json")

	assert_int(bytes.size()).is_equal(0)
	assert_int(source.last_error).is_equal(ERR_FILE_NOT_FOUND)


func test_read_bytes_keeps_exact_bytes_including_crlf() -> void:
	var raw := PackedByteArray([0x7B, 0x0D, 0x0A, 0x7D])
	var source := MemoryDataSource.new({"hud.json": raw})

	assert_array(source.read_bytes("hud.json")).is_equal(raw)


func test_list_returns_direct_children_sorted() -> void:
	var source := MemoryDataSource.new({
		"units.json": "{}", "ai.json": "{}", "cartes/plaine.json": "{}", "cartes/delta.json": "{}",
	})

	assert_array(source.list("")).is_equal(PackedStringArray(["ai.json", "units.json"]))
	assert_array(source.list("cartes")).is_equal(PackedStringArray(["delta.json", "plaine.json"]))
