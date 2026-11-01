extends GdUnitTestSuite

const ECLAIREUR := 0
const ASSAUT := 1
const REMPART := 2
const SENTINELLE := 4
const REVEIL_SOBRE := 1


## 8 x 2 map, player turn. Ids: 0 player Éclaireur (1,0) (view 4); 1 player Assaut (0,0);
## 2 neutral Rempart dormant (2,0), next to an AI unit; 3 neutral Éclaireur dormant (1,1);
## 4 AI Assaut (3,0); 5 neutral Éclaireur dormant (7,1), hidden; 6 player Sentinelle
## (0,1); 7 neutral Rempart dormant (3,1), visible but two tiles from unit 0.
func _board(energy: int = 20) -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray(["........", "........"]))
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 1, 0)
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, REMPART, Faction.NONE, 2, 0, true)
	MapBuilder.unit(state, ECLAIREUR, Faction.NONE, 1, 1, true)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 3, 0)
	MapBuilder.unit(state, ECLAIREUR, Faction.NONE, 7, 1, true)
	MapBuilder.unit(state, SENTINELLE, Faction.PLAYER, 0, 1)
	MapBuilder.unit(state, REMPART, Faction.NONE, 3, 1, true)
	return PipelineFixture.new(MapBuilder.with_energy(MapBuilder.ready(state), energy, 0))


func test_wake_pays_the_price_and_turns_the_dormant_into_an_exhausted_unit_of_the_waker() -> void:
	var fx := _board()
	var units_before := fx.state.units.row_count()
	var next_id := fx.state.header.value(HeaderSlice.NEXT_UNIT_ID)

	assert_bool(fx.wake(0, 2).permitted).is_true()

	var view := fx.state.view()
	assert_int(EnergyRules.stock(fx.state, Faction.PLAYER)).is_equal(12)
	assert_array([view.unit_faction(2), view.unit_asleep(2), view.unit_moved(2), view.unit_acted(2)]).is_equal([Faction.PLAYER, false, true, true])
	assert_array([view.unit_type(2), view.unit_hp(2), view.unit_tile(2)]).is_equal([REMPART, 14, fx.state.tile_index(2, 0)])
	assert_array([view.unit_acted(0), view.unit_moved(0)]).is_equal([true, false])
	assert_int(fx.state.units.row_count()).is_equal(units_before)
	assert_int(fx.state.header.value(HeaderSlice.NEXT_UNIT_ID)).is_equal(next_id)
	var events := fx.last_events()
	assert_array([(events[0] as EnergyChangedEvent).before, (events[0] as EnergyChangedEvent).after]).is_equal([20, 12])
	assert_array([(events[1] as DroneWokenEvent).unit_id, (events[1] as DroneWokenEvent).by]).is_equal([2, 0])


func test_validation_order_returns_the_first_failure() -> void:
	var fx := _board()
	assert_str(fx.wake(4, 2).code).is_equal(Refusal.UNKNOWN_UNIT)
	assert_str(fx.wake(2, 3).code).is_equal(Refusal.UNKNOWN_UNIT)
	assert_str(fx.wake(99, 2).code).is_equal(Refusal.UNKNOWN_UNIT)
	assert_str(fx.wake(6, 99).code).is_equal(Refusal.TYPE_NOT_CAPABLE)
	fx.wake(0, 3)
	assert_str(fx.wake(0, 99).code).is_equal(Refusal.ALREADY_ACTED)
	var poor := _board(0)
	assert_str(poor.wake(0, 5).code).is_equal(Refusal.NO_ADJACENT_DRONE)
	assert_str(poor.wake(0, 2).code).is_equal(Refusal.NOT_ENOUGH_ENERGY)


func test_every_way_to_miss_the_dormant_gives_one_code_without_parameter() -> void:
	var fx := _board()

	var unknown := fx.wake(0, 99)
	var awake := fx.wake(0, 1)
	var hidden := fx.wake(0, 5)
	var far := fx.wake(0, 7)

	assert_str(unknown.code).is_equal(Refusal.NO_ADJACENT_DRONE)
	assert_array(unknown.params).is_empty()
	for other in [awake, hidden, far]:
		assert_bool(unknown.equals(other)).is_true()


func test_energy_refusal_gives_need_and_available_and_the_exact_price_is_enough() -> void:
	var short := _board(7)
	var exact := _board(8)

	var refused := short.wake(0, 2)

	assert_array(refused.params).is_equal(PackedInt64Array([8, 7]))
	assert_bool(short.wake(0, 3).permitted).is_true()
	assert_bool(exact.wake(0, 2).permitted).is_true()
	assert_int(EnergyRules.stock(exact.state, Faction.PLAYER)).is_equal(0)


func test_reveil_sobre_lowers_the_price_of_its_owner_only() -> void:
	var sober := _board()
	ResearchRules.acquire(sober.state, Faction.PLAYER, REVEIL_SOBRE)
	var rival := _board()
	ResearchRules.acquire(rival.state, Faction.AI, REVEIL_SOBRE)

	sober.wake(0, 2)
	rival.wake(0, 2)

	assert_int(EnergyRules.stock(sober.state, Faction.PLAYER)).is_equal(13)
	assert_int(EnergyRules.stock(rival.state, Faction.PLAYER)).is_equal(12)


func test_a_dormant_next_to_an_enemy_can_be_woken() -> void:
	var fx := _board()

	assert_bool(fx.wake(0, 2).permitted).is_true()
	assert_int(fx.state.view().unit_tile(4)).is_equal(fx.state.tile_index(3, 0))


