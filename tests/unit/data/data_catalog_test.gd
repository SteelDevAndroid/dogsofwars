extends GdUnitTestSuite


func _errors_of(docs: Dictionary) -> PackedStringArray:
	var result := CatalogFactory.load_documents(docs)
	assert_bool(result.ok).is_false()
	assert_object(result.catalog).is_null()
	var lines := PackedStringArray()
	for error in result.errors:
		lines.append(str(error))
	return lines


func test_standard_documents_load_into_typed_objects() -> void:
	var catalog := CatalogFactory.standard()

	assert_int(catalog.units.count()).is_equal(7)
	assert_str(catalog.units.key(0)).is_equal("eclaireur")
	assert_int(catalog.units.vision(0)).is_equal(4)
	assert_int(catalog.units.side(5)).is_equal(Faction.AI)
	assert_int(catalog.units.hp(2)).is_equal(14)
	assert_int(catalog.nodes.territory_radius(3)).is_equal(3)
	assert_int(catalog.fog.mountain_view_bonus()).is_equal(1)


func test_fraction_is_refused_never_rounded() -> void:
	var docs := CatalogFactory.documents()
	docs["brouillard.json"]["node_view_min"] = 2.5

	assert_array(_errors_of(docs)).contains(["brouillard.json: node_view_min: expected an integer, got 2.5"])


func test_two_point_zero_is_the_integer_two() -> void:
	var docs := CatalogFactory.documents()
	docs["brouillard.json"] = "{\"schema_version\": 1, \"node_view_min\": 2.0, \"mountain_view_bonus\": 1}"

	assert_bool(CatalogFactory.load_documents(docs).ok).is_true()


func test_unknown_and_missing_keys_are_both_reported() -> void:
	var docs := CatalogFactory.documents()
	docs["brouillard.json"].erase("mountain_view_bonus")
	docs["brouillard.json"]["fog_colour"] = 3

	var errors := _errors_of(docs)

	assert_array(errors).contains([
		"brouillard.json: fog_colour: unknown key", "brouillard.json: mountain_view_bonus: missing key"])


func test_every_error_is_reported_with_its_path() -> void:
	var docs := CatalogFactory.documents()
	docs["units.json"]["types"][1]["hp"] = 40
	docs["units.json"]["types"][4]["side"] = "neutre"
	docs["noeuds.json"]["territory_radius"] = [1, "2", 3]

	var errors := _errors_of(docs)

	assert_array(errors).has_size(3)
	assert_array(errors).contains([
		"units.json: types[1].hp: 40 outside 6..14",
		"units.json: types[4].side: expected one of meute, gardiens",
		"noeuds.json: territory_radius[1]: expected an integer"])


func test_cross_checks_refuse_out_of_order_ids_and_duplicate_keys() -> void:
	var docs := CatalogFactory.documents()
	docs["units.json"]["types"][2]["id"] = 5
	docs["units.json"]["types"][3]["key"] = "assaut"
	docs["noeuds.json"]["territory_radius"] = [2, 1]

	assert_array(_errors_of(docs)).contains([
		"units.json: types[2].id: expected 2: ids are 0..n-1 in order",
		"units.json: types[3].key: duplicate key assaut",
		"noeuds.json: territory_radius[1]: radius decreases with the level"])


func test_missing_unknown_and_unparsable_files_are_refused() -> void:
	var docs := CatalogFactory.documents()
	docs.erase("noeuds.json")
	docs["combat.json"] = {"schema_version": 1}
	docs["units.json"] = "{\"schema_version\": 1,"

	var errors := _errors_of(docs)

	assert_array(errors).contains(["noeuds.json: (file): missing data file", "combat.json: (file): unknown data file"])
	assert_bool(errors[errors.size() - 1].begins_with("units.json: ")).is_true()


func test_other_schema_version_is_refused() -> void:
	var docs := CatalogFactory.documents()
	docs["noeuds.json"]["schema_version"] = 2

	assert_array(_errors_of(docs)).contains(["noeuds.json: schema_version: 2 outside 1..1"])


func test_huge_or_infinite_numbers_are_refused() -> void:
	var docs := CatalogFactory.documents()
	docs["brouillard.json"] = "{\"schema_version\": 1, \"node_view_min\": 1e999, \"mountain_view_bonus\": 9007199254740993}"

	assert_array(_errors_of(docs)).has_size(2)


func test_content_hash_is_stable_and_follows_the_bytes() -> void:
	var docs := CatalogFactory.documents()
	var first := CatalogFactory.load_documents(docs).catalog.content_hash
	var again := CatalogFactory.load_documents(CatalogFactory.documents()).catalog.content_hash
	docs["brouillard.json"] = JSON.stringify(docs["brouillard.json"]) + "\r\n"

	var with_crlf := CatalogFactory.load_documents(docs).catalog.content_hash

	assert_str(again).is_equal(first)
	assert_int(first.length()).is_equal(64)
	assert_str(with_crlf).is_not_equal(first)


func test_content_hash_does_not_depend_on_listing_order() -> void:
	var files := {"b.json": "x".to_utf8_buffer(), "a.json": "yz".to_utf8_buffer()}
	var reversed := {"a.json": "yz".to_utf8_buffer(), "b.json": "x".to_utf8_buffer()}

	assert_str(DataCatalog.content_hash_of(reversed)).is_equal(DataCatalog.content_hash_of(files))


func test_content_hash_separates_files_whose_concatenation_is_equal() -> void:
	# Name then bytes, concatenated, read "a.jsonxb.jsony" for both sets.
	var two_files := {"a.json": "x".to_utf8_buffer(), "b.json": "y".to_utf8_buffer()}
	var one_file := {"a.json": "xb.jsony".to_utf8_buffer()}

	assert_str(DataCatalog.content_hash_of(one_file)).is_not_equal(DataCatalog.content_hash_of(two_files))


func test_vision_context_takes_radii_from_the_catalog() -> void:
	var state := StateFactory.minimal()

	var ctx := VisionContext.for_map(CatalogFactory.standard(), state)

	assert_array(ctx.view_radius).is_equal(PackedInt32Array([4, 2, 2, 2, 3, 3, 2]))
	assert_array(ctx.node_radius).is_equal(PackedInt32Array([0, 2, 2, 3]))
	assert_int(ctx.mountain_bonus).is_equal(1)
	assert_int(ctx.fields.max_radius()).is_equal(5)
