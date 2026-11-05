extends GdUnitTestSuite

const ECLAIREUR := 0
const ASSAUT := 1
const REMPART := 2
const OUVRIER := 3
const SENTINELLE := 4

var _catalog := CatalogFactory.standard()


## 10 x 1 plain. Player: Eclaireur 0 (0,0), Assaut 1 (1,0), Rempart 2 (2,0) 10/14, Ouvrier 3 (3,0) 3/7.
## AI: Assaut 4 at (5,0) (far enough to see nothing of the player but the Ouvrier's side), Sentinelle 5 at (9,0).
func _board() -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray([".........."]))
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 1, 0)
	MapBuilder.unit(state, REMPART, Faction.PLAYER, 2, 0, false, 10)
	MapBuilder.unit(state, OUVRIER, Faction.PLAYER, 3, 0, false, 3)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 5, 0)
	MapBuilder.unit(state, SENTINELLE, Faction.AI, 9, 0)
	return PipelineFixture.new(MapBuilder.ready(state))


func test_an_ability_starts_its_cooldown_and_refuses_a_second_use() -> void:
	var fx := _board()

	assert_bool(fx.ability(1).permitted).is_true()  # Assaut: charge

	assert_int(fx.state.view().unit_cooldown(1)).is_equal(3)
	assert_bool(fx.state.view().unit_ability_on(1)).is_true()
	var again := fx.ability(1)
	assert_bool(again.permitted).is_false()
	assert_str(again.code).is_equal(Refusal.ABILITY_RECHARGING)
	assert_array(again.params).is_equal([3])


func test_a_type_without_ability_is_refused() -> void:
	var fx := _board()
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)

	var result := fx.ability(5, Faction.AI)

	assert_str(result.code).is_equal(Refusal.NO_ABILITY)


func test_the_cooldown_counts_down_at_the_start_of_the_players_turn() -> void:
	var fx := _board()
	fx.ability(1)
	fx.end_turn()
	fx.begin_turn(Faction.AI)

	fx.begin_turn(Faction.PLAYER)

	assert_int(fx.state.view().unit_cooldown(1)).is_equal(2)
	assert_bool(fx.state.view().unit_ability_on(1)).is_false()  # the charge ended with the turn


func test_sprint_adds_movement_points() -> void:
	var fx := _board()
	var base := MovementRules.remaining_points(fx.state.view(), 0, _catalog)

	fx.ability(0)

	assert_int(MovementRules.remaining_points(fx.state.view(), 0, _catalog)).is_equal(base + 2)


func test_sprint_is_refused_once_the_unit_has_moved() -> void:
	var state := MapBuilder.state(PackedStringArray([".........."]))
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 9, 0)
	var fx := PipelineFixture.new(MapBuilder.ready(state))
	assert_bool(fx.move(0, fx.state.tile_index(2, 0)).permitted).is_true()

	var result := fx.ability(0)

	assert_str(result.code).is_equal(Refusal.ALREADY_MOVED)


func test_charge_adds_attack_to_the_next_strike() -> void:
	var state := MapBuilder.state(PackedStringArray(["......"]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 1, 0)
	var fx := PipelineFixture.new(MapBuilder.ready(state))
	assert_int(CombatRules.damage(fx.state.view(), 0, 1, _catalog)).is_equal(4)

	fx.ability(0)

	assert_int(CombatRules.damage(fx.state.view(), 0, 1, _catalog)).is_equal(8)  # ATQ 3 + 2: the target is destroyed
	fx.attack(0, 1)
	assert_int(fx.state.view().unit_hp(1)).is_equal(0)


func test_hold_raises_defense_through_the_enemy_phase_and_costs_the_action() -> void:
	var state := MapBuilder.state(PackedStringArray(["......"]))
	MapBuilder.unit(state, REMPART, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 1, 0)
	var fx := PipelineFixture.new(MapBuilder.ready(state))
	var before := CombatRules.damage(fx.state.view(), 1, 0, _catalog)

	fx.ability(0)

	assert_bool(fx.state.view().unit_acted(0)).is_true()
	var held := CombatRules.damage(fx.state.view(), 1, 0, _catalog)
	assert_int(held).is_less(before)
	fx.end_turn()
	fx.begin_turn(Faction.AI)
	assert_int(CombatRules.damage(fx.state.view(), 1, 0, _catalog)).is_equal(held)  # still held on the AI's turn
	fx.begin_turn(Faction.PLAYER)
	assert_int(CombatRules.damage(fx.state.view(), 1, 0, _catalog)).is_equal(before)  # over at its next turn


func test_repair_heals_the_unit_and_its_neighbours_only() -> void:
	var fx := _board()

	assert_bool(fx.ability(3).permitted).is_true()  # Ouvrier at (3,0), 3/7

	var view := fx.state.view()
	assert_int(view.unit_hp(3)).is_equal(6)  # +3
	assert_int(view.unit_hp(2)).is_equal(13)  # the Rempart next to it: 10 + 3
	assert_int(view.unit_hp(1)).is_equal(8)  # two tiles away: untouched (already full anyway)
	assert_bool(view.unit_acted(3)).is_true()
	assert_bool(view.unit_ability_on(3)).is_false()  # an instant effect
	var healed := fx.last_events().filter(func(event: PresentationEvent) -> bool: return event is UnitHealedEvent)
	assert_int(healed.size()).is_equal(2)
	assert_object(fx.last_events()[0]).is_instanceof(AbilityUsedEvent)


func test_the_command_round_trips_through_the_codec() -> void:
	var command := AbilityCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, 7)

	var decoded := CommandCodec.decode(CommandCodec.encode(command)) as AbilityCommand

	assert_int(decoded.unit_id).is_equal(7)
	assert_int(decoded.type()).is_equal(CommandType.ABILITY)
	assert_object(CommandCodec.decode(PackedInt64Array([CommandType.ABILITY, 0, 0]))).is_null()  # a missing parameter
