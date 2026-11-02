extends GdUnitTestSuite

const ECLAIREUR := 0
const ASSAUT := 1
const CHASSEUR := 5
const BASTION := 6
const UNIT := IntentionsSlice.TARGET_UNIT
const NODE := IntentionsSlice.TARGET_NODE
const ATTACK := IntentionsSlice.ACTION_ATTACK
const CAPTURE := IntentionsSlice.ACTION_CAPTURE


## 8 x 3, turn 4 announced, turn 5 enemy phase. Player: Eclaireur 0 at (0,0) with 1 HP,
## Assaut 1 at (7,2), node 0 at (4,1) (level 2) and node 1 at (7,0). AI: Chasseur 2
## at (1,0) (will kill 0), Bastion 3 on node 0, Chasseur 4 at (6,2) next to Assaut 1
## (retaliation kills it: 1 HP).
func _board() -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray(["........", "........", "........"]))
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 0, 0, false, 1)
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 7, 2)
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 1, 0)
	MapBuilder.unit(state, BASTION, Faction.AI, 4, 1)
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 6, 2, false, 1)
	GameStateSetup.add_node(state, state.tile_index(4, 1), Faction.PLAYER, 2)
	GameStateSetup.add_node(state, state.tile_index(7, 0), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(0, 2), Faction.AI, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 4)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	var fx := PipelineFixture.new(MapBuilder.ready(state))
	assert_bool(fx.announce([[2, UNIT, 0, ATTACK, 0], [3, NODE, 0, CAPTURE, IntentionsSlice.MOTIVE_CAPTURE], [4, UNIT, 1, ATTACK, 0]]).permitted).is_true()
	GameStateSetup.set_turn(state, 5)
	return fx


func test_units_lost_during_the_enemy_phase_are_recalled_with_their_side() -> void:
	var fx := _board()

	fx.execute_intention(0)
	fx.execute_intention(1)
	fx.execute_intention(2)

	var recalls := fx.state.recalls
	assert_int(recalls.unit_count()).is_equal(2)
	assert_array([recalls.unit_tile_of(0), recalls.unit_side_of(0)]).is_equal([fx.state.tile_index(0, 0), Faction.PLAYER])
	assert_array([recalls.unit_tile_of(1), recalls.unit_side_of(1)]).is_equal([fx.state.tile_index(6, 2), Faction.AI])


func test_tiles_lost_by_the_player_are_recalled_once() -> void:
	var fx := _board()

	fx.execute_intention(0)
	fx.execute_intention(1)

	var lost := fx.state.recalls.lost_tiles()
	assert_bool(lost.size() > 0).is_true()
	assert_bool(lost.has(fx.state.tile_index(4, 1))).is_true()
	for tile in lost:
		assert_int(fx.state.map.owner_at(tile)).is_not_equal(Faction.PLAYER)
	var sorted := Array(lost)
	sorted.sort()
	for k in range(1, sorted.size()):
		assert_int(sorted[k]).is_not_equal(sorted[k - 1])


func test_nothing_is_recalled_in_the_player_phase() -> void:
	var fx := _board()
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)

	assert_bool(fx.attack(1, 4).permitted).is_true()

	assert_int(fx.state.recalls.unit_count()).is_equal(0)
	assert_bool(fx.state.view().unit_tile(4) < 0).is_true()


func test_the_recalls_are_emptied_at_the_end_of_the_players_turn() -> void:
	var fx := _board()
	fx.execute_intention(0)
	assert_int(fx.state.recalls.unit_count()).is_equal(1)
	fx.begin_turn(Faction.PLAYER)
	assert_int(fx.state.recalls.unit_count()).is_equal(1)  # still shown during the player's turn

	fx.end_turn()

	assert_int(fx.state.recalls.unit_count()).is_equal(0)
	assert_int(fx.state.recalls.lost_tiles().size()).is_equal(0)


func test_the_next_enemy_phase_starts_from_an_empty_slice() -> void:
	var fx := _board()
	fx.execute_intention(0)
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_END_OF_TURN, Faction.AI)

	fx.begin_turn(Faction.AI)

	assert_int(fx.state.recalls.unit_count()).is_equal(0)


func test_the_recalls_have_no_game_effect() -> void:
	var with_recalls := _board()
	var without := _board()
	with_recalls.execute_intention(0)
	without.execute_intention(0)
	without.state.recalls.clear()

	assert_int(with_recalls.state.score.units_destroyed_of(Faction.AI)).is_equal(without.state.score.units_destroyed_of(Faction.AI))
	assert_array(with_recalls.state.view().unit_ids()).is_equal(without.state.view().unit_ids())


func test_a_tile_lost_twice_is_recalled_once() -> void:
	var fx := _board()

	RecallWrites.tile_lost(fx.state, 5)
	RecallWrites.tile_lost(fx.state, 5)

	assert_array(Array(fx.state.recalls.lost_tiles())).is_equal([5])


func test_only_tiles_lost_by_the_player_count() -> void:
	var fx := _board()
	NodeWrites.capture(fx.state, 2, Faction.PLAYER)

	TerritoryRules.recompute(fx.state, CatalogFactory.standard().nodes, MapSlice.CAUSE_CAPTURE)

	assert_int(fx.state.recalls.lost_tiles().size()).is_equal(0)
