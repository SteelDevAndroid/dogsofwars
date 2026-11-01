extends GdUnitTestSuite

const ASSAUT := 1
const VEILLE := 0
const REVEIL := 1
const REPOS := 3
const BLINDAGE := 4


## The player has `energy` and the protocols of `acquired`; the AI owns nothing.
func _fixture(energy: int, acquired: PackedInt32Array = PackedInt32Array()) -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray(["......"]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 5, 0)
	for protocol in acquired:
		ResearchRules.acquire(state, Faction.PLAYER, protocol)
	MapBuilder.ready(state)
	var loaded := StatePayload.decoded_with(state, &"_fac_energy", PackedInt32Array([energy, 50]))
	VisionService.rebuild(loaded, StateFactory.vision_context(loaded))
	return PipelineFixture.new(loaded)


func test_research_pays_the_price_and_starts_for_its_duration() -> void:
	var fx := _fixture(20)

	assert_bool(fx.research(REPOS).permitted).is_true()

	assert_int(fx.state.factions.research_of(Faction.PLAYER)).is_equal(REPOS)
	assert_int(fx.state.factions.research_turns_of(Faction.PLAYER)).is_equal(2)
	assert_int(EnergyRules.stock(fx.state, Faction.PLAYER)).is_equal(5)
	var events := fx.last_events()
	assert_int((events[0] as ResearchStartedEvent).protocol).is_equal(REPOS)
	assert_int((events[1] as EnergyChangedEvent).after).is_equal(5)


func test_validation_order_returns_the_first_failure() -> void:
	assert_str(_fixture(99).research(9).code).is_equal(Refusal.UNKNOWN_PROTOCOL)
	assert_str(_fixture(99).research(-1).code).is_equal(Refusal.UNKNOWN_PROTOCOL)
	assert_str(_fixture(0, PackedInt32Array([REPOS])).research(REPOS).code).is_equal(Refusal.PROTOCOL_ACQUIRED)
	var busy := _fixture(99)
	busy.research(REPOS)
	var in_progress := busy.research(VEILLE)
	assert_str(in_progress.code).is_equal(Refusal.RESEARCH_IN_PROGRESS)
	assert_array(in_progress.params).is_equal(PackedInt64Array([REPOS]))
	var no_prerequisite := _fixture(0).research(BLINDAGE)
	assert_str(no_prerequisite.code).is_equal(Refusal.PREREQUISITE_MISSING)
	assert_array(no_prerequisite.params).is_equal(PackedInt64Array([REPOS]))


func test_energy_comes_last_with_need_and_available() -> void:
	var poor := _fixture(14)

	var result := poor.research(REPOS)

	assert_str(result.code).is_equal(Refusal.NOT_ENOUGH_ENERGY)
	assert_array(result.params).is_equal(PackedInt64Array([15, 14]))
	assert_bool(_fixture(15).research(REPOS).permitted).is_true()


func test_prerequisite_still_in_research_does_not_count() -> void:
	var fx := _fixture(99)
	fx.research(VEILLE)

	var result := fx.pipeline.check(ResearchCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, REVEIL))

	assert_str(result.code).is_equal(Refusal.RESEARCH_IN_PROGRESS)
	assert_bool(_fixture(99, PackedInt32Array([VEILLE])).research(REVEIL).permitted).is_true()


func test_refused_research_writes_nothing_and_needs_the_player_turn() -> void:
	var fx := _fixture(5)
	var before := fx.state.to_bytes()

	var poor := fx.research(REPOS)
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	var off_turn := _fixture(99)
	GameStateSetup.set_phase(off_turn.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)

	assert_str(poor.code).is_equal(Refusal.NOT_ENOUGH_ENERGY)
	assert_array(StatePayload.with_column(fx.state, &"_header", before_header(before))).is_equal(before)
	assert_array(fx.sink.batches).is_empty()
	assert_str(off_turn.research(REPOS).code).is_equal(Refusal.NOT_YOUR_TURN)


## Header of a serialized state (the test changed the phase after the refusal).
func before_header(bytes: PackedByteArray) -> PackedInt64Array:
	var data: Array = bytes_to_var(bytes)
	return data[StatePayload.column_index(StateFactory.minimal(), &"_header")]


func test_started_research_completes_through_the_turns() -> void:
	var fx := _fixture(20)
	fx.research(REPOS)
	fx.end_turn()
	fx.begin_turn(Faction.AI)
	fx.begin_turn(Faction.PLAYER)
	fx.end_turn()
	fx.begin_turn(Faction.AI)

	fx.begin_turn(Faction.PLAYER)

	assert_bool(fx.state.protocols.has(Faction.PLAYER, REPOS)).is_true()


func test_codec_round_trips_research() -> void:
	var decoded := CommandCodec.decode(CommandCodec.encode(ResearchCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, BLINDAGE)))

	assert_int((decoded as ResearchCommand).protocol).is_equal(BLINDAGE)
	assert_object(CommandCodec.decode(PackedInt64Array([CommandType.RESEARCH, 0, 0]))).is_null()
