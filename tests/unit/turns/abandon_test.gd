extends GdUnitTestSuite

const ASSAUT := 1


func _match(phase: int, active: int) -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray([".....", "....."]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 4, 1)
	MapBuilder.ready(state)
	GameStateSetup.set_turn(state, 7)
	GameStateSetup.set_phase(state, phase, active)
	return PipelineFixture.new(state)


func test_abandon_ends_the_match_with_the_abandon_status() -> void:
	var fx := _match(HeaderSlice.PHASE_PLAYER, Faction.PLAYER)

	assert_bool(fx.abandon().permitted).is_true()

	assert_int(fx.state.header.value(HeaderSlice.PHASE)).is_equal(HeaderSlice.PHASE_FINISHED)
	assert_int(fx.state.header.value(HeaderSlice.END_STATUS)).is_equal(HeaderSlice.END_ABANDONED)
	assert_int((fx.last_events()[0] as MatchEndedEvent).status).is_equal(HeaderSlice.END_ABANDONED)
	assert_array(fx.post_commit.revisions).is_equal(PackedInt64Array([1]))
	assert_int(fx.state.turn()).is_equal(7)


func test_abandon_is_permitted_in_the_enemy_phase_and_at_the_end_of_turn() -> void:
	for phase in [HeaderSlice.PHASE_ENEMY_EXECUTION, HeaderSlice.PHASE_END_OF_TURN]:
		var fx := _match(phase, Faction.AI if phase == HeaderSlice.PHASE_ENEMY_EXECUTION else Faction.PLAYER)

		assert_bool(fx.abandon().permitted).is_true()


func test_after_the_end_abandon_and_every_command_are_refused() -> void:
	var fx := _match(HeaderSlice.PHASE_PLAYER, Faction.PLAYER)
	fx.abandon()

	assert_str(fx.abandon().code).is_equal(Refusal.MATCH_OVER)
	assert_str(fx.move(0, fx.state.tile_index(1, 0)).code).is_equal(Refusal.MATCH_OVER)
	assert_int(fx.state.revision()).is_equal(1)


func test_only_the_player_abandons() -> void:
	var fx := _match(HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)

	assert_str(fx.pipeline.submit(AbandonCommand.new(Faction.AI, Command.EMITTER_AI)).code).is_equal(Refusal.NOT_YOUR_TURN)


func test_abandon_disarms_the_undo_and_round_trips_in_the_codec() -> void:
	var state := MapBuilder.state(PackedStringArray([".....", ".....", ".....", ".....", "....."]))
	MapBuilder.unit(state, 0, Faction.PLAYER, 2, 2)
	var fx := PipelineFixture.new(MapBuilder.ready(state))
	fx.move(0, state.tile_index(3, 2))

	fx.abandon()

	assert_str(fx.undo.reason).is_equal(Refusal.OTHER_ACTION_SINCE)
	assert_int(CommandCodec.decode(CommandCodec.encode(AbandonCommand.new())).type()).is_equal(CommandType.ABANDON)
