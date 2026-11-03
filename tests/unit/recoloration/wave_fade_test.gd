extends GdUnitTestSuite

const D := 400  # T_FONDU
const FRIEND := Faction.PLAYER
const FOE := Faction.AI
const GREY := Faction.NONE


func _s(from_owner: int, from_s: int, to_owner: int, u: int) -> Array:
	var state := WaveFade.shown(from_owner, from_s, to_owner, u, D)
	return [state.x, state.y]


## GDD 15 F5, grey to a tint: the saturation rises from 0 to 1000 over D.
func test_grey_to_a_tint_rises_over_the_whole_fade() -> void:
	assert_array(_s(GREY, 0, FRIEND, 0)).is_equal([FRIEND, 0])
	assert_array(_s(GREY, 0, FRIEND, 100)).is_equal([FRIEND, 250])
	assert_array(_s(GREY, 0, FRIEND, 200)).is_equal([FRIEND, 500])
	assert_array(_s(GREY, 0, FRIEND, D)).is_equal([FRIEND, 1000])


func test_a_tint_to_grey_falls_over_the_whole_fade_and_stays_grey() -> void:
	assert_array(_s(FRIEND, 1000, GREY, 100)).is_equal([FRIEND, 750])
	assert_array(_s(FRIEND, 1000, GREY, D)).is_equal([FRIEND, 0])


## F5, a tint to another: the old tint falls to 0 in the first half, the new one rises in the
## second, and the tile is grey in the middle: the tints never mix.
func test_a_tint_to_another_goes_through_grey() -> void:
	assert_array(_s(FRIEND, 1000, FOE, 100)).is_equal([FRIEND, 500])
	assert_array(_s(FRIEND, 1000, FOE, 200)).is_equal([FRIEND, 0])
	assert_array(_s(FRIEND, 1000, FOE, 300)).is_equal([FOE, 500])
	assert_array(_s(FRIEND, 1000, FOE, D)).is_equal([FOE, 1000])


func test_the_fade_is_continuous_with_one_tint_at_a_time() -> void:
	var last := 1000
	for u in range(0, D + 1, 10):
		var state := WaveFade.shown(FRIEND, 1000, FOE, u, D)
		assert_bool(state.x == FRIEND or state.x == FOE).is_true()
		assert_bool(absi(state.y - last) <= 100).is_true()  # no jump between two samples
		last = state.y


## F5, rewrite during a fade (rule 15): the tile leaves the saturation it shows.
func test_a_rewrite_towards_another_tint_falls_then_rises_from_the_shown_saturation() -> void:
	# the foe tint at 600 towards the friend tint: 200 x 600 div 1000 = 120 ms down, then 200 up
	assert_array(_s(FOE, 600, FRIEND, 0)).is_equal([FOE, 600])
	assert_array(_s(FOE, 600, FRIEND, 120)).is_equal([FOE, 0])
	assert_array(_s(FOE, 600, FRIEND, 220)).is_equal([FRIEND, 500])
	assert_array(_s(FOE, 600, FRIEND, 320)).is_equal([FRIEND, 1000])


func test_a_rewrite_towards_the_same_tint_rises_in_the_time_left() -> void:
	# 400 x (1000 - 600) div 1000 = 160 ms
	assert_array(_s(FRIEND, 600, FRIEND, 80)).is_equal([FRIEND, 800])
	assert_array(_s(FRIEND, 600, FRIEND, 160)).is_equal([FRIEND, 1000])


func test_a_rewrite_towards_grey_falls_in_the_time_it_takes() -> void:
	# 400 x 600 div 1000 = 240 ms
	assert_array(_s(FRIEND, 600, GREY, 120)).is_equal([FRIEND, 300])
	assert_array(_s(FRIEND, 600, GREY, 240)).is_equal([FRIEND, 0])


func test_a_tile_faded_to_nothing_is_grey_whatever_tint_it_came_from() -> void:
	assert_array(_s(FOE, 0, FRIEND, 100)).is_equal(_s(GREY, 0, FRIEND, 100))


func test_a_fade_of_no_duration_is_the_end_state() -> void:
	var state := WaveFade.shown(FRIEND, 1000, FOE, 0, 0)

	assert_array([state.x, state.y]).is_equal([FOE, 1000])
