extends GdUnitTestSuite

const ASSAUT := 1
const SENTINELLE := 4
const CHASSEUR := 5
const BASTION := 6


func _plan(state: GameState) -> AnnounceIntentionsCommand:
	return AiPlanner.new().plan_announcement(state.filtered_copy(Faction.AI), CatalogFactory.standard()) as AnnounceIntentionsCommand


func _fixture(state: GameState) -> PipelineFixture:
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	return PipelineFixture.new(MapBuilder.ready(state))


## 8 x 3, turn 4. AI Chasseur 0 at (2,1) next to the player Assaut 1 at (3,1); AI
## Sentinelle 2 at (0,0); AI Bastion 3 on the player node 0 at (6,1); the player's second
## node 1 at (7,2) (so node 0 is not the last one).
func _board() -> GameState:
	var state := MapBuilder.state(PackedStringArray(["........", "........", "........"]))
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 2, 1)
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 3, 1)
	MapBuilder.unit(state, SENTINELLE, Faction.AI, 0, 0)
	MapBuilder.unit(state, BASTION, Faction.AI, 6, 1)
	GameStateSetup.add_node(state, state.tile_index(6, 1), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(7, 2), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(0, 2), Faction.AI, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 4)
	return state


func test_the_announcement_is_accepted_by_the_pipeline_and_stores_the_intentions() -> void:
	var fx := _fixture(_board())
	var command := _plan(fx.state)

	assert_bool(fx.pipeline.submit(command).permitted).is_true()

	var slice := fx.state.intentions
	assert_int(slice.row_count()).is_equal(2)
	assert_array([slice.author_of(0), slice.action_of(0), slice.target_id_of(0), slice.motive_of(0)]).is_equal([0, IntentionsSlice.ACTION_ATTACK, 1, IntentionsSlice.MOTIVE_HUNT])
	assert_array([slice.author_of(1), slice.action_of(1), slice.target_id_of(1), slice.motive_of(1)]).is_equal([3, IntentionsSlice.ACTION_CAPTURE, 0, IntentionsSlice.MOTIVE_CAPTURE])
	assert_array([fx.state.siege.node_of(), fx.state.siege.count_of()]).is_equal([-1, 0])


func test_roles_follow_the_situation() -> void:
	var fx := _fixture(_board())
	fx.pipeline.submit(_plan(fx.state))
	var agents := fx.state.ai_agents

	assert_int(agents.role_of(agents.find_row(0))).is_equal(AiAgentsSlice.ROLE_HUNT)
	assert_int(agents.role_of(agents.find_row(2))).is_equal(AiAgentsSlice.ROLE_IMMOBILE)
	assert_int(agents.role_of(agents.find_row(3))).is_equal(AiAgentsSlice.ROLE_CAPTURE)
	assert_int(agents.post_tile_of(agents.find_row(0))).is_equal(fx.state.tile_index(2, 1))


func test_a_hunter_without_target_goes_back_to_its_post_after_two_idle_turns() -> void:
	var state := _board()
	UnitWrites.destroy(state, 1)
	var fx := _fixture(state)
	AiWrites.set_agent(fx.state, 0, AiAgentsSlice.ROLE_HUNT, 0, fx.state.tile_index(1, 1), AiAgentsSlice.NO_MOTIVE)
	VisionService.recompute(fx.state, fx.rules.vision)

	fx.pipeline.submit(_plan(fx.state))
	assert_array([fx.state.ai_agents.role_of(fx.state.ai_agents.find_row(0)), fx.state.ai_agents.idle_turns_of(fx.state.ai_agents.find_row(0))]).is_equal([AiAgentsSlice.ROLE_HUNT, 1])

	GameStateSetup.set_turn(fx.state, 5)
	fx.pipeline.submit(_plan(fx.state))
	assert_int(fx.state.ai_agents.role_of(fx.state.ai_agents.find_row(0))).is_equal(AiAgentsSlice.ROLE_RETURN)


func test_a_bastion_that_holds_a_node_ripostes_against_an_adjacent_player_unit() -> void:
	var state := MapBuilder.state(PackedStringArray(["........", "........", "........"]))
	MapBuilder.unit(state, BASTION, Faction.AI, 4, 1)
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 5, 1)
	GameStateSetup.add_node(state, state.tile_index(4, 1), Faction.AI, 1)
	GameStateSetup.add_node(state, state.tile_index(0, 0), Faction.PLAYER, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 4)
	var fx := _fixture(state)

	assert_bool(fx.pipeline.submit(_plan(state)).permitted).is_true()

	assert_int(fx.state.intentions.motive_of(0)).is_equal(IntentionsSlice.MOTIVE_DEFENSE)
	assert_int(fx.state.ai_agents.role_of(0)).is_equal(AiAgentsSlice.ROLE_RIPOSTE)


func test_the_siege_of_the_last_player_node_takes_two_announcements() -> void:
	var state := _board()
	GameStateSetup.set_tile_owner(state, state.tile_index(7, 2), Faction.NONE)
	NodeWrites.capture(state, 1, Faction.AI)  # the player now holds node 0 only
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	UnitWrites.destroy(state, 0)
	var fx := _fixture(state)

	assert_bool(fx.pipeline.submit(_plan(fx.state)).permitted).is_true()
	assert_array([fx.state.siege.node_of(), fx.state.siege.count_of()]).is_equal([0, 1])

	GameStateSetup.set_turn(fx.state, 5)
	assert_bool(fx.pipeline.submit(_plan(fx.state)).permitted).is_true()
	assert_array([fx.state.siege.node_of(), fx.state.siege.count_of()]).is_equal([0, 2])


func test_a_siege_that_cannot_end_in_time_is_not_started() -> void:
	var state := _board()
	NodeWrites.capture(state, 1, Faction.AI)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	UnitWrites.destroy(state, 0)
	GameStateSetup.set_turn(state, GameState.MAX_TURN - 1)
	var fx := _fixture(state)

	var command := _plan(fx.state)

	assert_int(command.intentions.size()).is_equal(0)
	assert_int(command.siege_node).is_equal(-1)
	assert_bool(fx.pipeline.submit(command).permitted).is_true()


func test_no_announcement_without_ai_units() -> void:
	var state := MapBuilder.state(PackedStringArray(["....", "...."]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	MapBuilder.ready(state)

	assert_object(AiPlanner.new().plan_announcement(state.filtered_copy(Faction.AI), CatalogFactory.standard())).is_null()
