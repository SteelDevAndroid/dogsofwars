extends GdUnitTestSuite

const ECLAIREUR := 0
const ASSAUT := 1


## 5 x 5 plains: the Éclaireur (view 4) in the middle sees the whole map, so its
## moves reveal nothing and can be undone.
func _open_map() -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray([".....", ".....", ".....", ".....", "....."]))
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 2, 2)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 4, 4)
	return PipelineFixture.new(MapBuilder.ready(state))


func test_applied_move_writes_revision_events_save_and_log() -> void:
	var fx := _open_map()
	var target := fx.state.tile_index(3, 2)

	var result := fx.move(0, target)

	assert_bool(result.permitted).is_true()
	assert_int(fx.state.view().unit_tile(0)).is_equal(target)
	assert_bool(fx.state.view().unit_moved(0)).is_true()
	assert_int(fx.state.revision()).is_equal(1)
	var moved := fx.last_events()[0] as UnitMovedEvent
	assert_int(moved.to_tile).is_equal(target)
	assert_int(moved.requested_tile).is_equal(target)
	assert_object(moved.event_id).is_equal(Vector2i(1, 0))
	assert_array(fx.post_commit.revisions).is_equal(PackedInt64Array([1]))
	assert_array(fx.post_commit.batches_pushed_before).is_equal(PackedInt32Array([0]))
	assert_int(fx.log.commands.size()).is_equal(1)
	assert_int(fx.sink.batches[0].revision).is_equal(1)


func test_refused_command_changes_nothing() -> void:
	var fx := _open_map()
	var before := fx.state.to_bytes()

	var result := fx.move(0, fx.state.tile_index(4, 4))

	assert_str(result.code).is_equal(Refusal.TILE_BLOCKED)
	assert_array(fx.state.to_bytes()).is_equal(before)
	assert_array(fx.sink.batches).is_empty()
	assert_array(fx.log.commands).is_empty()
	assert_array(fx.post_commit.revisions).is_empty()


func test_refusal_prefix_in_its_fixed_order() -> void:
	var fx := _open_map()
	var target := fx.state.tile_index(3, 2)

	assert_str(fx.move(1, fx.state.tile_index(3, 3), Faction.AI).code).is_equal(Refusal.NOT_YOUR_TURN)
	fx.gate.lock(&"ATTACK_RESOLUTION")
	assert_str(fx.move(0, target).code).is_equal(Refusal.COMMANDS_LOCKED)
	fx.gate.unlock(&"ATTACK_RESOLUTION")
	fx.gate.enter_dispatch()
	assert_str(fx.move(0, target).code).is_equal(Refusal.COMMANDS_LOCKED)
	fx.gate.exit_dispatch()
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_FINISHED, Faction.PLAYER)
	assert_str(fx.move(0, target).code).is_equal(Refusal.MATCH_OVER)


func test_player_lock_never_blocks_the_ai() -> void:
	var fx := _open_map()
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	fx.gate.lock(&"FRAGMENT_PANEL")

	assert_bool(fx.move(1, fx.state.tile_index(4, 3), Faction.AI).permitted).is_true()
	assert_int(fx.state.ai_cursor._ai_cursor[0]).is_equal(1)


func test_undo_restores_the_snapshot_and_moves_the_revision_on() -> void:
	var fx := _open_map()
	var start := fx.state.duplicate_state()
	fx.move(0, fx.state.tile_index(3, 2))

	var result := fx.undo_move()

	assert_bool(result.permitted).is_true()
	assert_int(fx.state.revision()).is_equal(2)
	var restored := fx.state.duplicate_state()
	assert_bool(restored.equals(start)).is_false()
	assert_int(fx.state.view().unit_tile(0)).is_equal(start.view().unit_tile(0))
	assert_bool(fx.state.view().unit_moved(0)).is_false()
	var undone := fx.last_events()[0] as MoveUndoneEvent
	assert_int(undone.to_tile).is_equal(start.view().unit_tile(0))
	assert_str(fx.undo_move().code).is_equal(Refusal.NOTHING_TO_UNDO)


func test_undo_codes_after_a_reveal_another_command_or_a_load() -> void:
	var fx := _open_map()
	assert_str(fx.pipeline.check(UndoMoveCommand.new()).code).is_equal(Refusal.NOTHING_TO_UNDO)
	fx.move(0, fx.state.tile_index(3, 2))
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	fx.move(1, fx.state.tile_index(4, 3), Faction.AI)
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)

	assert_str(fx.undo_move().code).is_equal(Refusal.OTHER_ACTION_SINCE)
	fx.pipeline.on_state_loaded()
	assert_str(fx.undo_move().code).is_equal(Refusal.NOTHING_TO_UNDO)


