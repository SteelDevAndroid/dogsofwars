extends GdUnitTestSuite

const ECLAIREUR := 0
const ASSAUT := 1
const REMPART := 2
const CHASSEUR := 5
const REPOS := 3


## 8 x 2, turn 3 ended by the AI. Player node at (0,0) (level 1), AI node at (7,1).
## Player: Assaut 0 at (0,0) 3/8 (on the node), Assaut 1 at (3,0) 7/8, Rempart 2 at (4,0)
## 14/14, Eclaireur 3 at (0,1) 1/6 (off the node), Assaut 4 at (2,0) 3/8 that moved.
## AI: Chasseur 5 at (7,0) 4/8.
func _board() -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray(["........", "........"]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0, false, 3)
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 3, 0, false, 7)
	MapBuilder.unit(state, REMPART, Faction.PLAYER, 4, 0)
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 0, 1, false, 1)
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 2, 0, false, 3)
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 7, 0, false, 4)
	GameStateSetup.add_node(state, state.tile_index(0, 0), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(7, 1), Faction.AI, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 3)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	UnitWrites.set_moved(state, 4)
	return PipelineFixture.new(MapBuilder.ready(state))


func _hp(fx: PipelineFixture, unit_id: int) -> int:
	return fx.state.view().unit_hp(unit_id)


func test_a_rested_unit_heals_by_the_formula_of_the_gdd() -> void:
	var fx := _board()

	assert_bool(fx.begin_turn(Faction.PLAYER).permitted).is_true()

	assert_int(_hp(fx, 0)).is_equal(7)  # 3/8 on an owned node: min(4, 5)
	assert_int(_hp(fx, 1)).is_equal(8)  # 7/8 off a node: min(2, 1)
	assert_int(_hp(fx, 2)).is_equal(14)  # full HP: nothing written
	assert_int(_hp(fx, 3)).is_equal(3)  # 1/6 off a node: +2
	assert_int(_hp(fx, 4)).is_equal(3)  # moved last turn
	assert_int(_hp(fx, 5)).is_equal(4)  # the other faction waits for its own turn


func test_heal_events_follow_turn_started_and_skip_zero_heals() -> void:
	var fx := _board()
	fx.begin_turn(Faction.PLAYER)

	var healed: Array = fx.last_events().filter(func(event: PresentationEvent) -> bool: return event is UnitHealedEvent)

	assert_array(healed.map(func(event: UnitHealedEvent) -> Array: return [event.unit_id, event.hp_before, event.hp_after])) \
			.is_equal([[0, 3, 7], [1, 7, 8], [3, 1, 3]])
	assert_object(fx.last_events()[0]).is_instanceof(TurnStartedEvent)
	assert_object(fx.last_events()[1]).is_instanceof(UnitHealedEvent)


func test_the_flags_are_reset_after_the_check() -> void:
	var fx := _board()

	fx.begin_turn(Faction.PLAYER)

	assert_bool(fx.state.view().unit_moved(4)).is_false()
	assert_int(_hp(fx, 4)).is_equal(3)


func test_a_sleeping_or_just_woken_unit_does_not_heal() -> void:
	var fx := _board()
	var dormant := MapBuilder.unit(fx.state, ASSAUT, Faction.PLAYER, 6, 1, true, 3)
	var woken := MapBuilder.unit(fx.state, ASSAUT, Faction.PLAYER, 1, 1, false, 3)
	UnitWrites.set_moved(fx.state, woken)
	UnitWrites.set_acted(fx.state, woken)

	fx.begin_turn(Faction.PLAYER)

	assert_int(_hp(fx, dormant)).is_equal(3)
	assert_int(_hp(fx, woken)).is_equal(3)


