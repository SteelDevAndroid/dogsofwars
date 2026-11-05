extends GdUnitTestSuite

const REMPART := 2
const ASSAUT := 1
const SENTINELLE := 4


## The shipped data (assets/data/units.json), not the fixture's: the distance weapons are data.
func test_the_rempart_and_the_sentinelle_reach_two_tiles() -> void:
	var units := _units()

	assert_int(units.attack_range(REMPART)).is_equal(2)
	assert_int(units.attack_range(SENTINELLE)).is_equal(2)
	assert_int(units.attack_range(ASSAUT)).is_equal(1)
	assert_int(units.attack(SENTINELLE)).is_greater(0)  # a sentinel that cannot hit would waste its range


func _units() -> UnitTypes:
	var loaded := DataCatalog.load_all(ResDataSource.new())
	assert_bool(loaded.catalog != null).is_true()
	return loaded.catalog.units
