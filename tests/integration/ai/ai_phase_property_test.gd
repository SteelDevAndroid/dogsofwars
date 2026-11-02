# One whole AI phase on random states (GDD 9, ADR-0005): the runner finishes, the planner
# never gets a command refused, the state stays valid, nothing is drawn, a second run
# from a copy gives the same state and log, the log replays to an equal state, and a stop
# after any command followed by a resume gives the same phase (AC-IA33).
extends GdUnitTestSuite

const SEED := 9100
const STATES := 120
const MIN_PHASES_WITH_AI_COMMANDS := 20
const MAX_STEPS := 600


func _fixture(state: GameState) -> PipelineFixture:
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	return PipelineFixture.new(state)


func _finish(runner: AiRunner) -> void:
	for k in MAX_STEPS:
		if not runner.is_running():
			return
		runner.advance()
	assert_bool(runner.is_running()).override_failure_message("the runner did not finish in %d steps" % MAX_STEPS).is_false()


func test_a_phase_on_random_states_is_valid_deterministic_and_replayable() -> void:
	var with_commands := 0
	var states := StateFactory.random_states(STATES, SEED)
	for k in states.size():
		var context := "seed %d state %d" % [SEED, k]
		var initial := states[k]
		GameStateSetup.set_phase(initial, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
		var first := _fixture(initial.duplicate_state())
		var second := _fixture(initial.duplicate_state())
		var counter := initial.header.value(HeaderSlice.DRAW_COUNTER)
		var runner := AiRunner.new()
		runner.start_turn(first.state, first.pipeline, AlwaysReadyPacingGate.new(), CatalogFactory.standard())
		_finish(runner)
		var again := AiRunner.new()
		again.start_turn(second.state, second.pipeline, AlwaysReadyPacingGate.new(), CatalogFactory.standard())
		_finish(again)

		assert_int(runner.refusals).override_failure_message(context).is_equal(0)
		assert_array(first.state.validate()).override_failure_message(context).is_empty()
		assert_int(first.state.header.value(HeaderSlice.DRAW_COUNTER)).override_failure_message(context).is_equal(counter)
		assert_bool(first.state.equals(second.state)).override_failure_message(context).is_true()
		assert_array(first.log.commands).override_failure_message(context).is_equal(second.log.commands)
		var replay := CommandReplay.replay(initial, first.log, CatalogFactory.standard())
		assert_int(replay.divergence).override_failure_message("%s: %s" % [context, replay.code]).is_equal(-1)
		assert_bool(replay.state.equals(first.state)).override_failure_message(context).is_true()
		if first.log.commands.size() > 0:
			with_commands += 1
		runner.free()
		again.free()
	assert_int(with_commands).override_failure_message("too few phases with AI commands (%d): vacuous" % with_commands).is_greater(MIN_PHASES_WITH_AI_COMMANDS)


func test_a_stop_after_any_command_then_a_resume_gives_the_same_phase_on_random_states() -> void:
	var states := StateFactory.random_states(25, SEED + 1)
	var checked := 0
	for k in states.size():
		var initial := states[k]
		GameStateSetup.set_phase(initial, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
		var reference := _fixture(initial.duplicate_state())
		var runner := AiRunner.new()
		runner.start_turn(reference.state, reference.pipeline, AlwaysReadyPacingGate.new(), CatalogFactory.standard())
		_finish(runner)
		runner.free()
		for stop in reference.log.commands.size():
			var fx := _fixture(initial.duplicate_state())
			var first := AiRunner.new()
			first.start_turn(fx.state, fx.pipeline, AlwaysReadyPacingGate.new(), CatalogFactory.standard())
			while fx.log.commands.size() < stop + 1 and first.is_running():
				first.advance()
			first.cancel()
			first.free()
			var second := AiRunner.new()
			second.resume(fx.state, fx.pipeline, AlwaysReadyPacingGate.new(), CatalogFactory.standard())
			_finish(second)
			second.free()
			checked += 1
			assert_bool(fx.state.equals(reference.state)).override_failure_message("seed %d state %d stop %d" % [SEED + 1, k, stop]).is_true()
	assert_int(checked).override_failure_message("no stop point checked: vacuous").is_greater(10)
