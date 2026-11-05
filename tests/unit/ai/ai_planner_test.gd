extends GdUnitTestSuite

const ECLAIREUR := 0
const ASSAUT := 1
const SENTINELLE := 4
const CHASSEUR := 5
const BASTION := 6


func _planner() -> AiPlanner:
	return AiPlanner.new()


func _budget() -> AiBudget:
	return AiBudget.new(CatalogFactory.standard().ai.planner("evals_per_call"))


## 10 x 3 plain, turn 5, the enemy phase. AI Sentinelle 0 at (4,2) sees (6,1); AI Chasseur 1
## at (2,1); player Assaut 2 at (6,1).
func _hunt_board() -> GameState:
	var state := MapBuilder.state(PackedStringArray(["..........", "..........", ".........."]))
	MapBuilder.unit(state, SENTINELLE, Faction.AI, 4, 2)
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 2, 1)
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 6, 1)
	GameStateSetup.add_node(state, state.tile_index(0, 0), Faction.AI, 1)
	GameStateSetup.add_node(state, state.tile_index(9, 2), Faction.PLAYER, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 5)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	return MapBuilder.ready(state)


func _frozen(state: GameState) -> GameState:
	return state.filtered_copy(Faction.AI)


func test_a_hunter_closes_in_on_a_visible_target() -> void:
	var state := _hunt_board()

	var command := _planner().plan_next(_frozen(state), CatalogFactory.standard(), _budget()) as MoveCommand

	assert_object(command).is_not_null()
	assert_int(command.unit_id).is_equal(1)
	assert_int(CombatRules.distance(10, command.tile, state.tile_index(6, 1))).is_equal(1)
	assert_array([command.faction, command.emitter]).is_equal([Faction.AI, Command.EMITTER_AI])


func test_a_target_out_of_sight_does_not_attract_the_hunter() -> void:
	var state := _hunt_board()
	UnitWrites.destroy(state, 0)  # the Sentinelle that saw it
	VisionService.recompute(state, StateFactory.vision_context(state))

	assert_object(_planner().plan_next(_frozen(state), CatalogFactory.standard(), _budget())).is_null()


func test_a_returning_hunter_heads_for_its_post() -> void:
	var state := _hunt_board()
	UnitWrites.move_to(state, 1, state.tile_index(8, 0))
	VisionService.recompute(state, StateFactory.vision_context(state))
	AiWrites.set_agent(state, 1, AiAgentsSlice.ROLE_RETURN, 0, state.tile_index(5, 0), AiAgentsSlice.NO_MOTIVE)

	var command := _planner().plan_next(_frozen(state), CatalogFactory.standard(), _budget()) as MoveCommand

	assert_object(command).is_not_null()
	assert_int(CombatRules.distance(10, command.tile, state.tile_index(5, 0))).is_less(CombatRules.distance(10, state.tile_index(8, 0), state.tile_index(5, 0)))


func test_a_capturer_walks_to_the_nearest_node_it_does_not_hold() -> void:
	var state := MapBuilder.state(PackedStringArray(["..........", "..........", ".........."]))
	MapBuilder.unit(state, SENTINELLE, Faction.AI, 3, 0)
	MapBuilder.unit(state, BASTION, Faction.AI, 1, 1)
	GameStateSetup.add_node(state, state.tile_index(4, 1), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(0, 0), Faction.AI, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 5)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	MapBuilder.ready(state)

	var command := _planner().plan_next(_frozen(state), CatalogFactory.standard(), _budget()) as MoveCommand

	assert_int(command.unit_id).is_equal(1)
	assert_int(CombatRules.distance(10, command.tile, state.tile_index(4, 1))).is_equal(2)  # one step closer


func test_the_upgrade_with_the_best_gain_per_energy_comes_first() -> void:
	var state := MapBuilder.state(PackedStringArray(["..........", "..........", ".........."]))
	MapBuilder.unit(state, SENTINELLE, Faction.AI, 0, 0)
	var cheap := GameStateSetup.add_node(state, state.tile_index(1, 0), Faction.AI, 1)
	GameStateSetup.add_node(state, state.tile_index(5, 2), Faction.AI, 2)
	GameStateSetup.set_turn(state, 5)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	state = MapBuilder.with_energy(MapBuilder.ready(state), 0, 40)

	var command := _planner().plan_next(_frozen(state), CatalogFactory.standard(), _budget()) as UpgradeNodeCommand

	assert_int(command.node_id).is_equal(cheap)


