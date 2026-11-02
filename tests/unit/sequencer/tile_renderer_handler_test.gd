extends GdUnitTestSuite


func _setup() -> Array:
	var catalog := CatalogFactory.standard()
	var state := GameStateFactory.new_game(catalog, TestSessionFactory.shipped_map(catalog), 3)
	var renderer := TileRenderer.new()
	renderer.show_state(state, catalog)
	renderer.fit(Rect2(0, 118, 390, 520))
	var clock := FakeClock.new()
	renderer.clock = clock
	return [TileRendererHandler.new(renderer, catalog.presentation), renderer, clock, state]


func _context(clock: FakeClock, reduced: bool = false, direct: bool = false) -> SequenceContext:
	return SequenceContext.new(clock.current(), clock, direct, reduced)


func test_a_move_slides_the_unit_for_a_step_time_per_tile() -> void:
	var set_up := _setup()
	var handler: TileRendererHandler = set_up[0]
	var renderer: TileRenderer = set_up[1]
	var clock: FakeClock = set_up[2]
	var moved := UnitMovedEvent.new(0, 5, 14, 17, 17)  # 3 tiles along a row (12 columns)

	var hold := handler.handle(moved, _context(clock))

	assert_int(hold.duration_ms).is_equal(3 * 120)
	assert_int(renderer.effects.size()).is_equal(1)
	var effect := renderer.effects[0]
	assert_array([effect.kind, effect.unit_id, effect.tile, effect.tile2]).is_equal([TileEffect.Kind.MOVE, 5, 14, 17])
	assert_float(effect.duration).is_equal_approx(0.36, 0.0001)
	renderer.free()


func test_the_unit_is_drawn_along_its_slide() -> void:
	var set_up := _setup()
	var handler: TileRendererHandler = set_up[0]
	var renderer: TileRenderer = set_up[1]
	var clock: FakeClock = set_up[2]
	handler.handle(UnitMovedEvent.new(0, 5, 14, 17, 17), _context(clock))

	assert_vector(renderer._moving_center(5)).is_equal(renderer.layout.center_of(14))
	clock.advance(0.18)
	assert_vector(renderer._moving_center(5)).is_equal_approx(renderer.layout.center_of(14).lerp(renderer.layout.center_of(17), 0.5), Vector2(0.01, 0.01))
	assert_vector(renderer._moving_center(6)).is_equal(Vector2(-1, -1))
	renderer.free()


func test_reduced_motion_and_direct_display_shorten_slides_and_waves_but_not_the_attack() -> void:
	var set_up := _setup()
	var handler: TileRendererHandler = set_up[0]
	var renderer: TileRenderer = set_up[1]
	var clock: FakeClock = set_up[2]
	var wave := TileOwnersChangedEvent.new(PackedInt32Array([1, 2]), Faction.NONE, Faction.PLAYER)

	assert_int(handler.handle(wave, _context(clock)).duration_ms).is_equal(400)
	assert_int(handler.handle(wave, _context(clock, true)).duration_ms).is_equal(0)
	assert_int(handler.handle(UnitMovedEvent.new(0, 5, 14, 17, 17), _context(clock, true)).duration_ms).is_equal(0)
	assert_int(handler.handle(UnitMovedEvent.new(0, 5, 14, 17, 17), _context(clock, false, true)).duration_ms).is_equal(0)
	assert_int(handler.handle(AttackResolvedEvent.new(0, 1, 2, 14, 15), _context(clock, true)).duration_ms).is_equal(250)
	assert_float(renderer.effects[renderer.effects.size() - 1].duration).is_equal(0.25)  # the line keeps its 250 ms in reduced motion
	assert_int(handler.handle(UnitHitEvent.new(1, 2, 3, 4, 15), _context(clock, true)).duration_ms).is_equal(350)
	renderer.free()


func test_a_blow_draws_a_line_and_the_hit_shows_its_number_for_800_ms() -> void:
	var set_up := _setup()
	var handler: TileRendererHandler = set_up[0]
	var renderer: TileRenderer = set_up[1]
	var clock: FakeClock = set_up[2]

	handler.handle(AttackResolvedEvent.new(0, 1, 2, 14, 15), _context(clock))
	handler.handle(UnitHitEvent.new(1, 2, 4, 3, 15), _context(clock))

	assert_array([renderer.effects[0].kind, renderer.effects[0].tile, renderer.effects[0].tile2]).is_equal([TileEffect.Kind.LINE, 14, 15])
	assert_str(renderer.effects[1].text).is_equal("−4")
	assert_float(renderer.effects[1].duration).is_equal(0.8)
	handler.handle(UnitHealedEvent.new(0, 1, 3, 5, 14), _context(clock))
	assert_str(renderer.effects[2].text).is_equal("+2")
	renderer.free()


