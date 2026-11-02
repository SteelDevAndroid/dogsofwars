extends GdUnitTestSuite

const ASSAUT := 1
const ECLAIREUR := 0


## 9 x 3 map at turn 4, player turn, nodes far enough apart for the territories not to
## overlap. Ids: 0 player level 1 at (1,1); 1 player level 2 at (6,1); 2 player level 3
## at (8,1). The Éclaireur at (0,0) sees up to x = 4.
func _board(energy: int = 40) -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray([".........", ".........", "........."]))
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 0, 0)
	GameStateSetup.add_node(state, state.tile_index(1, 1), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(6, 1), Faction.PLAYER, 2)
	GameStateSetup.add_node(state, state.tile_index(8, 1), Faction.PLAYER, 3)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 4)
	return PipelineFixture.new(MapBuilder.with_energy(MapBuilder.ready(state), energy, 0))


func test_upgrade_pays_the_price_raises_the_level_and_widens_the_territory() -> void:
	var fx := _board()
	var widened := fx.state.tile_index(3, 1)
	assert_int(fx.state.map.owner_at(widened)).is_equal(Faction.NONE)

	assert_bool(fx.upgrade_node(0).permitted).is_true()

	var row := fx.state.nodes.find_row(0)
	assert_int(fx.state.nodes.level_of(row)).is_equal(2)
	assert_int(fx.state.nodes.upgraded_turn_of(row)).is_equal(4)
	assert_int(EnergyRules.stock(fx.state, Faction.PLAYER)).is_equal(28)
	assert_int(fx.state.map.owner_at(widened)).is_equal(Faction.PLAYER)
	var events := fx.last_events()
	assert_array([(events[0] as EnergyChangedEvent).before, (events[0] as EnergyChangedEvent).after]).is_equal([40, 28])
	assert_array([(events[1] as NodeUpgradedEvent).node_id, (events[1] as NodeUpgradedEvent).level]).is_equal([0, 2])
	var changed := events[2] as TileOwnersChangedEvent
	assert_array([changed.old_owner, changed.new_owner]).is_equal([Faction.NONE, Faction.PLAYER])
	assert_int(fx.state.map._tile_change_cause[widened]).is_equal(MapSlice.CAUSE_UPGRADE)


func test_the_second_upgrade_costs_more_and_the_income_changes_next_turn() -> void:
	var fx := _board()
	var income_before := EnergyRules.income(fx.state, Faction.PLAYER, CatalogFactory.standard().energy)

	fx.upgrade_node(1)

	assert_int(EnergyRules.stock(fx.state, Faction.PLAYER)).is_equal(20)
	assert_int(fx.state.nodes.level_of(fx.state.nodes.find_row(1))).is_equal(3)
	assert_int(EnergyRules.income(fx.state, Faction.PLAYER, CatalogFactory.standard().energy)).is_equal(income_before + 1)


func test_validation_order_returns_the_first_failure() -> void:
	var fx := _board()
	assert_str(fx.upgrade_node(99).code).is_equal(Refusal.UNKNOWN_NODE)
	assert_str(fx.upgrade_node(2).code).is_equal(Refusal.MAX_LEVEL)
	fx.upgrade_node(1)
	assert_str(fx.upgrade_node(1).code).is_equal(Refusal.MAX_LEVEL)
	fx.upgrade_node(0)
	assert_str(fx.upgrade_node(0).code).is_equal(Refusal.ALREADY_UPGRADED)


func test_a_known_foreign_node_is_not_owned_and_an_unknown_one_is_unknown() -> void:
	var state := MapBuilder.state(PackedStringArray(["......"]))
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 0, 0)
	GameStateSetup.add_node(state, state.tile_index(2, 0), Faction.AI, 1)
	GameStateSetup.add_node(state, state.tile_index(5, 0), Faction.NONE, 1)
	GameStateSetup.add_node(state, state.tile_index(0, 0), Faction.PLAYER, 1)
	GameStateSetup.set_turn(state, 4)
	var fx := PipelineFixture.new(MapBuilder.with_energy(MapBuilder.ready(state), 40, 0))

	assert_str(fx.upgrade_node(0).code).is_equal(Refusal.NODE_NOT_OWNED)
	assert_str(fx.upgrade_node(1).code).is_equal(Refusal.UNKNOWN_NODE)
	assert_bool(fx.upgrade_node(1).equals(fx.upgrade_node(99))).is_true()