func test_no_upgrade_when_the_energy_is_short() -> void:
	var state := MapBuilder.state(PackedStringArray(["........"]))
	MapBuilder.unit(state, SENTINELLE, Faction.AI, 0, 0)
	GameStateSetup.add_node(state, state.tile_index(1, 0), Faction.AI, 1)
	GameStateSetup.set_turn(state, 5)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	state = MapBuilder.with_energy(MapBuilder.ready(state), 0, 5)

	assert_object(_planner().plan_next(_frozen(state), CatalogFactory.standard(), _budget())).is_null()


func test_passive_ai_plans_nothing_and_turn_t_max_only_upgrades() -> void:
	var state := _hunt_board()
	GameStateSetup.set_ai_passive(state, true)
	assert_object(_planner().plan_next(_frozen(state), CatalogFactory.standard(), _budget())).is_null()
	assert_object(_planner().plan_announcement(_frozen(state), CatalogFactory.standard())).is_null()

	GameStateSetup.set_ai_passive(state, false)
	GameStateSetup.set_turn(state, GameState.MAX_TURN)
	assert_object(_planner().plan_next(_frozen(state), CatalogFactory.standard(), _budget())).is_null()
	assert_object(_planner().plan_announcement(_frozen(state), CatalogFactory.standard())).is_null()


func test_the_planner_is_pure_and_deterministic() -> void:
	var state := _hunt_board()
	var frozen := _frozen(state)
	var before := frozen.duplicate_state()
	var counter := frozen.header.value(HeaderSlice.DRAW_COUNTER)

	var first := _planner().plan_next(frozen, CatalogFactory.standard(), _budget())
	var second := _planner().plan_next(frozen, CatalogFactory.standard(), _budget())

	assert_array(CommandCodec.encode(first)).is_equal(CommandCodec.encode(second))
	assert_bool(frozen.equals(before)).is_true()
	assert_int(frozen.header.value(HeaderSlice.DRAW_COUNTER)).is_equal(counter)


func test_an_exhausted_budget_plans_nothing() -> void:
	assert_object(_planner().plan_next(_frozen(_hunt_board()), CatalogFactory.standard(), AiBudget.new(0))).is_null()


func test_units_before_the_cursor_are_not_replanned() -> void:
	var state := _hunt_board()
	AiWrites.set_cursor(state, 3)
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 3, 2)
	VisionService.recompute(state, StateFactory.vision_context(state))
	AiWrites.set_cursor(state, 3)

	var command := _planner().plan_next(_frozen(state), CatalogFactory.standard(), _budget()) as MoveCommand

	# unit 1 comes before unit 3 in the order (same rank, lower id): it is not planned again
	assert_int(command.unit_id).is_equal(3)


func test_a_unit_that_has_moved_or_acted_stays_put() -> void:
	var state := _hunt_board()
	UnitWrites.set_moved(state, 1)

	assert_object(_planner().plan_next(_frozen(state), CatalogFactory.standard(), _budget())).is_null()


func test_a_large_state_margin_keeps_the_hunter_at_its_post() -> void:
	var docs := CatalogFactory.documents()
	docs["ai.json"]["planner"]["state_margin"] = 50
	var catalog := CatalogFactory.load_documents(docs).catalog

	assert_object(_planner().plan_next(_frozen(_hunt_board()), catalog, AiBudget.new(2000))).is_null()


func test_the_exposure_counts_the_player_units_that_can_reach_the_tile() -> void:
	var state := _hunt_board()
	var view := _frozen(state).view()
	var catalog := CatalogFactory.standard()

	# Assaut 2 at (6,1) reaches MVT 3 + range 1 = 4 tiles; its blow on a Chasseur (8 HP, DEF 0) is 6.
	assert_int(_planner()._exposure(view, 1, state.tile_index(2, 1), catalog)).is_equal(6)
	assert_int(_planner()._exposure(view, 1, state.tile_index(1, 1), catalog)).is_equal(0)


func test_the_leash_costs_points_per_tile_beyond_the_limit() -> void:
	var state := _hunt_board()
	UnitWrites.destroy(state, 2)
	AiWrites.set_agent(state, 1, AiAgentsSlice.ROLE_POST, 0, state.tile_index(0, 1), AiAgentsSlice.NO_MOTIVE)
	VisionService.recompute(state, StateFactory.vision_context(state))
	var frozen := _frozen(state)
	var catalog := CatalogFactory.standard()
	var near := state.tile_index(2, 1)
	var far := state.tile_index(8, 1)

	assert_int(_planner()._score(frozen, 1, near, near, near, catalog)).is_equal(0)  # within the leash of 4
	assert_int(_planner()._score(frozen, 1, far, far, far, catalog)).is_equal(-3 * (8 - 4))