func test_a_destroyed_unit_sags_with_the_silhouette_it_had() -> void:
	var set_up := _setup()
	var handler: TileRendererHandler = set_up[0]
	var renderer: TileRenderer = set_up[1]
	var clock: FakeClock = set_up[2]
	var unit: Array = renderer.snapshot.units[0]

	var hold := handler.handle(UnitDestroyedEvent.new(unit[2], unit[0], unit[1], -1), _context(clock))

	assert_int(hold.duration_ms).is_equal(400)
	assert_array([renderer.effects[0].kind, renderer.effects[0].unit_type]).is_equal([TileEffect.Kind.GHOST, unit[3]])
	renderer.free()


func test_a_recolouring_spreads_in_the_colour_of_the_new_owner() -> void:
	var set_up := _setup()
	var handler: TileRendererHandler = set_up[0]
	var renderer: TileRenderer = set_up[1]
	var clock: FakeClock = set_up[2]

	handler.handle(TileOwnersChangedEvent.new(PackedInt32Array([3, 4]), Faction.NONE, Faction.AI), _context(clock))

	assert_array(Array(renderer.effects[0].tiles)).is_equal([3, 4])
	assert_object(renderer.effects[0].color).is_equal(TilePalette.ENEMY)
	renderer.free()


func test_effects_expire_with_the_clock_and_a_rebuild_clears_them() -> void:
	var set_up := _setup()
	var handler: TileRendererHandler = set_up[0]
	var renderer: TileRenderer = set_up[1]
	var clock: FakeClock = set_up[2]
	handler.handle(UnitHitEvent.new(1, 2, 4, 3, 15), _context(clock))
	handler.handle(UnitDestroyedEvent.new(0, 1, 14, -1), _context(clock))

	clock.advance(0.5)
	renderer._process(0.0)
	assert_int(renderer.effects.size()).is_equal(1)  # the 400 ms ghost is over, the 800 ms number is not
	clock.advance(0.4)
	renderer._process(0.0)
	assert_int(renderer.effects.size()).is_equal(0)
	handler.handle(UnitHitEvent.new(1, 2, 4, 3, 15), _context(clock))
	handler.rebuild_from_state(set_up[3])

	assert_int(renderer.effects.size()).is_equal(0)
	renderer.free()


func test_only_the_tiles_inside_the_map_area_are_drawn() -> void:
	var set_up := _setup()
	var renderer: TileRenderer = set_up[1]
	renderer.layout = TileLayout.new(12, 12, 32.0, Vector2(0, 0))

	renderer.set_clip_rect(Rect2(64, 32, 96, 64))  # 3 columns x 2 rows, x 2..4, y 1..2
	var shown := Array(renderer.visible_tiles())
	shown.sort()

	assert_array(shown).is_equal([14, 15, 16, 26, 27, 28])
	renderer.set_clip_rect(Rect2(70, 40, 40, 20))  # cuts tiles in the middle: partly shown
	assert_int(renderer.visible_tiles().size()).is_equal(2)
	renderer.free()


func test_the_colour_wave_follows_the_colour_blind_palette() -> void:
	var set_up := _setup()
	var handler: TileRendererHandler = set_up[0]
	var renderer: TileRenderer = set_up[1]
	var clock: FakeClock = set_up[2]
	var wave := TileOwnersChangedEvent.new(PackedInt32Array([1]), Faction.NONE, Faction.PLAYER)

	handler.handle(wave, _context(clock))
	renderer.colorblind = true
	handler.handle(wave, _context(clock))

	assert_object(renderer.effects[0].color).is_equal(TilePalette.PLAYER)
	assert_object(renderer.effects[1].color).is_equal(TilePalette.PLAYER_ALT)
	renderer.free()


func test_only_the_ownership_colours_change_in_the_colour_blind_palette() -> void:
	assert_object(TilePalette.owner(Faction.PLAYER, true)).is_equal(Color("3A8EE6"))
	assert_object(TilePalette.owner(Faction.AI, true)).is_equal(Color("F0DC6E"))
	assert_object(TilePalette.owner(Faction.NONE, true)).is_equal(Color("5F6266"))
	assert_object(TilePalette.owner(Faction.PLAYER)).is_equal(TilePalette.PLAYER)
	assert_object(TilePalette.owner(Faction.AI)).is_equal(TilePalette.ENEMY)
	assert_object(TilePalette.owner(Faction.NONE)).is_equal(TilePalette.NEUTRAL)
	assert_object(TilePalette.THREAT).is_equal(Color("FF6A3D"))
	assert_object(TilePalette.RUIN).is_equal(Color("C8955A"))
