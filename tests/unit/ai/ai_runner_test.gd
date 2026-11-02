extends GdUnitTestSuite

const ASSAUT := 1
const SENTINELLE := 4
const CHASSEUR := 5
const BASTION := 6


## 10 x 3, turn 5, the enemy phase just begun. AI Sentinelle 0 at (4,2) (sees far), Chasseur
## 1 at (3,1), Bastion 2 at (1,1); player Assaut 3 at (6,1); player node 0 at (9,2), AI node
## 1 at (0,0), neutral node 2 at (4,0). An intention announced last turn: Chasseur 1 ...
func _fixture() -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray(["..........", "..........", ".........."]))
	MapBuilder.unit(state, SENTINELLE, Faction.AI, 4, 2)
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 5, 1)
	MapBuilder.unit(state, BASTION, Faction.AI, 1, 1)
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 6, 1)
	GameStateSetup.add_node(state, state.tile_index(9, 2), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(0, 0), Faction.AI, 1)
	GameStateSetup.add_node(state, state.tile_index(4, 0), Faction.NONE, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 4)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	var fx := PipelineFixture.new(MapBuilder.ready(state))
	# last turn's announcement: the Chasseur strikes the Assaut this turn
	assert_bool(fx.announce([[1, IntentionsSlice.TARGET_UNIT, 3, IntentionsSlice.ACTION_ATTACK, IntentionsSlice.MOTIVE_HUNT]]).permitted).is_true()
	GameStateSetup.set_turn(fx.state, 5)
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	return fx


func _run(fx: PipelineFixture, steps: int = 500) -> AiRunner:
	var runner := AiRunner.new()
	var finished := [false]
	runner.on_turn_finished = func() -> void: finished[0] = true
	runner.start_turn(fx.state, fx.pipeline, AlwaysReadyPacingGate.new(), CatalogFactory.standard())
	for k in steps:
		if not runner.is_running():
			break
		runner.advance()
	assert_bool(finished[0]).is_true()
	return runner


func test_a_whole_phase_runs_through_the_pipeline_without_a_refusal() -> void:
	var fx := _fixture()

	var runner := _run(fx)

	assert_int(runner.refusals).is_equal(0)
	assert_bool(runner.is_running()).is_false()
	assert_int(runner.worst_advance_usec).is_greater(0)  # the spike's measure of the worst frame
	assert_int(runner.worst_advance_usec).is_greater_equal(runner.last_advance_usec)
	assert_int(fx.state.intentions.status_of(0)).is_equal(IntentionsSlice.STATUS_EXECUTED)
	assert_bool(fx.state.view().unit_acted(1)).is_true()
	assert_array(fx.state.validate()).is_empty()
	var types := fx.log.commands.map(func(values: PackedInt64Array) -> int: return values[0])
	assert_int(types[1]).is_equal(CommandType.EXECUTE_INTENTION)
	assert_int(types[-1]).is_equal(CommandType.ANNOUNCE_INTENTIONS)
	runner.free()


## ADR-0005 §4 (review 2026-11-01, B3): the phase makes no more planner calls than the
## structural bound the maps are checked against (3 AI units, 3 nodes here).
func test_a_phase_stays_within_the_planner_call_bound() -> void:
	var fx := _fixture()
	var runner := AiRunner.new()
	runner.start_turn(fx.state, fx.pipeline, AlwaysReadyPacingGate.new(), CatalogFactory.standard())
	var calls := 0

	for k in 500:
		if not runner.is_running():
			break
		if runner.step == AiRunner.Step.MOVING:
			calls += 1
		runner.advance()

	assert_bool(runner.is_running()).is_false()
	assert_int(calls).is_greater(0)
	assert_int(calls).is_less_equal(AiPlanner.max_calls_per_turn(3, 3))
	runner.free()


