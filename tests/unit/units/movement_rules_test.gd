extends GdUnitTestSuite

const ECLAIREUR := 0
const ASSAUT := 1
const REMPART := 2
const SENTINELLE := 4
const SEED := 2718
## Every unit, every tile: one validation each, so fewer states than the other properties.
const STATES := 10


func _validate(state: GameState, faction: int, unit_id: int, x: int, y: int) -> ValidationResult:
	var catalog := CatalogFactory.standard()
	var rules := RuleTable.standard(catalog, VisionContext.for_map(catalog, state))
	return rules.validate(FactionView.new(state, faction), MoveCommand.new(faction, Command.EMITTER_PLAYER, unit_id, state.tile_index(x, y)))


func _code(state: GameState, unit_id: int, x: int, y: int) -> StringName:
	return _validate(state, Faction.PLAYER, unit_id, x, y).code


func test_cost_is_the_sum_of_entry_costs() -> void:
	var state := MapBuilder.state(PackedStringArray(["..f..", "....."]))
	var unit := MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.ready(state)

	assert_str(_code(state, unit, 2, 0)).is_empty()
	assert_str(_code(state, unit, 3, 1)).is_empty()
	assert_str(_code(state, unit, 4, 0)).is_equal(Refusal.OUT_OF_RANGE)


func test_too_far_is_out_of_range() -> void:
	var state := MapBuilder.state(PackedStringArray(["fff..", "fff.."]))
	var unit := MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.ready(state)

	assert_str(_code(state, unit, 1, 0)).is_empty()
	assert_str(_code(state, unit, 3, 0)).is_equal(Refusal.OUT_OF_RANGE)
	assert_str(_code(state, unit, 0, 5)).is_equal(Refusal.OUT_OF_RANGE)


func test_guaranteed_step_enters_a_costly_neighbour_once() -> void:
	var state := MapBuilder.state(PackedStringArray([".^...", "....."]))
	var unit := MapBuilder.unit(state, REMPART, Faction.PLAYER, 0, 0)
	var fixture := PipelineFixture.new(MapBuilder.ready(state))

	assert_bool(fixture.move(unit, state.tile_index(1, 0)).permitted).is_true()
	assert_int(state.view().unit_tile(unit)).is_equal(state.tile_index(1, 0))
	assert_str(fixture.move(unit, state.tile_index(2, 0)).code).is_equal(Refusal.ALREADY_MOVED)


func test_water_occupied_and_off_map_destinations() -> void:
	var state := MapBuilder.state(PackedStringArray([".~...", "....."]))
	var unit := MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 1)
	MapBuilder.ready(state)

	assert_str(_code(state, unit, 1, 0)).is_equal(Refusal.TILE_BLOCKED)
	assert_str(_code(state, unit, 0, 1)).is_equal(Refusal.TILE_BLOCKED)
	assert_str(_validate(state, Faction.PLAYER, unit, 0, 0).code).is_equal(Refusal.TILE_BLOCKED)
	var off_map := MoveCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, unit, state.tile_count())
	var catalog := CatalogFactory.standard()
	var rules := RuleTable.standard(catalog, VisionContext.for_map(catalog, state))
	assert_str(rules.validate(FactionView.new(state, Faction.PLAYER), off_map).code).is_equal(Refusal.OUT_OF_RANGE)


func test_no_passing_through_a_friend_nor_cutting_a_corner() -> void:
	var walled := MapBuilder.state(PackedStringArray([".~.", "~..", "..."]))
	var corner_unit := MapBuilder.unit(walled, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.ready(walled)
	var corridor := MapBuilder.state(PackedStringArray(["...", "~~~"]))
	var runner := MapBuilder.unit(corridor, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(corridor, ASSAUT, Faction.PLAYER, 1, 0)
	MapBuilder.ready(corridor)

	assert_str(_code(walled, corner_unit, 1, 1)).is_equal(Refusal.OUT_OF_RANGE)
	assert_str(_code(corridor, runner, 2, 0)).is_equal(Refusal.OUT_OF_RANGE)


func test_unit_checks_come_first_in_order() -> void:
	var state := MapBuilder.state(PackedStringArray(["....."]))
	var dormant := MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0, true)
	var sentinel := MapBuilder.unit(state, SENTINELLE, Faction.PLAYER, 2, 0)
	var enemy := MapBuilder.unit(state, ASSAUT, Faction.AI, 4, 0)
	MapBuilder.ready(state)

	assert_str(_code(state, dormant, 1, 0)).is_equal(Refusal.UNIT_ASLEEP)
	assert_str(_code(state, sentinel, 3, 0)).is_equal(Refusal.UNIT_IMMOBILE)
	assert_str(_code(state, enemy, 3, 0)).is_equal(Refusal.UNKNOWN_UNIT)
	assert_str(_code(state, 99, 3, 0)).is_equal(Refusal.UNKNOWN_UNIT)


func test_hidden_enemy_does_not_block_the_validation() -> void:
	var state := MapBuilder.state(PackedStringArray(["......"]))
	var unit := MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 3, 0)
	MapBuilder.ready(state)

	assert_str(_code(state, unit, 3, 0)).is_empty()


func test_move_range_matches_validate_on_random_states() -> void:
	var catalog := CatalogFactory.standard()
	for state in StateFactory.random_states(STATES, SEED):
		var rules := RuleTable.standard(catalog, VisionContext.for_map(catalog, state))
		for faction in StateFactory.FACTIONS:
			var view := FactionView.new(state, faction)
			for unit_id in view.unit_ids():
				var reach := rules.check_move_range(view, faction, unit_id)
				for tile in state.tile_count():
					var permitted := rules.validate(view, MoveCommand.new(faction, Command.EMITTER_PLAYER, unit_id, tile)).permitted
					assert_bool(reach.has(tile)).override_failure_message(
						"seed %d faction %d unit %d tile %d" % [SEED, faction, unit_id, tile]).is_equal(permitted)