func test_the_progress_toward_the_objective_is_rewarded_per_tile() -> void:
	var state := _hunt_board()
	UnitWrites.destroy(state, 2)
	VisionService.recompute(state, StateFactory.vision_context(state))
	var frozen := _frozen(state)
	var start := state.tile_index(2, 1)

	assert_int(_planner()._score(frozen, 1, state.tile_index(4, 1), start, state.tile_index(5, 1), CatalogFactory.standard())).is_equal(2 * 2)


func test_the_danger_weight_prices_the_exposure_in_the_score() -> void:
	var state := _hunt_board()
	var tile := state.tile_index(2, 1)

	assert_int(_planner()._score(_frozen(state), 1, tile, tile, tile, CatalogFactory.standard())).is_equal(-6 * 6)


## 9 x 5. A wall of water at x = 4 with one gap on the bottom row. AI Bastion at (2, 0); a neutral
## node at (5, 0), 3 tiles away as the crow flies but behind the water (path 6); another at (0, 4),
## 4 tiles away on the Bastion's side (path 4). Two Sentinelles let the AI see both nodes.
func test_a_capturer_heads_for_the_node_nearest_by_path_not_as_the_crow_flies() -> void:
	var state := MapBuilder.state(PackedStringArray([
		"....~....",
		"....~....",
		"....~....",
		"....~....",
		".........",
	]))
	MapBuilder.unit(state, BASTION, Faction.AI, 2, 0)
	MapBuilder.unit(state, SENTINELLE, Faction.AI, 6, 1)
	MapBuilder.unit(state, SENTINELLE, Faction.AI, 1, 3)
	GameStateSetup.add_node(state, state.tile_index(5, 0), Faction.NONE, 1)
	GameStateSetup.add_node(state, state.tile_index(0, 4), Faction.NONE, 1)
	GameStateSetup.add_node(state, state.tile_index(8, 4), Faction.AI, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 5)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	MapBuilder.ready(state)
	var frozen := _frozen(state)
	assert_int(frozen.view().node_ids().size()).is_equal(3)  # every node is known to the AI

	assert_int(_planner()._objective(frozen, 0, CatalogFactory.standard())).is_equal(state.tile_index(0, 4))


func test_a_hunter_goes_around_an_obstacle_instead_of_pressing_against_it() -> void:
	var state := MapBuilder.state(PackedStringArray([
		"...~.....",
		"...~.....",
		"...~.....",
		".........",
	]))
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 2, 0)
	GameStateSetup.add_node(state, state.tile_index(0, 3), Faction.AI, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 5)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	MapBuilder.ready(state)
	var frozen := _frozen(state)
	var catalog := CatalogFactory.standard()
	var objective := state.tile_index(5, 0)  # straight across the water
	var field := MovementRules.cost_field(frozen.view(), objective, catalog, true)

	# pressing against the water (2,0)->(2,1) is no progress by path; going down toward the gap is
	var against := _planner()._score(frozen, 0, state.tile_index(2, 1), state.tile_index(2, 0), objective, catalog, field)
	var around := _planner()._score(frozen, 0, state.tile_index(3, 3), state.tile_index(2, 0), objective, catalog, field)
	assert_int(around).is_greater(against)


func test_a_capturer_that_knows_no_node_explores_toward_the_nearest_unseen_tile() -> void:
	var state := MapBuilder.state(PackedStringArray(["................"]))
	MapBuilder.unit(state, BASTION, Faction.AI, 0, 0)
	GameStateSetup.add_node(state, state.tile_index(15, 0), Faction.NONE, 1)  # far in the fog
	GameStateSetup.set_turn(state, 5)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	MapBuilder.ready(state)
	var frozen := _frozen(state)
	assert_int(frozen.view().node_ids().size()).is_equal(0)

	var objective := _planner()._objective(frozen, 0, CatalogFactory.standard())

	var vision := CatalogFactory.standard().units.vision(BASTION)
	assert_int(objective).is_equal(state.tile_index(vision + 1, 0))  # the first tile past its view
	var command := _planner().plan_next(frozen, CatalogFactory.standard(), _budget()) as MoveCommand
	assert_int(command.tile).is_greater(state.tile_index(0, 0))