func test_the_runner_waits_for_the_pacing_gate_and_submits_one_command_per_call() -> void:
	var fx := _fixture()
	var gate := AlwaysReadyPacingGate.new()
	var runner := AiRunner.new()
	runner.start_turn(fx.state, fx.pipeline, gate, CatalogFactory.standard())
	var before := fx.log.commands.size()

	runner.advance()

	assert_int(fx.log.commands.size()).is_equal(before + 1)
	runner.free()


func test_a_stop_after_any_command_then_a_resume_gives_the_same_phase() -> void:
	var reference := _fixture()
	_run(reference).free()
	var total := reference.log.commands.size()

	for stop in range(0, total):
		var fx := _fixture()
		var first := AiRunner.new()
		first.start_turn(fx.state, fx.pipeline, AlwaysReadyPacingGate.new(), CatalogFactory.standard())
		while fx.log.commands.size() < stop + 1 and first.is_running():  # +1: the announcement of the setup
			first.advance()
		first.cancel()
		first.free()
		var second := _run_again(fx)
		assert_bool(fx.state.equals(reference.state)).override_failure_message("stop after command %d" % stop).is_true()
		second.free()


func _run_again(fx: PipelineFixture) -> AiRunner:
	var runner := AiRunner.new()
	runner.resume(fx.state, fx.pipeline, AlwaysReadyPacingGate.new(), CatalogFactory.standard())
	for k in 500:
		if not runner.is_running():
			break
		runner.advance()
	return runner


func test_a_passive_ai_does_nothing_but_finish_the_phase() -> void:
	var fx := _fixture()
	GameStateSetup.set_ai_passive(fx.state, true)
	var before := fx.log.commands.size()

	var runner := _run(fx)

	# the intention announced earlier is still executed; no move, no announcement
	assert_array(fx.log.commands.slice(before).map(func(values: PackedInt64Array) -> int: return values[0])).is_equal([CommandType.EXECUTE_INTENTION])
	runner.free()


func test_the_runner_stops_when_the_match_ends() -> void:
	var fx := _fixture()
	var runner := AiRunner.new()
	runner.start_turn(fx.state, fx.pipeline, AlwaysReadyPacingGate.new(), CatalogFactory.standard())
	TurnWrites.finish(fx.state, HeaderSlice.END_ABANDONED)

	runner.advance()

	assert_bool(runner.is_running()).is_false()
	runner.free()


func test_the_whole_phase_replays_to_an_equal_state() -> void:
	var fx := _fixture()
	var initial := fx.state.duplicate_state()
	# rebuild the log from the same initial state: replay the log of this fixture
	var log_before := fx.log.commands.size()
	_run(fx).free()
	var tail := CommandLog.new(fx.log.content_hash)
	for k in range(log_before, fx.log.commands.size()):
		tail.commands.append(fx.log.commands[k])
	GameStateSetup.set_turn(initial, 5)

	var outcome := CommandReplay.replay(initial, tail, CatalogFactory.standard())

	assert_int(outcome.divergence).override_failure_message(String(outcome.code)).is_equal(-1)


func test_ordinary_moves_come_before_the_announcement() -> void:
	var state := MapBuilder.state(PackedStringArray(["..........", "..........", ".........."]))
	MapBuilder.unit(state, SENTINELLE, Faction.AI, 3, 2)
	MapBuilder.unit(state, BASTION, Faction.AI, 1, 1)
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 9, 2)
	GameStateSetup.add_node(state, state.tile_index(9, 1), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(0, 0), Faction.AI, 1)
	GameStateSetup.add_node(state, state.tile_index(4, 0), Faction.NONE, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 5)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	var fx := PipelineFixture.new(MapBuilder.ready(state))

	_run(fx).free()

	var types := fx.log.commands.map(func(values: PackedInt64Array) -> int: return values[0])
	assert_array(types).is_equal([CommandType.MOVE, CommandType.ANNOUNCE_INTENTIONS])
	assert_int(fx.state.ai_cursor.cursor()).is_equal(1)
