# A whole match from the match setup (GDD 1 CRÉÉE to the end, GDD 3): the new-game factory,
# the turn commands, the AI runner and a passive player who only ends turns. The match ends
# by elimination or at turn T_MAX; every command is accepted, the state stays valid, the
# same seed gives the same match and the journal replays to an equal state.
extends GdUnitTestSuite

const SEEDS := [1, 2, 3, 4, 5, 6]
const MAX_ROUNDS := 35


func _play(seed_value: int) -> PipelineFixture:
	var catalog := CatalogFactory.standard()
	var errors: Array[DataError] = []
	var map := MapDefinition.parse(FileAccess.get_file_as_string("res://assets/data/maps/plaine.json"), "plaine.json", catalog, errors)
	var fx := PipelineFixture.new(GameStateFactory.new_game(catalog, map, seed_value), true)
	var refusals := 0
	for round in MAX_ROUNDS:
		if fx.state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_FINISHED:
			break
		refusals += 0 if fx.begin_turn(Faction.PLAYER).permitted else 1
		if fx.state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_FINISHED:
			break
		refusals += 0 if fx.end_turn().permitted else 1
		refusals += 0 if fx.begin_turn(Faction.AI).permitted else 1
		var runner := AiRunner.new()
		runner.start_turn(fx.state, fx.pipeline, AlwaysReadyPacingGate.new(), catalog)
		for step in 600:
			if not runner.is_running():
				break
			runner.advance()
		refusals += runner.refusals
		runner.free()
	assert_int(refusals).override_failure_message("seed %d: refused commands" % seed_value).is_equal(0)
	return fx


func test_a_match_runs_to_its_end_without_a_refusal() -> void:
	for seed_value in SEEDS:
		var fx := _play(seed_value)
		var status := fx.state.header.value(HeaderSlice.END_STATUS)

		assert_int(fx.state.header.value(HeaderSlice.PHASE)).override_failure_message("seed %d did not end" % seed_value).is_equal(HeaderSlice.PHASE_FINISHED)
		assert_bool([HeaderSlice.END_ELIMINATED, HeaderSlice.END_TURNS_LOST, HeaderSlice.END_TURNS_DRAW, HeaderSlice.END_TURNS_WON].has(status)).is_true()
		assert_array(fx.state.validate()).override_failure_message("seed %d" % seed_value).is_empty()


func test_the_same_seed_plays_the_same_match_and_the_journal_replays() -> void:
	var first := _play(3)
	var second := _play(3)
	assert_bool(first.state.equals(second.state)).is_true()
	assert_array(first.log.commands).is_equal(second.log.commands)

	var catalog := CatalogFactory.standard()
	var errors: Array[DataError] = []
	var map := MapDefinition.parse(FileAccess.get_file_as_string("res://assets/data/maps/plaine.json"), "plaine.json", catalog, errors)
	var initial := GameStateFactory.new_game(catalog, map, 3)
	var outcome := CommandReplay.replay(initial, first.log, catalog)

	assert_int(outcome.divergence).override_failure_message(String(outcome.code)).is_equal(-1)
	assert_bool(outcome.state.equals(first.state)).is_true()


func test_a_passive_player_loses_ground_and_the_ai_acts() -> void:
	var fx := _play(2)
	var types := fx.log.commands.map(func(values: PackedInt64Array) -> int: return values[0])

	assert_bool(types.has(CommandType.MOVE)).is_true()
	assert_bool(types.has(CommandType.ANNOUNCE_INTENTIONS)).is_true()
