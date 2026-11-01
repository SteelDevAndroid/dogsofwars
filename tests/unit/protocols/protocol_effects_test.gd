extends GdUnitTestSuite

const ECLAIREUR := 0
const ASSAUT := 1
const REMPART := 2
const SENTINELLE := 4
const VEILLE := 0
const REVEIL_SOBRE := 1
const CADENCE := 2
const REPOS := 3
const BLINDAGE := 4
const REMPART_ARME := 5


func _with(protocols: PackedInt32Array, faction: int = Faction.PLAYER) -> GameState:
	var state := StateFactory.minimal()
	for protocol in protocols:
		ResearchRules.acquire(state, faction, protocol)
	return state


func _stat(state: GameState, faction: int, type: int, stat: int) -> int:
	return ProtocolEffects.unit_stat(state.view(), faction, type, stat, CatalogFactory.standard())


func test_without_protocols_the_stat_is_the_base() -> void:
	var state := _with(PackedInt32Array())

	assert_int(_stat(state, Faction.PLAYER, ASSAUT, ProtocolEffects.VISION)).is_equal(2)
	assert_int(_stat(state, Faction.PLAYER, REMPART, ProtocolEffects.DEFENSE)).is_equal(2)


func test_veille_elargie_widens_the_view_of_the_listed_types_only() -> void:
	var state := _with(PackedInt32Array([VEILLE]))

	assert_int(_stat(state, Faction.PLAYER, ASSAUT, ProtocolEffects.VISION)).is_equal(3)
	assert_int(_stat(state, Faction.PLAYER, ECLAIREUR, ProtocolEffects.VISION)).is_equal(4)


func test_effects_follow_the_owner_of_the_protocol() -> void:
	var state := _with(PackedInt32Array([VEILLE, BLINDAGE]))

	assert_int(_stat(state, Faction.AI, ASSAUT, ProtocolEffects.VISION)).is_equal(2)
	assert_int(_stat(state, Faction.AI, SENTINELLE, ProtocolEffects.DEFENSE)).is_equal(2)
	var ai_state := _with(PackedInt32Array([BLINDAGE]), Faction.AI)
	assert_int(_stat(ai_state, Faction.AI, SENTINELLE, ProtocolEffects.DEFENSE)).is_equal(3)


func test_blindage_covers_every_type_and_rempart_arme_the_rempart_only() -> void:
	var state := _with(PackedInt32Array([BLINDAGE, REMPART_ARME]))

	assert_int(_stat(state, Faction.PLAYER, ECLAIREUR, ProtocolEffects.DEFENSE)).is_equal(1)
	assert_int(_stat(state, Faction.PLAYER, REMPART, ProtocolEffects.ATTACK)).is_equal(2)
	assert_int(_stat(state, Faction.PLAYER, ASSAUT, ProtocolEffects.ATTACK)).is_equal(3)


func test_zero_stays_zero_for_move_and_attack_and_floors_apply() -> void:
	assert_int(ProtocolEffects.bounded(0, 1, ProtocolEffects.MOVE)).is_equal(0)
	assert_int(ProtocolEffects.bounded(0, 1, ProtocolEffects.ATTACK)).is_equal(0)
	assert_int(ProtocolEffects.bounded(0, 1, ProtocolEffects.DEFENSE)).is_equal(1)
	assert_int(ProtocolEffects.bounded(1, -1, ProtocolEffects.WAKE_PRICE)).is_equal(1)
	assert_int(ProtocolEffects.bounded(2, -3, ProtocolEffects.DEFENSE)).is_equal(0)


func test_bases_from_other_systems_are_adjusted() -> void:
	var state := _with(PackedInt32Array([REVEIL_SOBRE, REPOS]))
	var catalog := CatalogFactory.standard()

	assert_int(ProtocolEffects.adjusted(4, state.view(), Faction.PLAYER, ASSAUT, ProtocolEffects.WAKE_PRICE, catalog)).is_equal(3)
	assert_int(ProtocolEffects.adjusted(1, state.view(), Faction.PLAYER, ASSAUT, ProtocolEffects.WAKE_PRICE, catalog)).is_equal(1)
	assert_int(ProtocolEffects.adjusted(2, state.view(), Faction.PLAYER, ASSAUT, ProtocolEffects.REST_HEAL, catalog)).is_equal(3)


func test_cadence_de_marche_lengthens_the_move() -> void:
	var state := MapBuilder.state(PackedStringArray([".........."]))
	var unit := MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	ResearchRules.acquire(state, Faction.PLAYER, CADENCE)
	var fx := PipelineFixture.new(MapBuilder.ready(state))

	assert_bool(fx.move(unit, state.tile_index(4, 0)).permitted).is_true()


func test_veille_elargie_is_used_by_the_fog() -> void:
	var state := MapBuilder.state(PackedStringArray([".........."]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	ResearchRules.acquire(state, Faction.PLAYER, VEILLE)
	MapBuilder.ready(state)

	assert_int(VisionService.tile_state(state, Faction.PLAYER, 3)).is_equal(VisionService.VISIBLE)
	assert_int(VisionService.tile_state(state, Faction.PLAYER, 4)).is_equal(VisionService.UNKNOWN)


func test_completed_research_recomputes_the_view_and_reveals_tiles() -> void:
	var state := MapBuilder.state(PackedStringArray([".........."]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	MapBuilder.ready(state)
	var loaded := StatePayload.decoded_with(state, &"_fac_research_id", PackedInt32Array([VEILLE, -1]))
	loaded = StatePayload.decoded_with(loaded, &"_fac_research_turns", PackedInt32Array([1, 0]))
	VisionService.rebuild(loaded, StateFactory.vision_context(loaded))
	var fx := PipelineFixture.new(loaded, true)

	fx.begin_turn(Faction.PLAYER)

	var revealed := fx.last_events()[fx.last_events().size() - 1] as TilesRevealedEvent
	assert_array(revealed.revealed_tiles).is_equal(PackedInt32Array([3]))
	assert_int(VisionService.tile_state(loaded, Faction.PLAYER, 3)).is_equal(VisionService.VISIBLE)


func test_unknown_unit_type_in_an_effect_is_refused() -> void:
	var docs := CatalogFactory.documents()
	docs["protocoles.json"]["protocols"][0]["effects"][0]["types"] = ["assaut", "dragon"]

	var result := CatalogFactory.load_documents(docs)

	assert_bool(result.ok).is_false()
	assert_str(str(result.errors[0])).is_equal("protocoles.json: protocols[0].effects: unknown unit type dragon")
