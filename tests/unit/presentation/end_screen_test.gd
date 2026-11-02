extends GdUnitTestSuite


func test_the_result_shows_the_scores_the_gauge_the_fragments_and_the_quote() -> void:
	var screen := EndScreen.new()
	add_child(screen)

	screen.show_result(HeaderSlice.END_TURNS_WON, 30, 10, 2, "« Une lampe. »\n— Journal")

	assert_str(screen.title_label.text).is_equal("Victoire au tour 30")
	assert_str(screen.scores_label.text).is_equal("Meute 30  ·  Gardiens 10")
	assert_float(screen.gauge.value).is_equal(75.0)
	assert_str(screen.fragments_label.text).is_equal("Fragments lus : 2")
	assert_str(screen.quote_label.text).is_equal("« Une lampe. »\n— Journal")
	assert_bool(screen.quote_label.visible).is_true()
	screen.free()


func test_without_a_fragment_there_is_no_quote_and_no_scores_means_a_middle_gauge() -> void:
	var screen := EndScreen.new()
	add_child(screen)

	screen.show_result(HeaderSlice.END_ABANDONED, 0, 0)

	assert_bool(screen.quote_label.visible).is_false()
	assert_float(screen.gauge.value).is_equal(50.0)
	assert_str(screen.fragments_label.text).is_equal("Fragments lus : 0")
	screen.free()


func test_the_way_back_is_announced() -> void:
	var screen := EndScreen.new()
	add_child(screen)
	var backs := [0]
	screen.back_requested.connect(func() -> void: backs[0] += 1)

	screen.back_button.pressed.emit()

	assert_int(backs[0]).is_equal(1)
	screen.free()
