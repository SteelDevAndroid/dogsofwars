extends GdUnitTestSuite


func _fixture() -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray(["..........", "..........", ".........."]))
	MapBuilder.unit(state, 1, Faction.PLAYER, 2, 1)
	MapBuilder.unit(state, 5, Faction.AI, 3, 1)
	MapBuilder.unit(state, 6, Faction.AI, 9, 0)
	GameStateSetup.add_node(state, state.tile_index(0, 0), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(9, 0), Faction.AI, 1)
	GameStateSetup.add_node(state, state.tile_index(2, 2), Faction.PLAYER, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 4)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	return PipelineFixture.new(MapBuilder.ready(state))


func test_an_attack_on_a_visible_unit_is_marked_with_its_visible_author() -> void:
	var fx := _fixture()
	fx.announce([[1, IntentionsSlice.TARGET_UNIT, 0, IntentionsSlice.ACTION_ATTACK, IntentionsSlice.MOTIVE_HUNT]])

	var markers := IntentionMarkers.visible_to_player(fx.state)

	assert_array(markers).is_equal([[0, IntentionsSlice.TARGET_UNIT, fx.state.tile_index(2, 1), fx.state.tile_index(3, 1), IntentionsSlice.MOTIVE_HUNT]])


func test_the_author_in_the_fog_is_not_given_away() -> void:
	var fx := _fixture()
	UnitWrites.move_to(fx.state, 1, fx.state.tile_index(4, 1))
	fx.announce([[1, IntentionsSlice.TARGET_UNIT, 0, IntentionsSlice.ACTION_ATTACK, IntentionsSlice.MOTIVE_HUNT]])
	UnitWrites.move_to(fx.state, 0, fx.state.tile_index(0, 2))
	VisionService.recompute(fx.state, fx.rules.vision)

	assert_array(IntentionMarkers.visible_to_player(fx.state)).is_empty()  # target out of view: no marker at all


func test_a_capture_of_a_node_out_of_view_is_still_marked() -> void:
	var fx := _fixture()
	# the Bastion at (9,0) cannot capture its own node; a node of the player seen from afar:
	NodeWrites.capture(fx.state, 2, Faction.AI)
	NodeWrites.capture(fx.state, 2, Faction.PLAYER)
	AiWrites.announce_intention(fx.state, 2, fx.state.tile_index(9, 0), IntentionsSlice.TARGET_NODE, 2, fx.state.tile_index(2, 2),
			IntentionsSlice.ACTION_CAPTURE, IntentionsSlice.MOTIVE_CAPTURE)

	var markers := IntentionMarkers.visible_to_player(fx.state)

	assert_int(markers.size()).is_equal(1)
	assert_int(markers[0][3]).is_equal(-1)  # the Bastion is far: its tile is not shown


func test_settled_intentions_are_not_marked() -> void:
	var fx := _fixture()
	fx.announce([[1, IntentionsSlice.TARGET_UNIT, 0, IntentionsSlice.ACTION_ATTACK, IntentionsSlice.MOTIVE_HUNT]])
	AiWrites.settle_intention(fx.state, 0, IntentionsSlice.STATUS_CANCELLED, IntentionsSlice.REASON_TARGET_MOVED)

	assert_array(IntentionMarkers.visible_to_player(fx.state)).is_empty()


func test_an_attack_on_a_unit_the_player_no_longer_sees_is_not_marked() -> void:
	var state := MapBuilder.state(PackedStringArray(["..........", "..........", ".........."]))
	MapBuilder.unit(state, 1, Faction.PLAYER, 2, 1)
	MapBuilder.unit(state, 5, Faction.AI, 3, 1)
	GameStateSetup.set_turn(state, 4)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	var fx := PipelineFixture.new(MapBuilder.ready(state))
	fx.announce([[1, IntentionsSlice.TARGET_UNIT, 0, IntentionsSlice.ACTION_ATTACK, IntentionsSlice.MOTIVE_HUNT]])
	assert_int(IntentionMarkers.visible_to_player(state).size()).is_equal(1)

	UnitWrites.move_to(state, 0, state.tile_index(9, 2))
	VisionService.recompute(state, fx.rules.vision)

	assert_array(IntentionMarkers.visible_to_player(state)).is_empty()
