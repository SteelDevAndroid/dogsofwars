extends GdUnitTestSuite

const AREA := Rect2(0, 118, 390, 520)


func _setup() -> Array:
	var camera := MapCamera.new(12, 12, AREA)
	camera.center = Vector2(3, 3)
	return [CameraHandler.new(camera, CatalogFactory.standard().presentation), camera, FakeClock.new(5.0)]


func test_a_recentre_step_animates_the_camera_and_holds_for_its_duration() -> void:
	var set_up := _setup()
	var handler: CameraHandler = set_up[0]
	var camera: MapCamera = set_up[1]
	var clock: FakeClock = set_up[2]
	var tile := 8 * 12 + 9

	var hold := handler.handle(PresentationRecenter.new(tile), SequenceContext.new(5.0, clock))

	assert_int(hold.duration_ms).is_equal(300)
	assert_vector(camera.center).is_equal(Vector2(3, 3))
	camera.tick(5.3)
	assert_float(camera.center.x).is_greater(3.0)


func test_reduced_motion_and_direct_display_recentre_at_once() -> void:
	for flags in [[true, false], [false, true]]:
		var set_up := _setup()
		var camera: MapCamera = set_up[1]
		var clock: FakeClock = set_up[2]

		var hold := (set_up[0] as CameraHandler).handle(PresentationRecenter.new(8 * 12 + 9), SequenceContext.new(5.0, clock, flags[1], flags[0]))

		assert_int(hold.duration_ms).is_equal(0)
		assert_float(camera.center.x).is_greater(3.0)


func test_the_camera_follows_the_players_own_move_only() -> void:
	var set_up := _setup()
	var handler: CameraHandler = set_up[0]
	var camera: MapCamera = set_up[1]
	var context := SequenceContext.new(5.0, set_up[2])
	var far := 11 * 12 + 11
	assert_bool(camera.is_visible(far)).is_false()

	handler.handle(UnitMovedEvent.new(Faction.AI, 9, 5, far, far), context)
	assert_bool(camera.is_visible(far)).is_false()  # what the enemy does is not followed
	handler.handle(UnitMovedEvent.new(Faction.PLAYER, 9, 5, far, far), context)

	assert_bool(camera.is_visible(far)).is_true()


func test_the_camera_is_remembered_at_the_end_of_the_players_turn_and_given_back() -> void:
	var set_up := _setup()
	var handler: CameraHandler = set_up[0]
	var camera: MapCamera = set_up[1]
	var context := SequenceContext.new(5.0, set_up[2])

	handler.handle(TurnEndedEvent.new(3, Faction.AI), context)  # the enemy's end is not the player's
	camera.scroll(Vector2(-60, -60))
	handler.handle(TurnEndedEvent.new(3, Faction.PLAYER), context)
	var remembered := camera.center
	camera.scroll(Vector2(300, 300))
	handler.handle(TurnStartedEvent.new(4, Faction.AI, HeaderSlice.PHASE_ENEMY_EXECUTION), context)
	assert_vector(camera.center).is_not_equal(remembered)
	handler.handle(TurnStartedEvent.new(4, Faction.PLAYER, HeaderSlice.PHASE_PLAYER), context)

	assert_vector(camera.center).is_equal(remembered)
