extends GdUnitTestSuite

const ECLAIREUR := 0
const ASSAUT := 1
const BASTION := 6
const CHASSEUR := 5
const ATTACK := IntentionsSlice.ACTION_ATTACK
const CAPTURE := IntentionsSlice.ACTION_CAPTURE
const UNIT := IntentionsSlice.TARGET_UNIT
const NODE := IntentionsSlice.TARGET_NODE
const HUNT := IntentionsSlice.MOTIVE_HUNT
const CAPTURE_MOTIVE := IntentionsSlice.MOTIVE_CAPTURE


## 6 x 3, turn 4, enemy phase. Player: Assaut 0 at (0,0), Eclaireur 1 at (5,2). AI:
## Chasseur 2 at (1,0) (adjacent to 0), Chasseur 3 at (0,1) (adjacent to 0), Bastion 4
## on the player node 0 at (3,1). Intentions announced at turn 4: id 0 = 2 attacks 0,
## id 1 = 3 attacks 0, id 2 = Bastion 4 captures node 0. The turn then moves to 5.
func _board() -> PipelineFixture:
	var state := _raw()
	var fx := PipelineFixture.new(state)
	assert_bool(fx.announce([[2, UNIT, 0, ATTACK, HUNT], [3, UNIT, 0, ATTACK, HUNT], [4, NODE, 0, CAPTURE, CAPTURE_MOTIVE]]).permitted).is_true()
	GameStateSetup.set_turn(state, 5)
	return fx


func _raw() -> GameState:
	var state := MapBuilder.state(PackedStringArray(["......", "......", "......"]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 5, 2)
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 1, 0)
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 0, 1)
	MapBuilder.unit(state, BASTION, Faction.AI, 3, 1)
	GameStateSetup.add_node(state, state.tile_index(3, 1), Faction.PLAYER, 2)
	GameStateSetup.add_node(state, state.tile_index(5, 0), Faction.AI, 1)
	GameStateSetup.add_node(state, state.tile_index(4, 2), Faction.AI, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 4)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	return MapBuilder.ready(state)


func test_an_attack_is_executed_and_the_author_has_acted() -> void:
	var fx := _board()
	var revision := fx.state.revision()

	assert_bool(fx.execute_intention(0).permitted).is_true()

	assert_int(fx.state.revision()).is_equal(revision + 1)
	assert_int(fx.state.intentions.status_of(0)).is_equal(IntentionsSlice.STATUS_EXECUTED)
	assert_bool(fx.state.view().unit_acted(2)).is_true()
	assert_int(fx.state.view().unit_hp(0)).is_less(CatalogFactory.standard().units.hp(ASSAUT))
	var events := fx.last_events()
	assert_object(events[0]).is_instanceof(IntentionExecutedEvent)
	assert_object(events[1]).is_instanceof(AttackResolvedEvent)


func test_a_capture_is_executed_with_the_normal_capture_application() -> void:
	var fx := _board()
	fx.execute_intention(0)
	fx.execute_intention(1)

	assert_bool(fx.execute_intention(2).permitted).is_true()

	var row := fx.state.nodes.find_row(0)
	assert_int(fx.state.nodes.owner_of(row)).is_equal(Faction.AI)
	assert_int(fx.state.nodes.level_of(row)).is_equal(1)
	assert_bool(fx.state.view().unit_acted(4)).is_true()
	assert_object(fx.last_events()[0]).is_instanceof(IntentionExecutedEvent)
	assert_object(fx.last_events()[1]).is_instanceof(NodeCapturedEvent)


func test_intentions_run_by_ascending_id_and_only_once() -> void:
	var fx := _board()

	assert_str(fx.execute_intention(1).code).is_equal(Refusal.NO_INTENTION)
	assert_str(fx.execute_intention(99).code).is_equal(Refusal.NO_INTENTION)
	assert_bool(fx.execute_intention(0).permitted).is_true()
	assert_str(fx.execute_intention(0).code).is_equal(Refusal.NO_INTENTION)
	assert_bool(fx.execute_intention(1).permitted).is_true()


func test_an_intention_is_not_due_before_its_turn_nor_outside_the_enemy_phase() -> void:
	var fx := _board()
	GameStateSetup.set_turn(fx.state, 4)
	assert_str(fx.execute_intention(0).code).is_equal(Refusal.NO_INTENTION)
	GameStateSetup.set_turn(fx.state, 5)
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)
	assert_str(fx.execute_intention(0).code).is_equal(Refusal.WRONG_PHASE)
	assert_int(fx.state.revision()).is_equal(1)


