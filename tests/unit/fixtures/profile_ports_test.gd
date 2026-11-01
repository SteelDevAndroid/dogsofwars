extends GdUnitTestSuite


func test_null_port_writes_nothing_and_answers_false() -> void:
	assert_bool(NullProfilePort.new().apply(RecordFragmentEffect.new(Faction.PLAYER, 3))).is_false()


func test_recording_port_keeps_fragments_sorted_and_logs_calls() -> void:
	var port := RecordingProfilePort.new()

	var written := port.apply(RecordFragmentEffect.new(Faction.PLAYER, 7))
	port.apply(RecordFragmentEffect.new(Faction.PLAYER, 2))
	port.apply(RecordFragmentEffect.new(Faction.AI, 5))

	assert_bool(written).is_true()
	assert_array(port.fragments_of(Faction.PLAYER)).is_equal(PackedInt32Array([2, 7]))
	assert_array(port.fragments_of(Faction.AI)).is_equal(PackedInt32Array([5]))
	assert_int(port.calls.size()).is_equal(3)


func test_recording_port_is_idempotent_by_fragment() -> void:
	var port := RecordingProfilePort.new()

	port.apply(RecordFragmentEffect.new(Faction.PLAYER, 4))
	var again := port.apply(RecordFragmentEffect.new(Faction.PLAYER, 4))

	assert_bool(again).is_true()
	assert_array(port.fragments_of(Faction.PLAYER)).is_equal(PackedInt32Array([4]))
	assert_int(port.calls.size()).is_equal(2)


func test_failed_or_read_only_write_answers_false_and_keeps_nothing() -> void:
	var failing := RecordingProfilePort.new()
	failing.fail_writes = true
	var read_only := RecordingProfilePort.new()
	read_only.read_only = true

	assert_bool(failing.apply(RecordFragmentEffect.new(Faction.PLAYER, 1))).is_false()
	assert_bool(read_only.apply(RecordFragmentEffect.new(Faction.PLAYER, 1))).is_false()
	assert_bool(failing.has_fragment(Faction.PLAYER, 1)).is_false()
	assert_bool(read_only.has_fragment(Faction.PLAYER, 1)).is_false()
	assert_int(failing.calls.size()).is_equal(1)


func test_retry_after_a_failure_writes_the_fragment() -> void:
	var port := RecordingProfilePort.new()
	port.fail_writes = true
	port.apply(RecordFragmentEffect.new(Faction.PLAYER, 9))

	port.fail_writes = false
	var retried := port.apply(RecordFragmentEffect.new(Faction.PLAYER, 9))

	assert_bool(retried).is_true()
	assert_bool(port.has_fragment(Faction.PLAYER, 9)).is_true()