func test_ambush_stops_before_the_hidden_enemy_and_forbids_undo() -> void:
	var state := MapBuilder.state(PackedStringArray(["......"]))
	var unit := MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	var enemy := MapBuilder.unit(state, ASSAUT, Faction.AI, 3, 0)
	var fx := PipelineFixture.new(MapBuilder.ready(state))

	assert_bool(fx.move(unit, state.tile_index(3, 0)).permitted).is_true()

	var moved := fx.last_events()[0] as UnitMovedEvent
	assert_int(moved.to_tile).is_equal(state.tile_index(2, 0))
	assert_int(moved.requested_tile).is_equal(state.tile_index(3, 0))
	assert_bool(VisionService.can_see_unit(state, state.view_cache, Faction.PLAYER, enemy)).is_true()
	assert_str(fx.undo_move().code).is_equal(Refusal.MOVE_REVEALED)


func test_undiscovered_water_or_costly_terrain_stops_the_move_without_penalty() -> void:
	for row in ["...~..", "...f.."]:
		var state := MapBuilder.state(PackedStringArray([row]))
		var unit := MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
		var fx := PipelineFixture.new(MapBuilder.ready(state))

		assert_bool(fx.move(unit, state.tile_index(3, 0)).permitted).is_true()

		assert_int(state.view().unit_tile(unit)).is_equal(state.tile_index(2, 0))
		assert_bool(state.view().unit_moved(unit)).is_true()


func test_move_that_discovers_tiles_publishes_them_for_the_player() -> void:
	var state := MapBuilder.state(PackedStringArray(["........"]))
	var unit := MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	var fx := PipelineFixture.new(MapBuilder.ready(state))

	fx.move(unit, state.tile_index(3, 0))

	var revealed := fx.last_events()[1] as TilesRevealedEvent
	assert_array(revealed.revealed_tiles).is_equal(PackedInt32Array([3, 4, 5]))
	assert_str(fx.undo_move().code).is_equal(Refusal.MOVE_REVEALED)


func test_hidden_ai_move_is_filtered_out_of_the_player_batch() -> void:
	var state := MapBuilder.state(PackedStringArray(["..........", ".........."]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	var enemy := MapBuilder.unit(state, ASSAUT, Faction.AI, 9, 0)
	var fx := PipelineFixture.new(MapBuilder.ready(state))
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)

	fx.move(enemy, state.tile_index(8, 1), Faction.AI)
	fx.move(enemy, state.tile_index(8, 1), Faction.AI)

	assert_int(fx.sink.batches.size()).is_equal(1)
	assert_array(fx.sink.batches[0].events).is_empty()


func test_preview_is_the_command_on_the_faction_view_and_writes_nothing() -> void:
	var state := MapBuilder.state(PackedStringArray(["......"]))
	var unit := MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 3, 0)
	var fx := PipelineFixture.new(MapBuilder.ready(state))
	var before := state.to_bytes()

	var preview := fx.pipeline.preview(MoveCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, unit, state.tile_index(3, 0)))

	assert_bool(preview.validation.permitted).is_true()
	assert_int(preview.base_revision).is_equal(0)
	assert_int((preview.events[0] as UnitMovedEvent).to_tile).is_equal(state.tile_index(3, 0))
	assert_array(state.to_bytes()).is_equal(before)
	assert_array(fx.sink.batches).is_empty()


func test_apply_on_chains_moves_on_a_copy_only() -> void:
	var fx := _open_map()
	var copy := fx.state.filtered_copy(Faction.PLAYER)
	var before := fx.state.to_bytes()

	var result := fx.pipeline.apply_on(copy, MoveCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, 0, copy.tile_index(3, 2)))

	assert_bool(result.permitted).is_true()
	assert_int(copy.revision()).is_equal(1)
	assert_int(copy.view().unit_tile(0)).is_equal(copy.tile_index(3, 2))
	assert_array(fx.state.to_bytes()).is_equal(before)
	assert_array(fx.sink.batches).is_empty()


func test_every_implemented_type_is_registered() -> void:
	var catalog := CatalogFactory.standard()
	var rules := RuleTable.standard(catalog, VisionContext.for_map(catalog, StateFactory.minimal()))

	assert_array(rules.registered_types()).is_equal(PackedInt32Array([CommandType.MOVE, CommandType.ATTACK, CommandType.CAPTURE, CommandType.WAKE, CommandType.RESEARCH, CommandType.END_TURN, CommandType.ABANDON, CommandType.BEGIN_TURN]))
	assert_bool(rules.simulation().has_handler(CommandType.MOVE)).is_true()


func test_codec_round_trips_and_refuses_bad_input() -> void:
	var move := MoveCommand.new(Faction.AI, Command.EMITTER_AI, 7, 42)

	var decoded := CommandCodec.decode(CommandCodec.encode(move)) as MoveCommand

	assert_int(decoded.unit_id).is_equal(7)
	assert_int(decoded.tile).is_equal(42)
	assert_int(decoded.emitter).is_equal(Command.EMITTER_AI)
	assert_object(CommandCodec.decode(PackedInt64Array([CommandType.MOVE, 0, 0, 1]))).is_null()
	assert_object(CommandCodec.decode(PackedInt64Array([CommandType.ATTACK, 0, 0]))).is_null()
	assert_object(CommandCodec.decode(CommandCodec.encode(UndoMoveCommand.new()))).is_not_null()
