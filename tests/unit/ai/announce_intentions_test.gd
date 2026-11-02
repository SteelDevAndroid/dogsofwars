extends GdUnitTestSuite

const ECLAIREUR := 0
const ASSAUT := 1
const OUVRIER := 3
const SENTINELLE := 4
const CHASSEUR := 5
const BASTION := 6
const ATTACK := IntentionsSlice.ACTION_ATTACK
const CAPTURE := IntentionsSlice.ACTION_CAPTURE
const UNIT := IntentionsSlice.TARGET_UNIT
const NODE := IntentionsSlice.TARGET_NODE


## 6 x 3, turn 4, enemy phase. Player: Assaut 0 at (0,0), Ouvrier 1 at (5,2). AI:
## Chasseur 2 at (1,0) (adjacent to unit 0), Bastion 3 at (3,1) on the player node 0,
## Sentinelle 4 at (4,0) (no attack), a second Chasseur 5 at (3,0). Node 0 (player,
## level 1) at (3,1); node 1 (AI) at (4,1). Player Eclaireur 6 at (5,0), at distance 1
## of the Sentinelle and 2 of the Chasseur 5; AI Bastion 7 stands on its own node 1, AI Bastion 8 on the player node 2 at (0,2).
func _board() -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray(["......", "......", "......"]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, OUVRIER, Faction.PLAYER, 5, 2)
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 1, 0)
	MapBuilder.unit(state, BASTION, Faction.AI, 3, 1)
	MapBuilder.unit(state, SENTINELLE, Faction.AI, 4, 0)
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 3, 0)
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 5, 0)
	MapBuilder.unit(state, BASTION, Faction.AI, 4, 1)
	MapBuilder.unit(state, BASTION, Faction.AI, 0, 2)
	GameStateSetup.add_node(state, state.tile_index(3, 1), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(4, 1), Faction.AI, 1)
	GameStateSetup.add_node(state, state.tile_index(0, 2), Faction.PLAYER, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 4)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	return PipelineFixture.new(MapBuilder.ready(state))


func _code(result: ValidationResult) -> StringName:
	return result.code


func test_an_attack_and_a_capture_are_stored_with_positions_and_events() -> void:
	var fx := _board()

	var result := fx.announce([[2, UNIT, 0, ATTACK, IntentionsSlice.MOTIVE_HUNT], [3, NODE, 0, CAPTURE, IntentionsSlice.MOTIVE_CAPTURE]],
			[[2, AiAgentsSlice.ROLE_HUNT, 0, 7, IntentionsSlice.MOTIVE_HUNT], [3, AiAgentsSlice.ROLE_SIEGE, 0, -1, AiAgentsSlice.NO_MOTIVE]], 0, 1)

	assert_bool(result.permitted).is_true()
	var slice := fx.state.intentions
	assert_int(slice.row_count()).is_equal(2)
	assert_array([slice.id_of(0), slice.id_of(1)]).is_equal([0, 1])
	assert_array([slice.author_of(0), slice.target_kind_of(0), slice.target_id_of(0), slice.action_of(0), slice.motive_of(0)]) \
			.is_equal([2, UNIT, 0, ATTACK, IntentionsSlice.MOTIVE_HUNT])
	assert_array([slice.author_tile_of(0), slice.target_tile_of(0)]).is_equal([fx.state.tile_index(1, 0), fx.state.tile_index(0, 0)])
	assert_array([slice.announced_turn_of(1), slice.exec_turn_of(1), slice.status_of(1)]).is_equal([4, 5, IntentionsSlice.STATUS_ANNOUNCED])
	assert_int(slice.target_tile_of(1)).is_equal(fx.state.tile_index(3, 1))
	assert_array([fx.state.siege.node_of(), fx.state.siege.count_of()]).is_equal([0, 1])
	assert_int(fx.state.ai_agents.row_count()).is_equal(2)
	assert_int(fx.state.ai_agents.role_of(1)).is_equal(AiAgentsSlice.ROLE_SIEGE)
	assert_int(fx.state.header.value(HeaderSlice.NEXT_INTENTION_ID)).is_equal(2)
	assert_int(fx.state.revision()).is_equal(1)
	var events := fx.last_events()
	assert_int(events.size()).is_equal(2)
	assert_int((events[0] as IntentionAnnouncedEvent).siege).is_equal(0)
	assert_int((events[1] as IntentionAnnouncedEvent).siege).is_equal(1)
	assert_int((events[1] as IntentionAnnouncedEvent).target_tile).is_equal(fx.state.tile_index(3, 1))


