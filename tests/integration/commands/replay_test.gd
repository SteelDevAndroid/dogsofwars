# Replay (ADR-0004 §10, GDD 23 rule 16): an initial state and the log of applied
# commands give back an equal state; a refusal during the replay is a divergence.
extends GdUnitTestSuite

const SEED := 1618
const STATES := 20
## One undo attempt every UNDO_ONE_IN moves.
const UNDO_ONE_IN := 3


## Plays every live player unit once to a tile of its range picked by the dice,
## with undo attempts; returns the fixture.
func _played(state: GameState, dice_seed: int) -> PipelineFixture:
	var fx := PipelineFixture.new(state)
	var counter := 0
	for unit_id in FactionView.new(state, Faction.PLAYER).unit_ids():
		var reach := fx.pipeline.check_move_range(FactionView.new(state, Faction.PLAYER), Faction.PLAYER, unit_id)
		if reach.is_empty():
			continue
		fx.move(unit_id, reach[GameState.hash32(dice_seed, counter) % reach.size()])
		counter += 1
		if GameState.hash32(dice_seed, counter) % UNDO_ONE_IN == 0:
			fx.undo_move()
		counter += 1
	return fx


func test_replay_of_the_log_gives_an_equal_state() -> void:
	var states := StateFactory.random_states(STATES, SEED)
	for k in states.size():
		var initial := states[k]
		GameStateSetup.set_phase(initial, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)
		var fx := _played(initial.duplicate_state(), SEED + k)

		var outcome := CommandReplay.replay(initial, fx.log, CatalogFactory.standard())

		assert_int(outcome.divergence).override_failure_message("seed %d state %d: %s" % [SEED, k, outcome.code]).is_equal(-1)
		assert_bool(outcome.state.equals(fx.state)).override_failure_message("seed %d state %d" % [SEED, k]).is_true()
		assert_bool(outcome.other_data).is_false()


func test_same_inputs_give_the_same_log_and_state() -> void:
	var first := StateFactory.random_states(1, SEED)[0]
	var second := StateFactory.random_states(1, SEED)[0]
	for state in [first, second]:
		GameStateSetup.set_phase(state, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)

	var a := _played(first, SEED)
	var b := _played(second, SEED)

	assert_array(b.state.to_bytes()).is_equal(a.state.to_bytes())
	assert_int(b.log.commands.size()).is_equal(a.log.commands.size())
	for k in a.log.commands.size():
		assert_array(b.log.commands[k]).is_equal(a.log.commands[k])


func test_refusal_during_the_replay_is_a_divergence() -> void:
	var state := StateFactory.minimal()
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)
	var fx := PipelineFixture.new(state.duplicate_state())
	fx.move(0, state.tile_index(2, 1))
	fx.log.append(MoveCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, 0, state.tile_index(3, 1)))

	var outcome := CommandReplay.replay(state, fx.log, CatalogFactory.standard())

	assert_int(outcome.divergence).is_equal(1)
	assert_str(outcome.code).is_equal(Refusal.ALREADY_MOVED)


func test_other_format_is_refused_and_other_data_flagged() -> void:
	var state := StateFactory.minimal()
	var log := CommandLog.new("other data")
	log.format_version = CommandLog.FORMAT_VERSION + 1

	var outcome := CommandReplay.replay(state, log, CatalogFactory.standard())

	assert_str(outcome.code).is_equal(CommandReplay.FORMAT_INCOMPATIBLE)
	assert_bool(outcome.other_data).is_true()
