extends GdUnitTestSuite

const ASSAUT := 1
const REPOS := 3
const BLINDAGE := 4
const REMPART_ARME := 5


func _with_research(protocol: int, turns_left: int) -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray(["......"]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 5, 0)
	MapBuilder.ready(state)
	var loaded := StatePayload.decoded_with(state, &"_fac_research_id", PackedInt32Array([protocol, -1]))
	loaded = StatePayload.decoded_with(loaded, &"_fac_research_turns", PackedInt32Array([turns_left, 0]))
	VisionService.rebuild(loaded, StateFactory.vision_context(loaded))
	return PipelineFixture.new(loaded, true)


func test_research_launched_for_two_turns_ends_at_the_second_turn_start() -> void:
	var fx := _with_research(REPOS, 2)

	fx.begin_turn(Faction.PLAYER)
	assert_int(fx.state.factions.research_turns_of(Faction.PLAYER)).is_equal(1)
	assert_bool(fx.state.protocols.has(Faction.PLAYER, REPOS)).is_false()
	fx.end_turn()
	fx.begin_turn(Faction.AI)
	fx.begin_turn(Faction.PLAYER)

	assert_bool(fx.state.protocols.has(Faction.PLAYER, REPOS)).is_true()
	assert_int(fx.state.factions.research_of(Faction.PLAYER)).is_equal(ResearchRules.NONE)
	var done := fx.last_events()[fx.last_events().size() - 1] as ResearchCompletedEvent
	assert_int(done.protocol).is_equal(REPOS)


func test_research_advances_after_the_income() -> void:
	var fx := _with_research(REPOS, 1)
	GameStateSetup.add_node(fx.state, 2, Faction.PLAYER, 1)

	fx.begin_turn(Faction.PLAYER)

	var events := fx.last_events()
	assert_object(events[1]).is_instanceof(EnergyChangedEvent)
	assert_object(events[2]).is_instanceof(ResearchCompletedEvent)


func test_acquired_protocols_stay_sorted_by_faction_then_id() -> void:
	var state := StateFactory.minimal()

	ResearchRules.acquire(state, Faction.AI, BLINDAGE)
	ResearchRules.acquire(state, Faction.PLAYER, REPOS)
	ResearchRules.acquire(state, Faction.PLAYER, REMPART_ARME)

	assert_array([state.protocols.faction_of(0), state.protocols.protocol_of(0)]).is_equal([Faction.PLAYER, REPOS])
	assert_array([state.protocols.faction_of(1), state.protocols.protocol_of(1)]).is_equal([Faction.PLAYER, REMPART_ARME])
	assert_array([state.protocols.faction_of(2), state.protocols.protocol_of(2)]).is_equal([Faction.AI, BLINDAGE])


func test_ai_receives_its_calendar_protocols_at_its_phase_start() -> void:
	var fx := _with_research(ResearchRules.NONE, 0)
	GameStateSetup.set_turn(fx.state, 11)
	fx.begin_turn(Faction.PLAYER)
	assert_bool(fx.state.protocols.has(Faction.AI, BLINDAGE)).is_false()
	fx.end_turn()

	fx.begin_turn(Faction.AI)

	assert_bool(fx.state.protocols.has(Faction.AI, BLINDAGE)).is_true()
	assert_bool(fx.state.protocols.has(Faction.AI, REMPART_ARME)).is_false()
	assert_bool(fx.state.protocols.has(Faction.PLAYER, BLINDAGE)).is_false()
	assert_int(fx.last_events().size()).is_equal(1)


func test_no_research_in_progress_changes_nothing() -> void:
	var fx := _with_research(ResearchRules.NONE, 0)
	var before := fx.state.protocols.row_count()

	fx.begin_turn(Faction.PLAYER)

	assert_int(fx.state.protocols.row_count()).is_equal(before)


func test_prerequisite_is_the_previous_level_of_the_branch() -> void:
	var tree := CatalogFactory.standard().protocols

	assert_int(tree.prerequisite(BLINDAGE)).is_equal(REPOS)
	assert_int(tree.prerequisite(REPOS)).is_equal(-1)
	assert_int(tree.duration(REMPART_ARME)).is_equal(3)
	assert_int(tree.price(BLINDAGE)).is_equal(25)


func test_calendar_protocol_already_acquired_is_not_added_twice() -> void:
	var fx := _with_research(ResearchRules.NONE, 0)
	ResearchRules.acquire(fx.state, Faction.AI, BLINDAGE)
	GameStateSetup.set_turn(fx.state, 11)
	fx.begin_turn(Faction.PLAYER)
	fx.end_turn()
	var events: Array[PresentationEvent] = []

	ResearchRules.receive_calendar(fx.state, 12, CatalogFactory.standard().ai, events)

	assert_int(fx.state.protocols.row_count()).is_equal(1)
	assert_array(events).is_empty()