func test_validation_refuses_a_malformed_announcement_naming_its_index() -> void:
	var fx := _board()
	var hunt := IntentionsSlice.MOTIVE_HUNT

	assert_str(_code(fx.announce([[0, UNIT, 2, ATTACK, hunt]]))).is_equal(Refusal.INVALID_ANNOUNCEMENT)
	assert_array(fx.announce([[2, UNIT, 0, ATTACK, hunt], [3, UNIT, 0, ATTACK, hunt]]).params).is_equal([1])
	# author out of range of the target, Sentinelle without attack, hidden target, motive off the list
	assert_array(fx.announce([[5, UNIT, 0, ATTACK, hunt]]).params).is_equal([0])
	assert_array(fx.announce([[4, UNIT, 0, ATTACK, hunt]]).params).is_equal([0])
	assert_array(fx.announce([[2, UNIT, 1, ATTACK, hunt]]).params).is_equal([0])
	assert_array(fx.announce([[2, UNIT, 0, ATTACK, IntentionsSlice.MOTIVE_COUNT]]).params).is_equal([0])
	assert_array(fx.announce([[2, UNIT, 0, ATTACK, IntentionsSlice.MOTIVE_CAPTURE]]).params).is_equal([0])
	assert_array(fx.announce([[4, UNIT, 6, ATTACK, hunt]]).params).is_equal([0])
	assert_array(fx.announce([[5, UNIT, 6, ATTACK, hunt]]).params).is_equal([0])
	assert_array(fx.announce([[7, NODE, 1, CAPTURE, IntentionsSlice.MOTIVE_CAPTURE]]).params).is_equal([0])
	# friendly and unknown targets, a capture off a node or on an AI node, a hunter capturing
	assert_array(fx.announce([[2, UNIT, 3, ATTACK, hunt]]).params).is_equal([0])
	assert_array(fx.announce([[2, UNIT, 99, ATTACK, hunt]]).params).is_equal([0])
	assert_array(fx.announce([[6, UNIT, 6, ATTACK, hunt]]).params).is_equal([0])
	assert_array(fx.announce([[2, NODE, 0, CAPTURE, IntentionsSlice.MOTIVE_CAPTURE]]).params).is_equal([0])
	assert_array(fx.announce([[3, NODE, 1, CAPTURE, IntentionsSlice.MOTIVE_CAPTURE]]).params).is_equal([0])
	# authors must be ascending and unique
	assert_array(fx.announce([[3, NODE, 0, CAPTURE, IntentionsSlice.MOTIVE_CAPTURE], [2, UNIT, 0, ATTACK, hunt]], [], 0, 1).params).is_equal([1])
	assert_array(fx.announce([[2, UNIT, 0, ATTACK, hunt], [2, UNIT, 0, ATTACK, hunt]]).params).is_equal([1])
	assert_int(fx.state.revision()).is_equal(0)


func test_one_intention_per_unit_and_turn() -> void:
	var fx := _board()
	assert_bool(fx.announce([[2, UNIT, 0, ATTACK, IntentionsSlice.MOTIVE_HUNT]]).permitted).is_true()

	var again := fx.announce([[2, UNIT, 0, ATTACK, IntentionsSlice.MOTIVE_HUNT]])

	assert_str(again.code).is_equal(Refusal.INVALID_ANNOUNCEMENT)
	assert_array(again.params).is_equal([0])


func test_the_siege_goes_one_then_two_and_needs_its_capture_intention() -> void:
	var fx := _board()
	var capture := [[3, NODE, 0, CAPTURE, IntentionsSlice.MOTIVE_CAPTURE]]

	assert_array(fx.announce([], [], 0, 1).params).is_equal([-1])
	assert_array(fx.announce(capture, [], 0, 2).params).is_equal([-1])
	assert_array(fx.announce(capture, [], 1, 1).params).is_equal([-1])
	assert_array(fx.announce(capture, [], -1, 1).params).is_equal([-1])
	assert_array(fx.announce(capture, [], 0, 2).params).is_equal([-1])
	assert_bool(fx.announce(capture, [], 0, 1).permitted).is_true()

	GameStateSetup.set_turn(fx.state, 5)
	assert_array(fx.announce([], [], 0, 2).params).is_equal([-1])
	assert_array(fx.announce(capture, [], 0, 3).params).is_equal([-1])
	assert_array(fx.announce([[8, NODE, 2, CAPTURE, IntentionsSlice.MOTIVE_CAPTURE]], [], 2, 2).params).is_equal([-1])
	assert_bool(fx.announce(capture, [], 0, 2).permitted).is_true()
	assert_int(fx.state.siege.count_of()).is_equal(2)
	assert_int((fx.last_events()[0] as IntentionAnnouncedEvent).siege).is_equal(2)

	GameStateSetup.set_turn(fx.state, 6)
	assert_array(fx.announce(capture, [], 0, 2).params).is_equal([-1])

	assert_bool(fx.announce([], [], -1, 0).permitted).is_true()
	assert_array([fx.state.siege.node_of(), fx.state.siege.count_of()]).is_equal([-1, 0])


func test_no_siege_can_start_too_late_to_end() -> void:
	var fx := _board()
	var capture := [[3, NODE, 0, CAPTURE, IntentionsSlice.MOTIVE_CAPTURE]]
	GameStateSetup.set_turn(fx.state, 29)

	assert_array(fx.announce(capture, [], 0, 1).params).is_equal([-1])
	GameStateSetup.set_turn(fx.state, 28)
	assert_bool(fx.announce(capture, [], 0, 1).permitted).is_true()