func _cancelled_with(fx: PipelineFixture, id: int, reason: int) -> void:
	var revision := fx.state.revision()
	assert_bool(fx.execute_intention(id).permitted).is_true()
	assert_int(fx.state.revision()).is_equal(revision + 1)
	assert_int(fx.state.intentions.status_of(id)).is_equal(IntentionsSlice.STATUS_CANCELLED)
	assert_int(fx.state.intentions._int_cancel_reason[id]).is_equal(reason)
	assert_int(fx.last_events().size()).is_equal(1)
	assert_int((fx.last_events()[0] as IntentionCancelledEvent).reason).is_equal(reason)


func test_cancellation_reasons_of_an_attack() -> void:
	var fx := _board()
	UnitWrites.destroy(fx.state, 2)
	_cancelled_with(fx, 0, IntentionsSlice.REASON_AUTHOR_DESTROYED)

	UnitWrites.move_to(fx.state, 0, fx.state.tile_index(0, 2))
	_cancelled_with(fx, 1, IntentionsSlice.REASON_TARGET_MOVED)
	assert_int(fx.state.view().unit_hp(0)).is_equal(CatalogFactory.standard().units.hp(ASSAUT))


func test_cancellation_when_the_target_is_destroyed_or_the_author_out_of_range() -> void:
	var fx := _board()
	UnitWrites.move_to(fx.state, 2, fx.state.tile_index(3, 0))
	_cancelled_with(fx, 0, IntentionsSlice.REASON_OUT_OF_RANGE)

	UnitWrites.destroy(fx.state, 0)
	_cancelled_with(fx, 1, IntentionsSlice.REASON_TARGET_DESTROYED)


func test_a_target_that_moved_back_to_its_tile_does_not_cancel_but_a_move_within_range_does() -> void:
	var fx := _board()
	UnitWrites.move_to(fx.state, 0, fx.state.tile_index(1, 1))

	_cancelled_with(fx, 0, IntentionsSlice.REASON_TARGET_MOVED)


func test_cancellation_reasons_of_a_capture() -> void:
	var fx := _board()
	fx.execute_intention(0)
	fx.execute_intention(1)
	UnitWrites.move_to(fx.state, 4, fx.state.tile_index(3, 2))
	_cancelled_with(fx, 2, IntentionsSlice.REASON_UNIT_ABSENT)

	var other := _board()
	other.execute_intention(0)
	other.execute_intention(1)
	UnitWrites.destroy(other.state, 4)
	_cancelled_with(other, 2, IntentionsSlice.REASON_UNIT_DESTROYED)

	var taken := _board()
	taken.execute_intention(0)
	taken.execute_intention(1)
	NodeWrites.capture(taken.state, 0, Faction.AI)
	_cancelled_with(taken, 2, IntentionsSlice.REASON_NODE_ALREADY_AI)


func test_the_whole_sequence_replays_to_an_equal_state() -> void:
	var raw := _raw()
	var initial := raw.duplicate_state()
	var fx := PipelineFixture.new(raw)
	var announced := [[2, UNIT, 0, ATTACK, HUNT], [3, UNIT, 0, ATTACK, HUNT], [4, NODE, 0, CAPTURE, CAPTURE_MOTIVE]]
	assert_bool(fx.announce(announced).permitted).is_true()
	assert_bool(fx.begin_turn(Faction.PLAYER).permitted).is_true()
	assert_bool(fx.end_turn().permitted).is_true()
	assert_bool(fx.begin_turn(Faction.AI).permitted).is_true()
	for id in [0, 1, 2]:
		assert_bool(fx.execute_intention(id).permitted).is_true()

	var outcome := CommandReplay.replay(initial, fx.log, CatalogFactory.standard())

	assert_int(outcome.divergence).is_equal(-1)
	assert_bool(outcome.state.equals(fx.state)).is_true()


func test_the_codec_round_trips() -> void:
	var encoded := CommandCodec.encode(ExecuteIntentionCommand.new(7))

	var decoded := CommandCodec.decode(encoded) as ExecuteIntentionCommand

	assert_int(decoded.intention_id).is_equal(7)
	assert_array([decoded.faction, decoded.emitter]).is_equal([Faction.AI, Command.EMITTER_SYS])
	assert_object(CommandCodec.decode(PackedInt64Array([CommandType.EXECUTE_INTENTION, 1, 2]))).is_null()
