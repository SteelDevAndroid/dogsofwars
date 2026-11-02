extends GdUnitTestSuite


func _feed(interpreter: GestureInterpreter, events: Array) -> Array[Gesture]:
	var out: Array[Gesture] = []
	for event: PointerEvent in events:
		out.append_array(interpreter.feed(event))
	return out


func _down(index: int, at: Vector2) -> PointerEvent:
	return PointerEvent.new(index, PointerEvent.Phase.DOWN, at)


func _move(index: int, at: Vector2) -> PointerEvent:
	return PointerEvent.new(index, PointerEvent.Phase.MOVE, at)


func _up(index: int, at: Vector2) -> PointerEvent:
	return PointerEvent.new(index, PointerEvent.Phase.UP, at)


func test_a_touch_that_stays_put_is_a_tap_at_its_release_point() -> void:
	var interpreter := GestureInterpreter.new()

	var gestures := _feed(interpreter, [_down(0, Vector2(100, 100)), _move(0, Vector2(103, 102)), _up(0, Vector2(103, 102))])

	assert_int(gestures.size()).is_equal(1)
	assert_int(gestures[0].kind).is_equal(Gesture.Kind.TAP)
	assert_vector(gestures[0].position).is_equal(Vector2(103, 102))
	assert_bool(interpreter.is_free()).is_true()


func test_a_distance_equal_to_the_slop_is_still_a_tap_and_beyond_it_a_scroll() -> void:
	var interpreter := GestureInterpreter.new()
	interpreter.tile_size = 48.0  # slop 24
	var tap := _feed(interpreter, [_down(0, Vector2.ZERO), _move(0, Vector2(24, 0)), _up(0, Vector2(24, 0))])
	assert_int(tap[0].kind).is_equal(Gesture.Kind.TAP)

	var scroll := _feed(interpreter, [_down(0, Vector2.ZERO), _move(0, Vector2(25, 0)), _move(0, Vector2(30, 5)), _up(0, Vector2(30, 5))])

	assert_int(scroll.size()).is_equal(2)
	assert_vector(scroll[0].delta).is_equal(Vector2(25, 0))  # from where the finger went down
	assert_vector(scroll[1].delta).is_equal(Vector2(5, 5))
	assert_bool(scroll.all(func(g: Gesture) -> bool: return g.kind == Gesture.Kind.SCROLL)).is_true()


func test_the_slop_follows_the_zoom() -> void:
	var interpreter := GestureInterpreter.new()
	interpreter.tile_size = 24.0  # slop 12

	var gestures := _feed(interpreter, [_down(0, Vector2.ZERO), _move(0, Vector2(13, 0))])

	assert_int(gestures[0].kind).is_equal(Gesture.Kind.SCROLL)


func test_going_beyond_the_slop_and_coming_back_is_never_a_tap() -> void:
	var interpreter := GestureInterpreter.new()

	var gestures := _feed(interpreter, [_down(0, Vector2.ZERO), _move(0, Vector2(40, 0)), _move(0, Vector2(1, 0)), _up(0, Vector2(1, 0))])

	assert_bool(gestures.any(func(g: Gesture) -> bool: return g.kind == Gesture.Kind.TAP)).is_false()


func test_two_fingers_pinch_with_the_ratio_of_their_distances() -> void:
	var interpreter := GestureInterpreter.new()

	var gestures := _feed(interpreter, [_down(0, Vector2(100, 100)), _down(1, Vector2(200, 100)), _move(1, Vector2(300, 100)), _move(1, Vector2(250, 100))])

	assert_int(gestures.size()).is_equal(2)
	assert_float(gestures[0].factor).is_equal_approx(2.0, 0.0001)  # 100 -> 200
	assert_float(gestures[1].factor).is_equal_approx(0.75, 0.0001)  # 200 -> 150
	assert_vector(gestures[0].position).is_equal(Vector2(200, 100))


func test_a_pinch_ends_and_the_finger_left_does_nothing_until_it_lifts() -> void:
	var interpreter := GestureInterpreter.new()
	_feed(interpreter, [_down(0, Vector2(100, 100)), _down(1, Vector2(200, 100))])

	var gestures := _feed(interpreter, [_up(1, Vector2(200, 100)), _move(0, Vector2(300, 300)), _up(0, Vector2(300, 300))])

	assert_int(gestures.size()).is_equal(1)
	assert_int(gestures[0].kind).is_equal(Gesture.Kind.PINCH_END)
	assert_bool(interpreter.is_free()).is_true()


func test_a_scroll_that_gets_a_second_finger_becomes_a_pinch() -> void:
	var interpreter := GestureInterpreter.new()
	_feed(interpreter, [_down(0, Vector2(100, 100)), _move(0, Vector2(200, 100))])

	var gestures := _feed(interpreter, [_down(1, Vector2(300, 100)), _move(1, Vector2(400, 100))])

	assert_int(gestures[0].kind).is_equal(Gesture.Kind.PINCH_UPDATE)


func test_a_cancel_resets_everything_and_a_second_down_on_the_same_finger_cancels_first() -> void:
	var interpreter := GestureInterpreter.new()
	_feed(interpreter, [_down(0, Vector2(100, 100))])

	var cancelled := _feed(interpreter, [PointerEvent.new(0, PointerEvent.Phase.CANCEL)])
	assert_int(cancelled[0].kind).is_equal(Gesture.Kind.CANCEL)
	assert_bool(interpreter.is_free()).is_true()
	assert_int(_feed(interpreter, [PointerEvent.new(0, PointerEvent.Phase.CANCEL)]).size()).is_equal(0)  # nothing to cancel

	_feed(interpreter, [_down(0, Vector2(10, 10))])
	var again := _feed(interpreter, [_down(0, Vector2(50, 50)), _up(0, Vector2(50, 50))])

	assert_array(again.map(func(g: Gesture) -> int: return g.kind)).is_equal([Gesture.Kind.CANCEL, Gesture.Kind.TAP])


func test_moves_and_releases_of_unknown_fingers_are_ignored() -> void:
	var interpreter := GestureInterpreter.new()

	assert_int(_feed(interpreter, [_move(3, Vector2(1, 1)), _up(3, Vector2(1, 1))]).size()).is_equal(0)


func test_a_new_finger_during_the_orphan_of_a_pinch_does_nothing() -> void:
	var interpreter := GestureInterpreter.new()
	_feed(interpreter, [_down(0, Vector2(100, 100)), _down(1, Vector2(200, 100)), _up(1, Vector2(200, 100))])

	var gestures := _feed(interpreter, [_down(2, Vector2(50, 50)), _up(2, Vector2(50, 50))])

	assert_int(gestures.size()).is_equal(0)
