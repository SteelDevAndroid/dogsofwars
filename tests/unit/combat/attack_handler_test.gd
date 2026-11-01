extends GdUnitTestSuite

const ECLAIREUR := 0
const ASSAUT := 1
const SENTINELLE := 4
const CHASSEUR := 5


## 6 x 2 map. Player: Assaut 0 at (0,0), Sentinelle 1 at (0,1). AI: Assaut 2 at (1,0)
## (adjacent), Assaut 3 at (5,1) (hidden: the Assaut sees 2 tiles). Neutral dormant 4
## at (1,1), visible.
func _board() -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray(["......", "......"]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, SENTINELLE, Faction.PLAYER, 0, 1)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 1, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 5, 1)
	MapBuilder.unit(state, ASSAUT, Faction.NONE, 1, 1, true)
	return PipelineFixture.new(MapBuilder.ready(state))


func test_attack_hits_then_retaliates_and_spends_the_action() -> void:
	var fx := _board()

	assert_bool(fx.attack(0, 2).permitted).is_true()

	var events := fx.last_events()
	assert_object(events[0]).is_instanceof(AttackResolvedEvent)
	assert_int((events[1] as UnitHitEvent).unit_id).is_equal(2)
	assert_int((events[1] as UnitHitEvent).hp_left).is_equal(4)
	assert_int((events[2] as UnitHitEvent).unit_id).is_equal(0)
	assert_int((events[2] as UnitHitEvent).hp_left).is_equal(6)
	assert_bool(fx.state.view().unit_acted(0)).is_true()
	assert_bool(fx.state.view().unit_acted(2)).is_false()
	assert_bool(fx.state.view().unit_moved(0)).is_false()
	assert_int(fx.state.revision()).is_equal(1)
	assert_str(fx.undo.reason).is_equal(Refusal.OTHER_ACTION_SINCE)
	assert_int(fx.state.score.units_destroyed_of(Faction.PLAYER)).is_equal(0)


func test_validation_order_returns_the_first_refusal() -> void:
	var fx := _board()
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	assert_str(fx.attack(2, 0, Faction.AI).code).is_equal(Refusal.NO_INTENTION)
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)

	assert_str(fx.attack(2, 0).code).is_equal(Refusal.UNKNOWN_UNIT)
	assert_str(fx.attack(99, 2).code).is_equal(Refusal.UNKNOWN_UNIT)
	assert_str(fx.attack(1, 2).code).is_equal(Refusal.ATTACKER_WITHOUT_ATTACK)
	var sleeper := MapBuilder.unit(fx.state, ASSAUT, Faction.PLAYER, 3, 0, true)
	assert_str(fx.attack(sleeper, 2).code).is_equal(Refusal.UNIT_ASLEEP)
	assert_str(fx.attack(0, 0).code).is_equal(Refusal.TARGET_NOT_HOSTILE)
	assert_str(fx.attack(0, 1).code).is_equal(Refusal.TARGET_NOT_HOSTILE)
	assert_str(fx.attack(0, 4).code).is_equal(Refusal.TARGET_NOT_HOSTILE)
	assert_bool(fx.attack(0, 2).permitted).is_true()
	assert_str(fx.attack(0, 2).code).is_equal(Refusal.ALREADY_ACTED)


func test_a_hidden_unknown_or_stale_target_gives_the_same_refusal_without_parameter() -> void:
	var fx := _board()

	var hidden := fx.attack(0, 3)
	var unknown := fx.attack(0, 99)

	assert_str(hidden.code).is_equal(Refusal.TARGET_NOT_VISIBLE)
	assert_bool(hidden.equals(unknown)).is_true()
	assert_array(hidden.params).is_empty()
	UnitWrites.destroy(fx.state, 2)
	assert_bool(fx.attack(0, 2).equals(unknown)).is_true()


func test_a_target_beyond_the_range_is_refused_only_once_visible() -> void:
	var state := MapBuilder.state(PackedStringArray([".........."]))
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 3, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 9, 0)
	var fx := PipelineFixture.new(MapBuilder.ready(state))

	assert_str(fx.attack(0, 1).code).is_equal(Refusal.TARGET_OUT_OF_RANGE)
	assert_str(fx.attack(0, 2).code).is_equal(Refusal.TARGET_NOT_VISIBLE)


