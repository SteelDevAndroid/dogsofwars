extends GdUnitTestSuite

const ASSAUT := 1
const OUVRIER := 3


## 7 x 3: the player Ouvrier stands on a neutral level 2 node at (1, 1); the player
## holds a node at (0, 0); the AI holds two nodes and has an Assaut.
func _board() -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray([".......", ".......", "......."]))
	MapBuilder.unit(state, OUVRIER, Faction.PLAYER, 1, 1)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 6, 2)
	GameStateSetup.add_node(state, state.tile_index(1, 1), Faction.NONE, 2)
	GameStateSetup.add_node(state, state.tile_index(0, 0), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(5, 1), Faction.AI, 1)
	GameStateSetup.add_node(state, state.tile_index(6, 0), Faction.AI, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 3)
	return PipelineFixture.new(MapBuilder.ready(state))


func test_capture_takes_the_node_down_one_level_and_recomputes_the_territory() -> void:
	var fx := _board()

	assert_bool(fx.capture(0).permitted).is_true()

	var row := fx.state.nodes.find_row(0)
	assert_int(fx.state.nodes.owner_of(row)).is_equal(Faction.PLAYER)
	assert_int(fx.state.nodes.level_of(row)).is_equal(1)
	assert_int(fx.state.nodes._node_since_turn[row]).is_equal(3)
	assert_bool(fx.state.view().unit_acted(0)).is_true()
	assert_int(fx.state.map.owner_at(fx.state.tile_index(2, 2))).is_equal(Faction.PLAYER)
	var events := fx.last_events()
	assert_object(events[0]).is_instanceof(NodeCapturedEvent)
	assert_int((events[0] as NodeCapturedEvent).previous_owner).is_equal(Faction.NONE)
	var changed := events[1] as TileOwnersChangedEvent
	assert_array([changed.old_owner, changed.new_owner]).is_equal([Faction.NONE, Faction.PLAYER])


func test_validation_order_returns_the_first_failure() -> void:
	var fx := _board()
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	assert_str(fx.capture(1, Faction.AI).code).is_equal(Refusal.NO_INTENTION)
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)
	assert_str(fx.capture(1).code).is_equal(Refusal.UNKNOWN_UNIT)
	var assault := MapBuilder.unit(fx.state, ASSAUT, Faction.PLAYER, 3, 1)
	assert_str(fx.capture(assault).code).is_equal(Refusal.TYPE_NOT_CAPABLE)
	var off_node := MapBuilder.unit(fx.state, OUVRIER, Faction.PLAYER, 3, 2)
	assert_str(fx.capture(off_node).code).is_equal(Refusal.NOT_ON_A_NODE)
	var on_own := MapBuilder.unit(fx.state, OUVRIER, Faction.PLAYER, 0, 0)
	assert_str(fx.capture(on_own).code).is_equal(Refusal.NODE_ALREADY_OWNED)
	fx.capture(0)
	assert_str(fx.capture(0).code).is_equal(Refusal.ALREADY_ACTED)


func test_capturing_an_enemy_node_moves_its_tiles() -> void:
	var fx := _board()
	var worker := MapBuilder.unit(fx.state, OUVRIER, Faction.PLAYER, 5, 1)
	VisionService.setup(fx.state, StateFactory.vision_context(fx.state))

	var seen_by_node := fx.state.tile_index(3, 1)
	assert_int(VisionService.tile_state(fx.state, Faction.AI, seen_by_node)).is_equal(VisionService.VISIBLE)

	assert_bool(fx.capture(worker).permitted).is_true()

	assert_int(VisionService.tile_state(fx.state, Faction.AI, seen_by_node)).is_equal(VisionService.EXPLORED)
	assert_int(fx.state.nodes.owner_of(fx.state.nodes.find_row(2))).is_equal(Faction.PLAYER)
	assert_int(fx.state.map.owner_at(fx.state.tile_index(4, 1))).is_equal(Faction.PLAYER)
	assert_int(fx.state.map.owner_at(fx.state.tile_index(6, 1))).is_equal(Faction.AI)
	assert_bool(fx.state.factions.is_eliminated(Faction.AI)).is_false()


func test_taking_the_last_node_eliminates_the_faction_and_ends_the_match() -> void:
	var state := MapBuilder.state(PackedStringArray([".....", "....."]))
	var worker := MapBuilder.unit(state, OUVRIER, Faction.PLAYER, 4, 1)
	var enemy := MapBuilder.unit(state, ASSAUT, Faction.AI, 2, 0)
	GameStateSetup.add_node(state, state.tile_index(0, 0), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(4, 1), Faction.AI, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	var fx := PipelineFixture.new(MapBuilder.ready(state))

	assert_bool(fx.capture(worker).permitted).is_true()

	assert_bool(state.factions.is_eliminated(Faction.AI)).is_true()
	assert_int(state.view().unit_tile(enemy)).is_equal(-1)
	assert_int(state.header.value(HeaderSlice.END_STATUS)).is_equal(HeaderSlice.END_DOMINATION)
	var kinds := []
	for event in fx.last_events():
		kinds.append(event.get_script().get_global_name())
	assert_array(kinds).contains_exactly([&"NodeCapturedEvent", &"TileOwnersChangedEvent",
		&"UnitDestroyedEvent", &"FactionEliminatedEvent", &"MatchEndedEvent"])
	assert_str(fx.move(worker, state.tile_index(3, 1)).code).is_equal(Refusal.MATCH_OVER)


func test_capture_recomputes_the_view_and_round_trips_in_the_codec() -> void:
	var fx := _board()
	var before := FactionView.new(fx.state, Faction.PLAYER).unit_ids()

	fx.capture(0)

	assert_int(VisionService.tile_state(fx.state, Faction.PLAYER, fx.state.tile_index(3, 2))).is_equal(VisionService.VISIBLE)
	assert_array(before).is_equal(PackedInt32Array([0]))
	var decoded := CommandCodec.decode(CommandCodec.encode(CaptureCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, 4)))
	assert_int((decoded as CaptureCommand).unit_id).is_equal(4)