func test_a_node_acquired_this_turn_waits_for_the_next_one() -> void:
	var state := MapBuilder.state(PackedStringArray([".....", "....."]))
	var worker := MapBuilder.unit(state, 3, Faction.PLAYER, 3, 1)
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 0, 0)
	GameStateSetup.add_node(state, state.tile_index(0, 1), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(3, 1), Faction.AI, 2)
	# A second AI node, so that the capture does not eliminate it and end the match.
	GameStateSetup.add_node(state, state.tile_index(4, 0), Faction.AI, 1)
	GameStateSetup.set_turn(state, 4)
	var fx := PipelineFixture.new(MapBuilder.with_energy(MapBuilder.ready(state), 40, 0))
	fx.capture(worker)

	assert_str(fx.upgrade_node(1).code).is_equal(Refusal.NODE_ACQUIRED_THIS_TURN)
	fx.end_turn()
	fx.begin_turn(Faction.AI)
	fx.begin_turn(Faction.PLAYER)

	assert_bool(fx.upgrade_node(1).permitted).is_true()


func test_energy_is_checked_last_with_need_and_available_and_the_exact_price_is_enough() -> void:
	var short := _board(11)
	var exact := _board(12)

	var refused := short.upgrade_node(0)

	assert_str(refused.code).is_equal(Refusal.NOT_ENOUGH_ENERGY)
	assert_array(refused.params).is_equal(PackedInt64Array([12, 11]))
	assert_str(short.upgrade_node(2).code).is_equal(Refusal.MAX_LEVEL)
	assert_bool(exact.upgrade_node(0).permitted).is_true()
	assert_int(EnergyRules.stock(exact.state, Faction.PLAYER)).is_equal(0)


func test_no_unit_is_needed_and_an_enemy_standing_on_the_node_does_not_prevent_it() -> void:
	var state := MapBuilder.state(PackedStringArray(["....."]))
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 2, 0)
	GameStateSetup.add_node(state, state.tile_index(2, 0), Faction.PLAYER, 1)
	GameStateSetup.set_turn(state, 4)
	var fx := PipelineFixture.new(MapBuilder.with_energy(MapBuilder.ready(state), 40, 0))

	assert_bool(fx.upgrade_node(0).permitted).is_true()


func test_a_level_three_node_sees_farther_and_the_new_tiles_are_published() -> void:
	var state := MapBuilder.state(PackedStringArray(["............"]))
	GameStateSetup.add_node(state, state.tile_index(0, 0), Faction.PLAYER, 2)
	GameStateSetup.set_turn(state, 4)
	var fx := PipelineFixture.new(MapBuilder.with_energy(MapBuilder.ready(state), 40, 0))
	assert_int(VisionService.tile_state(fx.state, Faction.PLAYER, 3)).is_equal(VisionService.UNKNOWN)

	fx.upgrade_node(0)

	assert_int(VisionService.tile_state(fx.state, Faction.PLAYER, 3)).is_equal(VisionService.VISIBLE)
	var revealed := fx.last_events()[fx.last_events().size() - 1] as TilesRevealedEvent
	assert_array(revealed.revealed_tiles).is_equal(PackedInt32Array([3]))


func test_the_ai_upgrades_its_own_node_without_an_intention_and_not_the_players() -> void:
	var state := MapBuilder.state(PackedStringArray(["......"]))
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 5, 0)
	GameStateSetup.add_node(state, state.tile_index(0, 0), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(5, 0), Faction.AI, 1)
	GameStateSetup.set_turn(state, 4)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	var ai := PipelineFixture.new(MapBuilder.with_energy(MapBuilder.ready(state), 0, 30))

	assert_str(ai.upgrade_node(0, Faction.AI).code).is_equal(Refusal.UNKNOWN_NODE)
	assert_bool(ai.upgrade_node(1, Faction.AI).permitted).is_true()
	assert_int(EnergyRules.stock(ai.state, Faction.AI)).is_equal(18)


func test_an_upgrade_disarms_the_undo_is_saved_replayed_and_round_trips_in_the_codec() -> void:
	var initial := _board().state
	var fx := PipelineFixture.new(initial.duplicate_state())
	fx.move(0, fx.state.tile_index(1, 0))

	fx.upgrade_node(0)
	var outcome := CommandReplay.replay(initial, fx.log, CatalogFactory.standard())

	assert_str(fx.undo.reason).is_equal(Refusal.OTHER_ACTION_SINCE)
	assert_array(fx.post_commit.revisions).is_equal(PackedInt64Array([1, 2]))
	assert_int(outcome.divergence).is_equal(-1)
	assert_bool(outcome.state.equals(fx.state)).is_true()
	var decoded := CommandCodec.decode(CommandCodec.encode(UpgradeNodeCommand.new(Faction.AI, Command.EMITTER_AI, 6)))
	assert_array([(decoded as UpgradeNodeCommand).node_id, decoded.faction]).is_equal([6, Faction.AI])
	assert_object(CommandCodec.decode(PackedInt64Array([CommandType.UPGRADE_NODE, 0, 0]))).is_null()
