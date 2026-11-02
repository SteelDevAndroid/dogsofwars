extends GdUnitTestSuite

const ECLAIREUR := 0
const ASSAUT := 1
const CHASSEUR := 5


## 10 x 5 plain. Player Eclaireur 0 at (0,2) (MVT 4). Ruin 0 at (3,2) (zone radius 2:
## x 1..5, y 0..4). AI Chasseur 1 at (9,4) with its node at (5,0) in the zone (an
## enemy tile is never taken), another AI node far away. Ruin 1 at (3,0) is the second one.
func _board(enemy_node_in_zone: bool = true) -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray(["..........", "..........", "..........", "..........", ".........."]))
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 0, 2)
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 9, 4)
	if enemy_node_in_zone:
		GameStateSetup.add_node(state, state.tile_index(5, 0), Faction.AI, 1)
	GameStateSetup.add_node(state, state.tile_index(9, 4), Faction.AI, 1)
	GameStateSetup.add_node(state, state.tile_index(0, 4), Faction.PLAYER, 1)
	TerritoryRules.recompute(state, CatalogFactory.standard().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.add_ruin(state, state.tile_index(3, 2), 0, Faction.PLAYER)
	GameStateSetup.add_ruin(state, state.tile_index(3, 0), 1, Faction.PLAYER)
	return PipelineFixture.new(MapBuilder.ready(state))


func test_ending_a_move_on_a_ruin_reads_it_in_the_same_command() -> void:
	var fx := _board()
	var tile := fx.state.tile_index(3, 2)

	assert_bool(fx.move(0, tile).permitted).is_true()

	assert_bool(fx.state.ruins.is_read(0)).is_true()
	assert_array([fx.state.ruins.read_turn_of(0), fx.state.ruins.reader_of(0)]).is_equal([fx.state.turn(), Faction.PLAYER])
	assert_int(fx.state.ruin_journal.read_by(Faction.PLAYER)).is_equal(1)
	var events := fx.sink.batches[0].events
	var read := events.filter(func(event: PresentationEvent) -> bool: return event is RuinReadEvent)
	assert_array(read.map(func(event: RuinReadEvent) -> Array: return [event.ruin_id, event.fragment_id, event.tile]))\
			.is_equal([[0, 1, tile]])
	assert_bool(events.any(func(event: PresentationEvent) -> bool: return event is TileOwnersChangedEvent)).is_true()


func test_the_zone_is_recoloured_without_taking_an_enemy_tile() -> void:
	var fx := _board()

	fx.move(0, fx.state.tile_index(3, 2))

	var map := fx.state.map
	assert_int(map.owner_at(fx.state.tile_index(2, 1))).is_equal(Faction.PLAYER)
	assert_int(map.anchor_at(fx.state.tile_index(2, 1))).is_equal(MapSlice.ANCHOR_RUIN)
	assert_int(map.owner_at(fx.state.tile_index(5, 0))).is_equal(Faction.AI)
	assert_int(map.owner_at(fx.state.tile_index(6, 2))).is_equal(Faction.NONE)  # outside the radius
	assert_int(map.owner_at(fx.state.tile_index(1, 0))).is_equal(Faction.PLAYER)  # corners of the square
	assert_int(map.owner_at(fx.state.tile_index(5, 4))).is_equal(Faction.PLAYER)
	assert_int(map.owner_at(fx.state.tile_index(0, 2))).is_equal(Faction.NONE)
	assert_int(map.owner_at(fx.state.tile_index(3, 2))).is_equal(Faction.PLAYER)


func test_the_profile_write_is_followed_by_the_validation_command() -> void:
	var fx := _board()

	fx.move(0, fx.state.tile_index(3, 2))

	assert_int(fx.profile.fragments_of(Faction.PLAYER).size()).is_equal(1)
	assert_int(fx.profile.fragments_of(Faction.PLAYER)[0]).is_equal(1)
	assert_int(fx.state.ruin_journal.status_of(0)).is_equal(RuinJournalSlice.VALIDATED)
	assert_int(fx.state.revision()).is_equal(2)  # the move, then the validation
	assert_array(fx.log.commands.map(func(values: PackedInt64Array) -> int: return values[0])) \
			.is_equal([CommandType.MOVE, CommandType.VALIDATE_RUIN_READ])


func test_a_failed_profile_write_leaves_the_entry_pending_until_retried() -> void:
	var fx := _board()
	fx.profile.fail_writes = true

	fx.move(0, fx.state.tile_index(3, 2))

	assert_int(fx.state.ruin_journal.status_of(0)).is_equal(RuinJournalSlice.PENDING)
	assert_int(fx.state.revision()).is_equal(1)
	fx.profile.fail_writes = false
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)  # retried during the enemy phase
	assert_bool(fx.pipeline.submit(ValidateRuinReadCommand.new(Faction.PLAYER, 0)).permitted).is_true()
	assert_int(fx.state.ruin_journal.status_of(0)).is_equal(RuinJournalSlice.VALIDATED)
	assert_str(fx.pipeline.submit(ValidateRuinReadCommand.new(Faction.PLAYER, 0)).code).is_equal(Refusal.NO_PENDING_READ)
	assert_str(fx.pipeline.submit(ValidateRuinReadCommand.new(Faction.PLAYER, 9)).code).is_equal(Refusal.NO_PENDING_READ)


