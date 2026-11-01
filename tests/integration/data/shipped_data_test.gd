# The data files shipped in res://assets/data/ load without any error (ADR-0009 §5).
extends GdUnitTestSuite


func test_shipped_data_loads() -> void:
	var result := DataCatalog.load_all(ResDataSource.new())

	assert_array(result.errors.map(func(e: DataError) -> String: return str(e))).is_empty()
	assert_bool(result.ok).is_true()


func test_shipped_data_matches_the_test_catalog() -> void:
	var shipped := DataCatalog.load_all(ResDataSource.new()).catalog
	var standard := CatalogFactory.standard()

	assert_array(shipped.units.vision_radii()).is_equal(standard.units.vision_radii())
	for type in standard.units.count():
		assert_str(shipped.units.key(type)).is_equal(standard.units.key(type))
		assert_int(shipped.units.hp(type)).is_equal(standard.units.hp(type))