func test_a_diagonal_attack_is_allowed() -> void:
	var state := MapBuilder.state(PackedStringArray(["~.", ".."]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 1, 1)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 0, 0)
	var fx := PipelineFixture.new(MapBuilder.ready(state))

	assert_bool(fx.attack(0, 1).permitted).is_true()


func test_a_kill_counts_for_the_attacker_and_ends_the_exchange() -> void:
	var state := MapBuilder.state(PackedStringArray(["..."]))
	MapBuilder.unit(state, CHASSEUR, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ECLAIREUR, Faction.AI, 1, 0)
	var fx := PipelineFixture.new(MapBuilder.ready(state))

	fx.attack(0, 1)

	assert_int(state.view().unit_tile(1)).is_equal(-1)
	assert_int(state.view().unit_hp(0)).is_equal(8)
	assert_int(state.score.units_destroyed_of(Faction.PLAYER)).is_equal(1)
	assert_int(state.score.units_destroyed_of(Faction.AI)).is_equal(0)
	var destroyed := fx.last_events()[2] as UnitDestroyedEvent
	assert_array([destroyed.unit_id, destroyed.by, destroyed.faction]).is_equal([1, 0, Faction.AI])
	assert_array(PackedInt32Array(state.view().unit_ids())).is_equal(PackedInt32Array([0]))


func test_the_retaliation_can_destroy_the_attacker_and_counts_for_the_target() -> void:
	var state := MapBuilder.state(PackedStringArray(["..."]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0, false, 1)
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 1, 0)
	var fx := PipelineFixture.new(MapBuilder.ready(state))

	fx.attack(0, 1)

	assert_int(state.view().unit_tile(0)).is_equal(-1)
	assert_int(state.view().unit_hp(1)).is_equal(7)
	assert_int(state.score.units_destroyed_of(Faction.AI)).is_equal(1)
	assert_int(state.score.units_destroyed_of(Faction.PLAYER)).is_equal(0)
	assert_object(fx.last_events()[3]).is_instanceof(UnitDestroyedEvent)


func test_no_retaliation_from_a_sentinel() -> void:
	var state := MapBuilder.state(PackedStringArray(["..."]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, SENTINELLE, Faction.AI, 1, 0)
	var fx := PipelineFixture.new(MapBuilder.ready(state))

	fx.attack(0, 1)

	assert_int(fx.last_events().size()).is_equal(2)
	assert_int(state.view().unit_hp(0)).is_equal(8)


func test_a_destroyed_unit_takes_its_vision_with_it() -> void:
	var state := MapBuilder.state(PackedStringArray([".....", "....."]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0, false, 1)
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 1, 0)
	var fx := PipelineFixture.new(MapBuilder.ready(state))
	var far := state.tile_index(2, 1)
	assert_int(VisionService.tile_state(state, Faction.PLAYER, far)).is_equal(VisionService.VISIBLE)

	fx.attack(0, 1)

	assert_int(VisionService.tile_state(state, Faction.PLAYER, far)).is_equal(VisionService.EXPLORED)


func test_the_attack_is_saved_replayed_and_round_trips_in_the_codec() -> void:
	var initial := _board().state
	var fx := PipelineFixture.new(initial.duplicate_state())
	fx.attack(0, 2)

	var outcome := CommandReplay.replay(initial, fx.log, CatalogFactory.standard())

	assert_array(fx.post_commit.revisions).is_equal(PackedInt64Array([1]))
	assert_int(outcome.divergence).is_equal(-1)
	assert_bool(outcome.state.equals(fx.state)).is_true()
	var decoded := CommandCodec.decode(CommandCodec.encode(AttackCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, 3, 7)))
	assert_array([(decoded as AttackCommand).attacker_id, (decoded as AttackCommand).target_id]).is_equal([3, 7])
	assert_object(CommandCodec.decode(PackedInt64Array([CommandType.ATTACK, 0, 0, 1]))).is_null()