func test_the_woken_unit_neither_acts_nor_moves_this_turn_but_does_next_turn() -> void:
	var fx := _board()
	fx.wake(0, 2)

	assert_str(fx.move(2, fx.state.tile_index(2, 1)).code).is_equal(Refusal.ALREADY_MOVED)
	assert_str(fx.wake(2, 3).code).is_equal(Refusal.ALREADY_ACTED)
	fx.end_turn()
	fx.begin_turn(Faction.AI)
	fx.begin_turn(Faction.PLAYER)

	assert_bool(fx.move(2, fx.state.tile_index(2, 1)).permitted).is_true()


func test_one_action_one_dormant_but_another_unit_can_wake_the_second() -> void:
	var fx := _board()
	fx.wake(0, 2)

	assert_str(fx.wake(0, 3).code).is_equal(Refusal.ALREADY_ACTED)
	assert_bool(fx.wake(1, 3).permitted).is_true()


func test_waking_after_a_move_is_final() -> void:
	# The Éclaireur at (0, 1) sees the whole map, so the move reveals nothing.
	var state := MapBuilder.state(PackedStringArray(["....", "...."]))
	var worker := MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 0, 1)
	var dormant := MapBuilder.unit(state, ASSAUT, Faction.NONE, 3, 0, true)
	var fx := PipelineFixture.new(MapBuilder.with_energy(MapBuilder.ready(state), 20, 0))
	fx.move(worker, state.tile_index(2, 0))
	assert_bool(fx.undo.is_armed()).is_true()

	assert_bool(fx.wake(worker, dormant).permitted).is_true()

	assert_str(fx.undo.reason).is_equal(Refusal.OTHER_ACTION_SINCE)
	assert_str(fx.undo_move().code).is_equal(Refusal.OTHER_ACTION_SINCE)


func test_a_guardian_is_refused_even_when_the_ai_emits_the_command() -> void:
	var state := MapBuilder.state(PackedStringArray(["..."]))
	var guardian := MapBuilder.unit(state, SENTINELLE, Faction.AI, 0, 0)
	var dormant := MapBuilder.unit(state, ASSAUT, Faction.NONE, 1, 0, true)
	var fx := PipelineFixture.new(MapBuilder.ready(state))
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)

	assert_str(fx.wake(guardian, dormant, Faction.AI).code).is_equal(Refusal.TYPE_NOT_CAPABLE)


func test_waking_recomputes_the_view_and_clears_the_marker_only_where_it_is_seen() -> void:
	var state := MapBuilder.state(PackedStringArray(["............"]))
	var waker := MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	var dormant := MapBuilder.unit(state, ECLAIREUR, Faction.NONE, 1, 0, true)
	# with_energy returns a decoded copy: read the fixture's state from here on.
	var fx := PipelineFixture.new(MapBuilder.with_energy(MapBuilder.ready(state), 20, 0))
	var live := fx.state
	var tile := live.tile_index(1, 0)
	var tiles := live.tile_count()
	assert_int(live.visibility._vis_dormant_memo[Faction.PLAYER * tiles + tile]).is_equal(1)
	assert_int(VisionService.tile_state(live, Faction.PLAYER, live.tile_index(5, 0))).is_equal(VisionService.UNKNOWN)

	fx.wake(waker, dormant)

	assert_int(VisionService.tile_state(live, Faction.PLAYER, live.tile_index(5, 0))).is_equal(VisionService.VISIBLE)
	var revealed := fx.last_events()[2] as TilesRevealedEvent
	assert_array(revealed.revealed_tiles).is_equal(PackedInt32Array([3, 4, 5]))
	assert_int(live.visibility._vis_dormant_memo[Faction.PLAYER * tiles + tile]).is_equal(0)
	assert_int(live.visibility._vis_dormant_memo[Faction.AI * tiles + tile]).is_equal(1)


func test_the_preview_shows_the_same_energy_and_waking_events() -> void:
	var fx := _board()
	var command := WakeCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, 0, 2)
	var before := fx.state.to_bytes()

	var preview := fx.pipeline.preview(command)
	fx.pipeline.submit(command)

	assert_array(fx.state.to_bytes()).is_not_equal(before)
	var real := fx.last_events()
	assert_array([(preview.events[0] as EnergyChangedEvent).before, (preview.events[0] as EnergyChangedEvent).after]) \
		.is_equal([(real[0] as EnergyChangedEvent).before, (real[0] as EnergyChangedEvent).after])
	assert_array([(preview.events[1] as DroneWokenEvent).unit_id, (preview.events[1] as DroneWokenEvent).by]) \
		.is_equal([(real[1] as DroneWokenEvent).unit_id, (real[1] as DroneWokenEvent).by])


func test_the_wake_is_saved_replayed_and_round_trips_in_the_codec() -> void:
	var initial := _board().state
	var fx := PipelineFixture.new(initial.duplicate_state())
	fx.wake(0, 2)

	var outcome := CommandReplay.replay(initial, fx.log, CatalogFactory.standard())

	assert_array(fx.post_commit.revisions).is_equal(PackedInt64Array([1]))
	assert_int(outcome.divergence).is_equal(-1)
	assert_bool(outcome.state.equals(fx.state)).is_true()
	var decoded := CommandCodec.decode(CommandCodec.encode(WakeCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, 3, 9)))
	assert_array([(decoded as WakeCommand).waker_id, (decoded as WakeCommand).target_id]).is_equal([3, 9])
	assert_object(CommandCodec.decode(PackedInt64Array([CommandType.WAKE, 0, 0, 1]))).is_null()
