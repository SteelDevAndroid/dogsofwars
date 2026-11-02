extends GdUnitTestSuite

const BYTES := [1, 2, 3, 4, 5, 6]


func test_write_then_read_round_trips() -> void:
	var store := FaultInjectingFileStore.new()

	var error := store.write("user://match.tmp", PackedByteArray(BYTES))

	assert_int(error).is_equal(OK)
	assert_array(store.read("user://match.tmp")).is_equal(PackedByteArray(BYTES))
	assert_bool(store.exists("user://match.tmp")).is_true()


func test_failed_write_at_step_leaves_torn_file() -> void:
	var store := FaultInjectingFileStore.new()
	store.fail_at(1)

	var error := store.write("user://match.tmp", PackedByteArray(BYTES))

	assert_int(error).is_equal(ERR_FILE_CANT_WRITE)
	assert_array(store.read("user://match.tmp")).is_equal(PackedByteArray([1, 2, 3]))


func test_rename_onto_existing_target_is_refused() -> void:
	var store := FaultInjectingFileStore.new()
	store.write("user://match.tmp", PackedByteArray([1]))
	store.write("user://match.sav", PackedByteArray([2]))

	var error := store.rename("user://match.tmp", "user://match.sav")

	assert_int(error).is_equal(ERR_ALREADY_EXISTS)
	assert_array(store.read("user://match.sav")).is_equal(PackedByteArray([2]))


func test_rename_after_delete_replaces_target() -> void:
	var store := FaultInjectingFileStore.new()
	store.write("user://match.tmp", PackedByteArray([1]))
	store.write("user://match.sav", PackedByteArray([2]))

	store.delete("user://match.sav")
	var error := store.rename("user://match.tmp", "user://match.sav")

	assert_int(error).is_equal(OK)
	assert_array(store.paths()).is_equal(PackedStringArray(["user://match.sav"]))


func test_stop_after_step_freezes_files_for_next_launch() -> void:
	var store := FaultInjectingFileStore.new()
	store.stop_after(2)
	store.write("user://match.sav", PackedByteArray([1]))
	store.delete("user://match.bak")

	var error := store.write("user://match.tmp", PackedByteArray([2]))
	var next := store.restarted()

	assert_int(error).is_equal(ERR_UNAVAILABLE)
	assert_array(next.paths()).is_equal(PackedStringArray(["user://match.sav"]))
	assert_int(next.write("user://match.tmp", PackedByteArray([3]))).is_equal(OK)


func test_storage_full_refuses_writes_without_writing() -> void:
	var store := FaultInjectingFileStore.new()
	store.storage_full = true

	var error := store.write("user://profile.tmp", PackedByteArray(BYTES))

	assert_int(error).is_equal(ERR_FILE_CANT_WRITE)
	assert_bool(store.exists("user://profile.tmp")).is_false()


func test_calls_are_logged_in_order() -> void:
	var store := FaultInjectingFileStore.new()

	store.write("user://match.tmp", PackedByteArray([1]))
	store.delete("user://match.bak")
	store.rename("user://match.tmp", "user://match.sav")

	assert_array(store.calls).is_equal(PackedStringArray([
		"write user://match.tmp", "delete user://match.bak", "rename user://match.tmp user://match.sav",
	]))
