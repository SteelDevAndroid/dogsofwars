extends GdUnitTestSuite

const ASSAUT := 1

var _catalog := CatalogFactory.standard()


## 10 x 1 plain, the match not started (CRÉÉE). Player Assaut 0 at (0,0); AI Assaut 1 at (5,0):
## its vision (2) does not reach the player's unit, and the player's Assaut sees only 2 tiles.
func _board(player_x: int = 0, ai_x: int = 5) -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray([".........."]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, player_x, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, ai_x, 0)
	return PipelineFixture.new(MapBuilder.ready(state), true)


func test_a_unit_unseen_by_the_enemy_when_its_turn_begins_is_in_ambush_and_strikes_harder() -> void:
	var fx := _board(0, 4)

	fx.begin_turn(Faction.PLAYER)

	assert_bool(fx.state.view().unit_ambush(0)).is_true()
	assert_bool(fx.move(0, fx.state.tile_index(3, 0)).permitted).is_true()
	assert_int(CombatRules.damage(fx.state.view(), 0, 1, _catalog)).is_equal(6)  # ATQ 3 + 1, instead of 4
	fx.attack(0, 1)
	assert_int(fx.state.view().unit_hp(1)).is_equal(2)


func test_a_unit_the_enemy_sees_is_not_in_ambush() -> void:
	var fx := _board(3, 5)  # two tiles apart: each sees the other

	fx.begin_turn(Faction.PLAYER)

	assert_bool(fx.state.view().unit_ambush(0)).is_false()
	assert_int(CombatRules.damage(fx.state.view(), 0, 1, _catalog)).is_equal(4)


func test_the_ai_never_gets_an_ambush_and_the_players_ends_with_its_turn() -> void:
	var fx := _board()
	fx.begin_turn(Faction.PLAYER)
	assert_bool(fx.state.view().unit_ambush(0)).is_true()

	fx.end_turn()
	fx.begin_turn(Faction.AI)

	assert_bool(fx.state.view().unit_ambush(0)).is_false()  # not carried into the enemy phase
	assert_bool(fx.state.view().unit_ambush(1)).is_false()  # the AI's announced strikes stay readable


func test_a_faction_view_hides_an_enemys_ambush_and_cooldown() -> void:
	var fx := _board(3, 5)
	UnitWrites.use_ability(fx.state, 0, 3, true)
	var ai_view := FactionView.new(fx.state, Faction.AI)

	assert_int(ai_view.unit_cooldown(0)).is_equal(0)
	assert_bool(ai_view.unit_ambush(0)).is_false()
	assert_int(FactionView.new(fx.state, Faction.PLAYER).unit_cooldown(0)).is_equal(3)