func test_agents_must_be_ai_units_with_valid_roles() -> void:
	var fx := _board()

	assert_array(fx.announce([], [[0, AiAgentsSlice.ROLE_POST, 0, -1, 255]]).params).is_equal([0])
	assert_array(fx.announce([], [[2, AiAgentsSlice.ROLE_COUNT, 0, -1, 255]]).params).is_equal([0])
	assert_array(fx.announce([], [[2, 0, -1, -1, 255]]).params).is_equal([0])
	assert_array(fx.announce([], [[2, 0, 0, 18, 255]]).params).is_equal([0])
	assert_array(fx.announce([], [[2, 0, 0, -1, IntentionsSlice.MOTIVE_COUNT]]).params).is_equal([0])
	assert_array(fx.announce([], [[3, 0, 0, -1, 255], [2, 0, 0, -1, 255]]).params).is_equal([1])
	assert_bool(fx.announce([], [[2, AiAgentsSlice.ROLE_HUNT, 3, 5, IntentionsSlice.MOTIVE_REPRISAL]]).permitted).is_true()
	assert_bool(fx.announce([], [[2, AiAgentsSlice.ROLE_RETURN, 4, 5, 255]]).permitted).is_true()
	assert_int(fx.state.ai_agents.row_count()).is_equal(1)
	assert_array([fx.state.ai_agents.role_of(0), fx.state.ai_agents.idle_turns_of(0), fx.state.ai_agents.post_tile_of(0), fx.state.ai_agents.motive_of(0)]) \
			.is_equal([AiAgentsSlice.ROLE_RETURN, 4, 5, 255])


func test_phase_turn_limit_and_passive_ai() -> void:
	var fx := _board()
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)
	assert_str(fx.announce().code).is_equal(Refusal.WRONG_PHASE)
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_END_OF_TURN, Faction.AI)
	assert_str(fx.announce().code).is_equal(Refusal.WRONG_PHASE)
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	GameStateSetup.set_turn(fx.state, 30)
	assert_str(fx.announce().code).is_equal(Refusal.TURN_LIMIT)
	GameStateSetup.set_turn(fx.state, 4)
	GameStateSetup.set_ai_passive(fx.state, true)
	assert_str(fx.announce().code).is_equal(Refusal.AI_PASSIVE)


func test_old_intentions_are_pruned_and_ids_keep_growing() -> void:
	var fx := _board()
	var hunt := IntentionsSlice.MOTIVE_HUNT
	for turn in [4, 5, 6]:
		GameStateSetup.set_turn(fx.state, turn)
		assert_bool(fx.announce([[2, UNIT, 0, ATTACK, hunt]]).permitted).is_true()

	assert_int(fx.state.intentions.row_count()).is_equal(2)
	assert_array([fx.state.intentions.id_of(0), fx.state.intentions.id_of(1)]).is_equal([1, 2])
	assert_int(fx.state.header.value(HeaderSlice.NEXT_INTENTION_ID)).is_equal(3)
	assert_array(fx.state.validate()).is_empty()


func test_a_begin_turn_of_the_ai_resets_the_cursor() -> void:
	var fx := _board()
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_END_OF_TURN, Faction.AI)
	AiWrites.set_cursor(fx.state, 3)

	assert_bool(fx.begin_turn(Faction.AI).permitted).is_true()

	assert_int(fx.state.ai_cursor._ai_cursor[0]).is_equal(0)


func test_the_codec_round_trips_and_rejects_a_bad_length() -> void:
	var command := AnnounceIntentionsCommand.new(0, 2, PackedInt64Array([2, UNIT, 0, ATTACK, 0, 3, NODE, 0, CAPTURE, 2]),
			PackedInt64Array([2, 1, 0, -1, 255]))

	var encoded := CommandCodec.encode(command)
	var decoded := CommandCodec.decode(encoded) as AnnounceIntentionsCommand

	assert_array(CommandCodec.encode(decoded)).is_equal(encoded)
	assert_array([decoded.faction, decoded.emitter]).is_equal([Faction.AI, Command.EMITTER_SYS])
	encoded.append(1)
	assert_object(CommandCodec.decode(encoded)).is_null()
	assert_object(CommandCodec.decode(PackedInt64Array([CommandType.ANNOUNCE_INTENTIONS, 1, 2, 0, 0]))).is_null()


func test_the_player_sees_an_attack_marker_on_a_visible_target_and_a_capture_anywhere() -> void:
	var fx := _board()
	fx.announce([[2, UNIT, 0, ATTACK, IntentionsSlice.MOTIVE_HUNT], [3, NODE, 0, CAPTURE, IntentionsSlice.MOTIVE_CAPTURE]], [], 0, 1)

	var ids := fx.sink.batches[-1].events.map(func(event: PresentationEvent) -> int: return (event as IntentionAnnouncedEvent).intention_id)

	assert_array(ids).is_equal([0, 1])
