extends GdUnitTestSuite

const ASSAUT := 1
const ECLAIREUR := 0


## 6 x 2 map at the end of turn T_MAX's enemy phase. The player owns `player_tiles`
## tiles and one level 2 node; the AI owns one level 1 node; one unit each.
func _last_enemy_phase(player_tiles: int) -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray(["......", "......"]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 5, 1)
	GameStateSetup.add_node(state, state.tile_index(0, 1), Faction.PLAYER, 2)
	GameStateSetup.add_node(state, state.tile_index(5, 0), Faction.AI, 1)
	for tile in player_tiles:
		GameStateSetup.set_tile_owner(state, tile, Faction.PLAYER)
	GameStateSetup.set_tile_owner(state, state.tile_index(5, 0), Faction.AI)
	GameStateSetup.set_turn(state, GameState.MAX_TURN)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	return PipelineFixture.new(MapBuilder.ready(state))


func _score(state: GameState, faction: int) -> int:
	return ScoreRules.decisive(state, faction, CatalogFactory.standard().score)


func test_decisive_score_is_formula_one_without_fragments() -> void:
	var fx := _last_enemy_phase(3)

	# T 3, N 1, ΣL 2, P 0, U 1: 1*3 + 8*1 + 4*2 + 0 + 2*1.
	assert_int(_score(fx.state, Faction.PLAYER)).is_equal(21)
	# T 1, N 1, ΣL 1, U 1: 1 + 8 + 4 + 2.
	assert_int(_score(fx.state, Faction.AI)).is_equal(15)


func test_units_count_up_to_the_cap_and_protocols_weigh_zero() -> void:
	var state := StateFactory.with_units(25)
	ResearchRules.acquire(state, Faction.PLAYER, 0)

	assert_int(_score(state, Faction.PLAYER)).is_equal(2 * 20)


func test_end_of_turn_t_max_ends_the_match_with_the_higher_score() -> void:
	var fx := _last_enemy_phase(3)

	assert_bool(fx.begin_turn(Faction.PLAYER).permitted).is_true()

	assert_int(fx.state.turn()).is_equal(GameState.MAX_TURN)
	assert_int(fx.state.header.value(HeaderSlice.PHASE)).is_equal(HeaderSlice.PHASE_FINISHED)
	assert_int(fx.state.header.value(HeaderSlice.END_STATUS)).is_equal(HeaderSlice.END_TURNS_WON)
	assert_int((fx.last_events()[0] as MatchEndedEvent).status).is_equal(HeaderSlice.END_TURNS_WON)
	assert_bool(fx.state.view().unit_moved(0)).is_false()


func test_lower_score_loses_and_a_tie_is_a_draw() -> void:
	# Player with no tile: 8 + 4*2 + 2 = 18; AI with 5 tiles: 5 + 8 + 4 + 2 = 19.
	var lost := _last_enemy_phase(0)
	for tile in [1, 2, 3, 4]:
		GameStateSetup.set_tile_owner(lost.state, lost.state.tile_index(tile, 1), Faction.AI)
	# Player with 1 tile and a level 1 node: 1 + 8 + 4 + 2 = 15 = AI.
	var even := _last_enemy_phase(1)
	var loaded := StatePayload.decoded_with(even.state, &"_node_level", PackedInt32Array([1, 1]))
	VisionService.rebuild(loaded, StateFactory.vision_context(loaded))
	var tie := PipelineFixture.new(loaded)

	lost.begin_turn(Faction.PLAYER)
	tie.begin_turn(Faction.PLAYER)

	assert_array([_score(lost.state, Faction.PLAYER), _score(lost.state, Faction.AI)]).is_equal([18, 19])
	assert_int(lost.state.header.value(HeaderSlice.END_STATUS)).is_equal(HeaderSlice.END_TURNS_LOST)
	assert_array([_score(loaded, Faction.PLAYER), _score(loaded, Faction.AI)]).is_equal([15, 15])
	assert_int(loaded.header.value(HeaderSlice.END_STATUS)).is_equal(HeaderSlice.END_TURNS_DRAW)


func test_every_command_is_refused_once_the_match_is_over() -> void:
	var fx := _last_enemy_phase(3)
	fx.begin_turn(Faction.PLAYER)
	var revision := fx.state.revision()

	assert_str(fx.begin_turn(Faction.PLAYER).code).is_equal(Refusal.MATCH_OVER)
	assert_str(fx.move(0, fx.state.tile_index(1, 0)).code).is_equal(Refusal.MATCH_OVER)
	assert_str(fx.end_turn().code).is_equal(Refusal.MATCH_OVER)
	assert_int(fx.state.revision()).is_equal(revision)


func test_match_end_is_saved_and_replays() -> void:
	var initial := _last_enemy_phase(3).state
	var fx := PipelineFixture.new(initial.duplicate_state())

	fx.begin_turn(Faction.PLAYER)
	var outcome := CommandReplay.replay(initial, fx.log, CatalogFactory.standard())

	assert_array(fx.post_commit.revisions).is_equal(PackedInt64Array([1]))
	assert_int(outcome.divergence).is_equal(-1)
	assert_bool(outcome.state.equals(fx.state)).is_true()


func test_domination_bonus_must_stay_under_a_fifth_of_a_fragment() -> void:
	var docs := CatalogFactory.documents()
	docs["score.json"]["w_domination"] = 13

	var result := CatalogFactory.load_documents(docs)

	assert_str(str(result.errors[0])).is_equal(
		"score.json: w_domination: a fragment must be worth at least 5 turns of domination bonus (w_d <= w_f / 5)")


func test_destroyed_units_do_not_score() -> void:
	var fx := _last_enemy_phase(3)
	var before := _score(fx.state, Faction.PLAYER)

	UnitWrites.destroy(fx.state, 0)

	assert_int(_score(fx.state, Faction.PLAYER)).is_equal(before - 2)


func test_the_last_turn_is_still_played() -> void:
	var fx := _last_enemy_phase(3)
	GameStateSetup.set_turn(fx.state, GameState.MAX_TURN - 1)

	fx.begin_turn(Faction.PLAYER)

	assert_int(fx.state.turn()).is_equal(GameState.MAX_TURN)
	assert_int(fx.state.header.value(HeaderSlice.PHASE)).is_equal(HeaderSlice.PHASE_PLAYER)
	assert_int(fx.state.header.value(HeaderSlice.END_STATUS)).is_equal(HeaderSlice.END_NONE)
