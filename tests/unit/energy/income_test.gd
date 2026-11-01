extends GdUnitTestSuite

const ASSAUT := 1


## Player owns a level 1 and a level 3 node, the AI a level 2 node; one neutral node.
func _economy() -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray(["......", "......"]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 5, 1)
	GameStateSetup.add_node(state, state.tile_index(1, 0), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(2, 0), Faction.PLAYER, 3)
	GameStateSetup.add_node(state, state.tile_index(4, 1), Faction.AI, 2)
	GameStateSetup.add_node(state, state.tile_index(3, 1), Faction.NONE, 3)
	EnergyRules.initialize(state, CatalogFactory.standard().energy)
	return PipelineFixture.new(MapBuilder.ready(state), true)


func test_income_sums_the_owned_node_levels() -> void:
	var fx := _economy()
	var energy := CatalogFactory.standard().energy

	assert_int(EnergyRules.income(fx.state, Faction.PLAYER, energy)).is_equal(3 + 5)
	assert_int(EnergyRules.income(fx.state, Faction.AI, energy)).is_equal(4)
	assert_int(EnergyRules.stock(fx.state, Faction.PLAYER)).is_equal(6)


func test_begin_turn_pays_the_faction_only_and_publishes_the_change() -> void:
	var fx := _economy()

	fx.begin_turn(Faction.PLAYER)

	assert_int(EnergyRules.stock(fx.state, Faction.PLAYER)).is_equal(14)
	assert_int(EnergyRules.stock(fx.state, Faction.AI)).is_equal(6)
	var changed := fx.last_events()[1] as EnergyChangedEvent
	assert_int(changed.before).is_equal(6)
	assert_int(changed.after).is_equal(14)


func test_ai_is_paid_at_the_start_of_its_phase_and_the_player_does_not_see_it() -> void:
	var fx := _economy()
	fx.begin_turn(Faction.PLAYER)
	fx.end_turn()

	fx.begin_turn(Faction.AI)

	assert_int(EnergyRules.stock(fx.state, Faction.AI)).is_equal(10)
	assert_int(fx.last_events().size()).is_equal(1)
	assert_object(fx.last_events()[0]).is_instanceof(TurnStartedEvent)


func test_stock_is_capped_and_the_surplus_lost() -> void:
	var fx := _economy()
	var loaded := StatePayload.decoded_with(fx.state, &"_fac_energy", PackedInt32Array([95, 0]))
	VisionService.rebuild(loaded, StateFactory.vision_context(loaded))
	var capped := PipelineFixture.new(loaded, true)

	capped.begin_turn(Faction.PLAYER)

	assert_int(EnergyRules.stock(loaded, Faction.PLAYER)).is_equal(99)
	var full := StatePayload.decoded_with(loaded, &"_fac_energy", PackedInt32Array([99, 0]))
	assert_array(EnergyRules.consistency_errors(full, CatalogFactory.standard().energy)).is_empty()


func test_no_income_means_no_event_and_an_eliminated_faction_is_not_paid() -> void:
	var state := MapBuilder.state(PackedStringArray(["...."]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	var fx := PipelineFixture.new(MapBuilder.ready(state), true)
	var eliminated := StatePayload.decoded_with(_economy().state, &"_fac_eliminated", PackedByteArray([1, 0]))
	VisionService.rebuild(eliminated, StateFactory.vision_context(eliminated))

	fx.begin_turn(Faction.PLAYER)
	EnergyRules.pay_income(eliminated, Faction.PLAYER, CatalogFactory.standard().energy, [] as Array[PresentationEvent])

	assert_int(fx.last_events().size()).is_equal(1)
	assert_int(EnergyRules.stock(eliminated, Faction.PLAYER)).is_equal(6)


func test_stock_out_of_bounds_is_reported() -> void:
	var state := _economy().state

	var over := StatePayload.decoded_with(state, &"_fac_energy", PackedInt32Array([100, 0]))
	var under := StatePayload.decoded_with(state, &"_fac_energy", PackedInt32Array([0, -1]))

	assert_array(EnergyRules.consistency_errors(over, CatalogFactory.standard().energy)).has_size(1)
	assert_array(EnergyRules.consistency_errors(under, CatalogFactory.standard().energy)).has_size(1)
