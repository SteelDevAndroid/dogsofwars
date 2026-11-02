extends GdUnitTestSuite

const ASSAUT := 1
const ECLAIREUR := 0
const CHASSEUR := 5
const SENTINELLE := 4


## 12 x 1 corridor, turn 5, AI phase about to begin. AI Sentinelle 0 at (0,0) (vision 3).
## Player Assaut 1 at (2,0) (visible), Eclaireur 2 at (9,0) (hidden).
func _board() -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray(["............"]))
	MapBuilder.unit(state, SENTINELLE, Faction.AI, 0, 0)
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 2, 0)
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 9, 0)
	GameStateSetup.add_node(state, state.tile_index(0, 0), Faction.AI, 1)
	GameStateSetup.add_node(state, state.tile_index(9, 0), Faction.PLAYER, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 5)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_END_OF_TURN, Faction.AI)
	return PipelineFixture.new(MapBuilder.ready(state))


func _rows(fx: PipelineFixture) -> Array:
	var tracks := fx.state.ai_tracks
	var rows := []
	for row in tracks.row_count():
		rows.append([tracks.unit_of(row), tracks.tile_of(row), tracks.seen_turn_of(row), tracks.kind_of(row)])
	return rows


func test_a_visible_player_unit_is_tracked_and_a_hidden_one_is_not() -> void:
	var fx := _board()

	assert_bool(fx.begin_turn(Faction.AI).permitted).is_true()

	assert_array(_rows(fx)).is_equal([[1, 2, 5, ASSAUT]])


func test_a_track_is_kept_while_its_tile_stays_out_of_view_then_expires() -> void:
	var fx := _board()
	fx.begin_turn(Faction.AI)
	UnitWrites.move_to(fx.state, 1, fx.state.tile_index(6, 0))
	VisionService.recompute(fx.state, fx.rules.vision)
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_END_OF_TURN, Faction.AI)
	GameStateSetup.set_turn(fx.state, 8)
	fx.begin_turn(Faction.AI)
	# tile (2,0) is visible and empty: the track is dropped
	assert_array(_rows(fx)).is_empty()

	GameStateSetup.set_turn(fx.state, 5)
	AiWrites.set_tracks(fx.state, [[2, 9, 5, ECLAIREUR]])
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_END_OF_TURN, Faction.AI)
	GameStateSetup.set_turn(fx.state, 8)
	fx.begin_turn(Faction.AI)
	assert_array(_rows(fx)).is_equal([[2, 9, 5, ECLAIREUR]])

	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_END_OF_TURN, Faction.AI)
	GameStateSetup.set_turn(fx.state, 9)  # age 4 = PISTES_TTL: still kept
	fx.begin_turn(Faction.AI)
	assert_array(_rows(fx)).is_equal([[2, 9, 5, ECLAIREUR]])

	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_END_OF_TURN, Faction.AI)
	GameStateSetup.set_turn(fx.state, 10)
	fx.begin_turn(Faction.AI)
	assert_array(_rows(fx)).is_empty()


func test_a_seen_unit_updates_its_track() -> void:
	var fx := _board()
	AiWrites.set_tracks(fx.state, [[1, 8, 3, ASSAUT]])

	fx.begin_turn(Faction.AI)

	assert_array(_rows(fx)).is_equal([[1, 2, 5, ASSAUT]])


func test_the_player_turn_does_not_touch_the_tracks() -> void:
	var fx := _board()
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)

	fx.begin_turn(Faction.PLAYER)

	assert_array(_rows(fx)).is_empty()


func test_at_most_sixteen_tracks_the_oldest_dropped_first() -> void:
	var fx := _board()
	var seeded := []
	for unit in 17:
		seeded.append([100 + unit, 11, 5 - (unit % 3), ASSAUT])
	AiWrites.set_tracks(fx.state, seeded)
	GameStateSetup.set_turn(fx.state, 5)

	fx.begin_turn(Faction.AI)

	var rows := _rows(fx)
	assert_int(rows.size()).is_equal(GameState.MAX_TRACKS)
	assert_bool(rows.any(func(row: Array) -> bool: return row[0] == 1)).is_true()
	var ids := rows.map(func(row: Array) -> int: return row[0])
	assert_bool(ids.has(102) or ids.has(105)).is_false()  # the two oldest, lowest ids first
	assert_bool(ids.has(108)).is_true()
	for k in range(1, rows.size()):
		assert_bool(rows[k - 1][0] < rows[k][0]).is_true()


func test_ttl_comes_from_the_data() -> void:
	var docs := CatalogFactory.documents()
	docs["ai.json"]["track_ttl"] = 0

	var result := CatalogFactory.load_documents(docs)

	assert_bool(result.ok).is_false()
	assert_array(result.errors.map(func(error: DataError) -> String: return error.to_string())).contains(["ai.json: track_ttl: 0 outside 1..30"])