func test_crossing_a_ruin_reads_nothing_and_a_ruin_is_read_once() -> void:
	var fx := _board()
	fx.move(0, fx.state.tile_index(4, 2))
	assert_bool(fx.state.ruins.is_read(0)).is_false()
	assert_int(fx.state.revision()).is_equal(1)

	var again := _board()
	again.move(0, again.state.tile_index(3, 2))
	for tile in [again.state.tile_index(3, 1), again.state.tile_index(3, 2)]:
		GameStateSetup.set_phase(again.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
		again.begin_turn(Faction.PLAYER)
		assert_bool(again.move(0, tile).permitted).is_true()

	assert_int(again.state.ruin_journal.read_by(Faction.PLAYER)).is_equal(1)
	assert_int(again.state.ruin_journal.row_count()).is_equal(1)


func test_the_next_fragment_skips_the_chronicle_and_the_journal() -> void:
	var fx := _board()
	GameStateSetup.add_chronicle_fragment(fx.state, Faction.PLAYER, 1)
	var rules := fx.rules

	assert_int(RuinRules.next_fragment(fx.state, Faction.PLAYER, rules.catalog.fragments)).is_equal(2)
	fx.move(0, fx.state.tile_index(3, 2))
	assert_int(RuinRules.next_fragment(fx.state, Faction.PLAYER, rules.catalog.fragments)).is_equal(3)
	assert_int(fx.state.ruin_journal.fragment_of(0)).is_equal(2)


func test_an_exhausted_pool_gives_the_zone_and_the_score_only() -> void:
	var fx := _board()
	for fragment in [1, 2, 3, 4, 5]:
		GameStateSetup.add_chronicle_fragment(fx.state, Faction.PLAYER, fragment)

	fx.move(0, fx.state.tile_index(3, 2))

	assert_int(fx.profile.calls.size()).is_equal(0)
	assert_int(fx.state.ruin_journal.fragment_of(0)).is_equal(0)
	assert_int(fx.state.ruin_journal.status_of(0)).is_equal(RuinJournalSlice.VALIDATED)
	assert_int(fx.state.ruin_journal.read_by(Faction.PLAYER)).is_equal(1)
	assert_int(fx.state.map.owner_at(fx.state.tile_index(2, 1))).is_equal(Faction.PLAYER)
	assert_int((fx.sink.batches[0].events.filter(func(event: PresentationEvent) -> bool: return event is RuinReadEvent)[0] as RuinReadEvent).fragment_id).is_equal(0)


func test_the_ai_reads_nothing() -> void:
	var fx := _board()
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	var unit := MapBuilder.unit(fx.state, CHASSEUR, Faction.AI, 3, 3)
	VisionService.recompute(fx.state, fx.rules.vision)

	assert_bool(fx.move(unit, fx.state.tile_index(3, 2), Faction.AI).permitted).is_true()

	assert_bool(fx.state.ruins.is_read(0)).is_false()
	assert_int(fx.state.ruin_journal.row_count()).is_equal(0)


func test_a_reading_cannot_be_undone() -> void:
	var fx := _board(false)  # nothing else is revealed by the move: only the reading disarms the undo
	fx.move(0, fx.state.tile_index(3, 2))

	assert_str(fx.undo_move().code).is_equal(Refusal.MOVE_REVEALED)


func test_the_whole_reading_replays_to_an_equal_state() -> void:
	var raw := _board()
	var initial := raw.state.duplicate_state()
	raw.move(0, raw.state.tile_index(3, 2))

	var outcome := CommandReplay.replay(initial, raw.log, CatalogFactory.standard())

	assert_int(outcome.divergence).is_equal(-1)
	assert_bool(outcome.state.equals(raw.state)).is_true()


func test_fragment_data_is_checked() -> void:
	var docs := CatalogFactory.documents()
	docs["fragments.json"]["zone_radius"] = 0

	var result := CatalogFactory.load_documents(docs)

	assert_array(result.errors.map(func(error: DataError) -> String: return error.to_string())).contains(["fragments.json: zone_radius: 0 outside 1..4"])

	var duplicated := CatalogFactory.documents()
	duplicated["fragments.json"]["fragments"][2]["id"] = 1

	assert_array(CatalogFactory.load_documents(duplicated).errors.map(func(error: DataError) -> String: return error.to_string())) \
			.contains(["fragments.json: fragments[2].id: duplicate id 1"])


func test_a_zone_that_changes_no_tile_still_reads_but_publishes_no_colour_event() -> void:
	var fx := _board()
	fx.move(0, fx.state.tile_index(3, 2))
	GameStateSetup.set_phase(fx.state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	fx.begin_turn(Faction.PLAYER)

	assert_bool(fx.move(0, fx.state.tile_index(3, 0)).permitted).is_true()

	assert_bool(fx.state.ruins.is_read(1)).is_true()
	var batch: EventBatch = fx.sink.batches.filter(func(b: EventBatch) -> bool: return b.events.any(func(e: PresentationEvent) -> bool: return e is RuinReadEvent and (e as RuinReadEvent).ruin_id == 1))[0]
	assert_bool(batch.events.any(func(e: PresentationEvent) -> bool: return e is TileOwnersChangedEvent)).is_false()


func test_the_last_fragment_read_by_a_faction_is_the_highest_row() -> void:
	var fx := PipelineFixture.new(StateFactory.minimal())
	assert_int(fx.state.ruin_journal.last_fragment_of(Faction.PLAYER)).is_equal(0)

	RuinWrites.journal_add(fx.state, 1, Faction.PLAYER, 2)
	RuinWrites.journal_add(fx.state, 2, Faction.AI, 9)
	RuinWrites.journal_add(fx.state, 3, Faction.PLAYER, 4)

	assert_int(fx.state.ruin_journal.last_fragment_of(Faction.PLAYER)).is_equal(4)
	assert_int(fx.state.ruin_journal.last_fragment_of(Faction.AI)).is_equal(9)
	assert_int(fx.state.ruin_journal.last_fragment_of(Faction.NONE)).is_equal(0)