func test_an_announced_attack_intention_prevents_the_heal() -> void:
	var fx := _board()
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	UnitWrites.move_to(fx.state, 5, fx.state.tile_index(1, 1))
	VisionService.recompute(fx.state, fx.rules.vision)
	assert_bool(fx.announce([[5, IntentionsSlice.TARGET_UNIT, 3, IntentionsSlice.ACTION_ATTACK, IntentionsSlice.MOTIVE_HUNT]]).permitted).is_true()
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	fx.begin_turn(Faction.PLAYER)
	fx.end_turn()

	assert_bool(fx.begin_turn(Faction.AI).permitted).is_true()

	assert_int(_hp(fx, 5)).is_equal(4)


func test_a_unit_with_a_settled_intention_or_a_capture_intention_heals() -> void:
	var fx := _board()
	UnitWrites.move_to(fx.state, 5, fx.state.tile_index(1, 1))
	VisionService.recompute(fx.state, fx.rules.vision)
	fx.announce([[5, IntentionsSlice.TARGET_UNIT, 3, IntentionsSlice.ACTION_ATTACK, IntentionsSlice.MOTIVE_HUNT]])
	AiWrites.settle_intention(fx.state, 0, IntentionsSlice.STATUS_CANCELLED, IntentionsSlice.REASON_TARGET_MOVED)
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_END_OF_TURN, Faction.AI)

	fx.begin_turn(Faction.AI)

	assert_int(_hp(fx, 5)).is_equal(6)


func test_the_rest_protocol_adds_to_the_base_but_not_to_the_node_bonus() -> void:
	var fx := _board()
	ResearchRules.acquire(fx.state, Faction.PLAYER, REPOS)

	fx.begin_turn(Faction.PLAYER)

	assert_int(_hp(fx, 0)).is_equal(8)  # min(3 + 2, 5)
	assert_int(_hp(fx, 3)).is_equal(4)  # 1 + 3


func test_a_node_owned_by_the_other_faction_gives_no_bonus() -> void:
	var fx := _board()
	NodeWrites.capture(fx.state, 0, Faction.AI)

	fx.begin_turn(Faction.PLAYER)

	assert_int(_hp(fx, 0)).is_equal(5)


func test_a_unit_that_only_acted_does_not_heal() -> void:
	var fx := _board()
	UnitWrites.set_acted(fx.state, 1)

	fx.begin_turn(Faction.PLAYER)

	assert_int(_hp(fx, 1)).is_equal(7)


func test_a_capture_intention_does_not_prevent_the_heal() -> void:
	var fx := _board()
	AiWrites.announce_intention(fx.state, 5, fx.state.tile_index(7, 0), IntentionsSlice.TARGET_NODE, 0, fx.state.tile_index(0, 0),
			IntentionsSlice.ACTION_CAPTURE, IntentionsSlice.MOTIVE_CAPTURE)
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_END_OF_TURN, Faction.AI)

	fx.begin_turn(Faction.AI)

	assert_int(_hp(fx, 5)).is_equal(6)


func test_the_base_heal_comes_from_the_data() -> void:
	var docs := CatalogFactory.documents()
	docs["units.json"]["rest_heal"] = 3
	docs["units.json"]["node_rest_bonus"] = 1
	var catalog := CatalogFactory.load_documents(docs).catalog
	var fx := _board()
	var events: Array[PresentationEvent] = []

	RestRules.heal_faction(fx.state, Faction.PLAYER, catalog, events)

	assert_int(_hp(fx, 0)).is_equal(7)  # 3 + 1 on the node
	assert_int(_hp(fx, 3)).is_equal(4)  # 3 off it


func test_the_heal_data_is_bounded() -> void:
	var docs := CatalogFactory.documents()
	docs["units.json"]["rest_heal"] = 0
	docs["units.json"]["node_rest_bonus"] = 5

	var result := CatalogFactory.load_documents(docs)

	assert_bool(result.ok).is_false()
	assert_array(result.errors.map(func(error: DataError) -> String: return error.to_string())).contains([
		"units.json: rest_heal: 0 outside 1..3", "units.json: node_rest_bonus: 5 outside 0..4"])
