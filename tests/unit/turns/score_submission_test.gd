extends GdUnitTestSuite

const ASSAUT := 1
const OUVRIER := 3


## 6 x 2 map, turn `turn`, player phase. Player Ouvrier 0 stands on the AI's only node at
## (3,0); the player also owns a level 2 node at (0,1). The AI has an Assaut at (5,1).
func _board(turn: int = 12) -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray(["......", "......"]))
	MapBuilder.unit(state, OUVRIER, Faction.PLAYER, 3, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 5, 1)
	GameStateSetup.add_node(state, state.tile_index(0, 1), Faction.PLAYER, 2)
	GameStateSetup.add_node(state, state.tile_index(3, 0), Faction.AI, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, turn)
	return PipelineFixture.new(MapBuilder.ready(state))


func _submissions(fx: PipelineFixture) -> Array:
	return fx.profile.calls.filter(func(effect: ProfileEffect) -> bool: return effect is SubmitScoreEffect)


func test_a_domination_submits_the_profile_score_with_the_bonus() -> void:
	var fx := _board(12)
	var weights := CatalogFactory.standard().score

	assert_bool(fx.capture(0).permitted).is_true()

	var calls := _submissions(fx)
	assert_int(calls.size()).is_equal(1)
	var submission := calls[0] as SubmitScoreEffect
	var expected := ScoreRules.decisive(fx.state, Faction.PLAYER, weights, weights.w_domination() * (GameState.MAX_TURN - 12))
	assert_int(submission.score).is_equal(expected)
	assert_int(submission.score).is_greater(ScoreRules.decisive(fx.state, Faction.PLAYER, weights))
	assert_array([submission.faction, submission.difficulty, submission.match_id]).is_equal([Faction.PLAYER, SubmitScoreEffect.DIFFICULTY_STANDARD, 0])
	assert_int(fx.profile.best_score(Faction.PLAYER, SubmitScoreEffect.DIFFICULTY_STANDARD)).is_equal(expected)


func test_the_end_of_turn_t_max_submits_the_score_without_bonus() -> void:
	var fx := _board(GameState.MAX_TURN)
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)

	assert_bool(fx.begin_turn(Faction.PLAYER).permitted).is_true()

	var calls := _submissions(fx)
	assert_int(calls.size()).is_equal(1)
	assert_int((calls[0] as SubmitScoreEffect).score).is_equal(ScoreRules.decisive(fx.state, Faction.PLAYER, CatalogFactory.standard().score))


func test_an_abandon_or_an_elimination_submits_nothing() -> void:
	var fx := _board()
	assert_bool(fx.abandon().permitted).is_true()
	assert_int(_submissions(fx).size()).is_equal(0)

	var lost := _board()
	TurnWrites.finish(lost.state, HeaderSlice.END_ELIMINATED)
	assert_object(ScoreRules.submission(lost.state, CatalogFactory.standard().score)).is_null()


func test_a_domination_at_turn_t_max_has_no_bonus() -> void:
	var state := _board(GameState.MAX_TURN).state
	TurnWrites.finish(state, HeaderSlice.END_DOMINATION)
	var weights := CatalogFactory.standard().score

	assert_int(ScoreRules.submission(state, weights).score).is_equal(ScoreRules.decisive(state, Faction.PLAYER, weights))


func test_the_profile_keeps_the_best_score_once_per_match() -> void:
	var port := RecordingProfilePort.new()

	port.apply(SubmitScoreEffect.new(1, 0, 0, 340))
	port.apply(SubmitScoreEffect.new(2, 0, 0, 410))
	port.apply(SubmitScoreEffect.new(3, 0, 0, 200))
	port.apply(SubmitScoreEffect.new(2, 0, 0, 900))

	assert_int(port.best_score(0, 0)).is_equal(410)
	assert_int(port.best_score(0, 1)).is_equal(-1)


func test_a_failed_profile_write_does_not_change_the_match() -> void:
	var fx := _board(12)
	fx.profile.fail_writes = true

	assert_bool(fx.capture(0).permitted).is_true()

	assert_int(fx.state.header.value(HeaderSlice.END_STATUS)).is_equal(HeaderSlice.END_DOMINATION)
	assert_int(fx.profile.best_score(Faction.PLAYER, 0)).is_equal(-1)


func test_every_end_at_turn_t_max_submits_a_score_even_a_loss_or_a_draw() -> void:
	for status in [HeaderSlice.END_TURNS_WON, HeaderSlice.END_TURNS_LOST, HeaderSlice.END_TURNS_DRAW, HeaderSlice.END_DOMINATION]:
		var state := _board(GameState.MAX_TURN).state
		TurnWrites.finish(state, status)

		assert_object(ScoreRules.submission(state, CatalogFactory.standard().score)).is_not_null()
	for status in [HeaderSlice.END_ELIMINATED, HeaderSlice.END_ABANDONED, HeaderSlice.END_NONE]:
		var state := _board(GameState.MAX_TURN).state
		TurnWrites.finish(state, status)

		assert_object(ScoreRules.submission(state, CatalogFactory.standard().score)).is_null()
