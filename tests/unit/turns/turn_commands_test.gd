extends GdUnitTestSuite

const ASSAUT := 1


func _created() -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray([".....", ".....", "....."]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 4, 2)
	return PipelineFixture.new(MapBuilder.ready(state), true)


func _phase(fx: PipelineFixture) -> int:
	return fx.state.header.value(HeaderSlice.PHASE)


func test_begin_turn_opens_the_match_at_turn_one() -> void:
	var fx := _created()

	assert_bool(fx.begin_turn(Faction.PLAYER).permitted).is_true()

	assert_int(fx.state.turn()).is_equal(1)
	assert_int(_phase(fx)).is_equal(HeaderSlice.PHASE_PLAYER)
	var started := fx.last_events()[0] as TurnStartedEvent
	assert_int(started.turn).is_equal(1)
	assert_int(started.turn_faction).is_equal(Faction.PLAYER)


func test_a_full_turn_cycle_through_the_commands() -> void:
	var fx := _created()
	fx.begin_turn(Faction.PLAYER)
	fx.move(0, fx.state.tile_index(1, 0))

	assert_bool(fx.end_turn().permitted).is_true()
	assert_int(_phase(fx)).is_equal(HeaderSlice.PHASE_END_OF_TURN)
	assert_str(fx.move(0, fx.state.tile_index(2, 0)).code).is_equal(Refusal.NOT_YOUR_TURN)
	assert_bool(fx.begin_turn(Faction.AI).permitted).is_true()
	assert_int(_phase(fx)).is_equal(HeaderSlice.PHASE_ENEMY_EXECUTION)
	assert_int(fx.state.turn()).is_equal(1)
	assert_bool(fx.move(1, fx.state.tile_index(3, 2), Faction.AI).permitted).is_true()
	assert_bool(fx.begin_turn(Faction.PLAYER).permitted).is_true()

	assert_int(fx.state.turn()).is_equal(2)
	assert_bool(fx.state.view().unit_moved(0)).is_false()
	assert_bool(fx.state.view().unit_moved(1)).is_true()
	assert_bool(fx.move(0, fx.state.tile_index(2, 0)).permitted).is_true()


func test_begin_turn_resets_only_the_faction_flags() -> void:
	var fx := _created()
	fx.begin_turn(Faction.PLAYER)
	fx.move(0, fx.state.tile_index(1, 0))
	fx.end_turn()

	fx.begin_turn(Faction.AI)

	assert_bool(fx.state.view().unit_moved(0)).is_true()


func test_internal_turn_commands_out_of_sequence_are_refused() -> void:
	var fx := _created()

	assert_str(fx.begin_turn(Faction.AI).code).is_equal(Refusal.WRONG_PHASE)
	fx.begin_turn(Faction.PLAYER)
	assert_str(fx.begin_turn(Faction.PLAYER).code).is_equal(Refusal.WRONG_PHASE)
	assert_str(fx.begin_turn(Faction.AI).code).is_equal(Refusal.WRONG_PHASE)
	fx.end_turn()
	assert_str(fx.end_turn().code).is_equal(Refusal.NOT_YOUR_TURN)
	assert_str(fx.begin_turn(Faction.PLAYER).code).is_equal(Refusal.WRONG_PHASE)


func test_no_turn_beyond_t_max_from_a_created_state() -> void:
	var fx := _created()
	GameStateSetup.set_turn(fx.state, GameState.MAX_TURN)

	var result := fx.begin_turn(Faction.PLAYER)

	assert_str(result.code).is_equal(Refusal.TURN_LIMIT)
	assert_array(result.params).is_equal(PackedInt64Array([GameState.MAX_TURN]))


func test_end_turn_is_locked_like_any_player_command_and_not_for_the_ai() -> void:
	var fx := _created()
	fx.begin_turn(Faction.PLAYER)
	fx.gate.lock(&"ATTACK_RESOLUTION")

	assert_str(fx.end_turn().code).is_equal(Refusal.COMMANDS_LOCKED)
	fx.gate.unlock(&"ATTACK_RESOLUTION")
	assert_str(fx.pipeline.submit(EndTurnCommand.new(Faction.AI, Command.EMITTER_AI)).code).is_equal(Refusal.NOT_YOUR_TURN)


func test_end_turn_disarms_the_undo() -> void:
	var state := MapBuilder.state(PackedStringArray([".....", ".....", ".....", ".....", "....."]))
	MapBuilder.unit(state, 0, Faction.PLAYER, 2, 2)
	var fx := PipelineFixture.new(MapBuilder.ready(state))
	fx.move(0, state.tile_index(3, 2))

	fx.end_turn()

	assert_str(fx.pipeline.check(UndoMoveCommand.new()).code).is_equal(Refusal.NOT_YOUR_TURN)
	assert_str(fx.undo.reason).is_equal(Refusal.OTHER_ACTION_SINCE)


func test_turn_events_are_public_and_codec_round_trips() -> void:
	var fx := _created()
	fx.begin_turn(Faction.PLAYER)
	fx.end_turn()

	fx.begin_turn(Faction.AI)

	assert_int(fx.sink.batches.size()).is_equal(3)
	assert_int((fx.last_events()[0] as TurnStartedEvent).turn_faction).is_equal(Faction.AI)
	var begin := CommandCodec.decode(CommandCodec.encode(BeginTurnCommand.new(Faction.AI)))
	assert_int(begin.type()).is_equal(CommandType.BEGIN_TURN)
	assert_int(begin.faction).is_equal(Faction.AI)
	assert_int(CommandCodec.decode(CommandCodec.encode(EndTurnCommand.new())).type()).is_equal(CommandType.END_TURN)
