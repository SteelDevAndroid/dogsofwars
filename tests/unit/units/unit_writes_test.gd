# modifier_pv (GDD 6 rule 9): bounded to 0..PV_max, destruction in the same call.
extends GdUnitTestSuite

const ASSAUT := 1


func _state(hp: int) -> GameState:
	var state := MapBuilder.state(PackedStringArray(["..."]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0, false, hp)
	return state


func _units() -> UnitTypes:
	return CatalogFactory.standard().units


func test_damage_lowers_the_hp_and_reports_before_and_after() -> void:
	var state := _state(8)

	var change := UnitWrites.modify_hp(state, 0, -3, _units())

	assert_array([change.before, change.after, change.lost(), change.destroyed]).is_equal([8, 5, 3, false])
	assert_int(state.view().unit_hp(0)).is_equal(5)


func test_a_heal_stops_at_the_type_maximum() -> void:
	var state := _state(6)

	var change := UnitWrites.modify_hp(state, 0, 5, _units())

	assert_array([change.before, change.after, change.lost()]).is_equal([6, 8, -2])
	assert_int(state.view().unit_hp(0)).is_equal(8)


func test_a_blow_beyond_the_hp_destroys_in_the_same_call_and_reports_the_hp_really_lost() -> void:
	var state := _state(2)

	var change := UnitWrites.modify_hp(state, 0, -9, _units())

	assert_array([change.after, change.lost(), change.destroyed]).is_equal([0, 2, true])
	assert_int(state.view().unit_tile(0)).is_equal(-1)
	assert_array(state.view().unit_ids()).is_empty()


func test_a_zero_delta_writes_nothing() -> void:
	var state := _state(5)
	var before := state.to_bytes()

	var change := UnitWrites.modify_hp(state, 0, 0, _units())

	assert_bool(change.destroyed).is_false()
	assert_array(state.to_bytes()).is_equal(before)
