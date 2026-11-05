extends GdUnitTestSuite

var _pressed := []


## A 200 x 200 list of ten 100-point buttons at the top left of the window.
func _list() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2.ZERO
	scroll.size = Vector2(200, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	scroll.add_child(box)
	for k in 10:
		var button := Button.new()
		button.text = str(k)
		button.custom_minimum_size = Vector2(180, 100)
		button.pressed.connect(func() -> void: _pressed.append(k))
		box.add_child(button)
	TouchScroll.attach(scroll)
	add_child(scroll)
	return scroll


func _touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	get_viewport().push_input(event)


func _drag(position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = position
	event.relative = relative
	get_viewport().push_input(event)


func test_a_finger_moved_up_scrolls_the_list_and_presses_nothing() -> void:
	_pressed.clear()
	var scroll := _list()
	await await_idle_frame()

	_touch(Vector2(90, 150), true)
	_drag(Vector2(90, 120), Vector2(0, -30))
	_drag(Vector2(90, 50), Vector2(0, -70))
	_touch(Vector2(90, 50), false)
	await await_idle_frame()

	assert_int(scroll.scroll_vertical).is_equal(100)
	assert_array(_pressed).is_empty()
	var touched := scroll.get_child(0).get_child(1) as Button
	assert_int(touched.get_draw_mode()).is_not_equal(BaseButton.DRAW_PRESSED)  # not left looking pressed
	scroll.free()


func test_a_tap_still_presses_the_button_under_the_finger() -> void:
	_pressed.clear()
	var scroll := _list()
	await await_idle_frame()

	_touch(Vector2(90, 150), true)
	_drag(Vector2(90, 146), Vector2(0, -4))  # within the dead zone
	_touch(Vector2(90, 146), false)
	await await_idle_frame()

	assert_int(scroll.scroll_vertical).is_equal(0)
	assert_array(_pressed).is_equal([1])
	scroll.free()


func test_a_touch_outside_the_list_is_left_alone() -> void:
	var scroll := _list()
	await await_idle_frame()

	_touch(Vector2(500, 150), true)
	_drag(Vector2(500, 50), Vector2(0, -100))
	_touch(Vector2(500, 50), false)

	assert_int(scroll.scroll_vertical).is_equal(0)
	scroll.free()
