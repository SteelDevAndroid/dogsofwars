extends GdUnitTestSuite

const WIDTH := 16
const SOURCE := 6 * WIDTH + 6  # (6,6), index 102


func _state(visible: Array) -> GameState:
	var rows := PackedStringArray()
	for y in WIDTH:
		rows.append(".".repeat(WIDTH))
	var state := MapBuilder.ready(MapBuilder.state(rows))
	state.view_cache.seen[Faction.PLAYER].fill(0)
	for tile: int in visible:
		state.view_cache.seen[Faction.PLAYER][tile] = 1
	return state


func _at(x: int, y: int) -> int:
	return y * WIDTH + x


func test_a_source_the_player_sees_is_the_effective_source() -> void:
	var state := _state([SOURCE])

	assert_int(WaveSource.effective(state, PackedInt32Array([SOURCE, 100]), SOURCE)).is_equal(SOURCE)


## GDD 15 AC-RC12: (4,5) and (8,7) are both at Chebyshev 2 of the hidden source, the lower index wins.
func test_a_hidden_source_is_replaced_by_the_nearest_visible_changed_tile() -> void:
	var state := _state([_at(4, 5), _at(8, 7), _at(9, 9)])
	var changed := PackedInt32Array([_at(4, 5), _at(8, 7), _at(9, 9), _at(6, 7)])  # (6,7) is hidden and nearer

	var effective := WaveSource.effective(state, changed, SOURCE)

	assert_int(effective).is_equal(_at(4, 5))
	assert_int(WaveSchedule.ring_of(WIDTH, effective, _at(8, 7))).is_equal(4)
	var plan := WaveSchedule.plan(WIDTH, PackedInt32Array([_at(8, 7)]), effective, CatalogFactory.standard().presentation)
	assert_int(plan.steps[0][0]).is_equal(600)  # min(4, K_MAX) x 200


## GDD 15 AC-RC13: nothing visible, no source, so no wave and nothing hidden is revealed.
func test_no_visible_changed_tile_gives_no_source() -> void:
	var state := _state([_at(0, 0)])

	assert_int(WaveSource.effective(state, PackedInt32Array([_at(4, 5), _at(8, 7)]), SOURCE)).is_equal(-1)


func test_stamp_sets_the_source_of_the_tile_owner_events_only() -> void:
	var state := _state([SOURCE])
	var wave := TileOwnersChangedEvent.new(PackedInt32Array([SOURCE]), Faction.NONE, Faction.PLAYER)
	var other := TilesRevealedEvent.new(PackedInt32Array([1]))
	var events: Array[PresentationEvent] = [wave, other]

	WaveSource.stamp(events, SOURCE, state)

	assert_int(wave.source_tile).is_equal(SOURCE)
	assert_int(TileOwnersChangedEvent.new(PackedInt32Array([1]), Faction.NONE, Faction.AI).source_tile).is_equal(-1)
