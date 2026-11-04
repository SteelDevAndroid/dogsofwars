extends GdUnitTestSuite

const MAP_PATH := "res://assets/data/maps/plaine.json"


func _document() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))


func _errors_of(document: Dictionary) -> Array[String]:
	var errors: Array[DataError] = []
	MapDefinition.parse(JSON.stringify(document), "plaine.json", CatalogFactory.standard(), errors)
	var messages: Array[String] = []
	for error in errors:
		messages.append(error.message)
	return messages


func _with_message(document: Dictionary, fragment: String) -> bool:
	for message in _errors_of(document):
		if message.contains(fragment):
			return true
	return false


func test_the_shipped_map_is_valid() -> void:
	var errors: Array[DataError] = []

	var map := MapDefinition.parse(FileAccess.get_file_as_string(MAP_PATH), "plaine.json", CatalogFactory.standard(), errors)

	assert_array(errors.map(func(error: DataError) -> String: return str(error))).is_empty()
	assert_int(map.width).is_equal(12)
	assert_int(map.dormants.size()).is_equal(6)
	assert_int(map.nodes.size()).is_equal(4)


func test_a_wrong_schema_version_a_missing_key_or_bad_json_is_refused() -> void:
	var document := _document()
	document["schema_version"] = 2
	assert_bool(_errors_of(document).is_empty()).is_false()
	document = _document()
	document.erase("ruin_zones")
	assert_bool(_errors_of(document).is_empty()).is_false()
	var errors: Array[DataError] = []
	assert_object(MapDefinition.parse("{nope", "plaine.json", CatalogFactory.standard(), errors)).is_null()
	assert_int(errors.size()).is_equal(1)


func test_terrain_must_match_the_size_and_use_known_glyphs() -> void:
	var document := _document()
	document["terrain"][3] = "..."
	assert_bool(_with_message(document, "terrain row 3 has 3 tiles")).is_true()
	document = _document()
	document["terrain"][0] = "x..........."
	assert_bool(_with_message(document, "unknown glyph")).is_true()
	document = _document()
	document["terrain"].pop_back()
	assert_bool(_with_message(document, "terrain has 11 rows")).is_true()


func test_nodes_and_starts_stand_on_plain_and_keep_their_distance() -> void:
	var document := _document()
	document["nodes"][0] = {"x": 7, "y": 4, "level": 1}  # water
	assert_bool(_with_message(document, "is not on plain")).is_true()
	document = _document()
	document["nodes"][0] = {"x": 3, "y": 2, "level": 1}  # two tiles from the start node
	assert_bool(_with_message(document, "closer than 4")).is_true()
	document = _document()
	document["nodes"][0] = {"x": 1, "y": 2, "level": 1}
	assert_bool(_with_message(document, "share tile")).is_true()


func test_dormants_keep_away_from_starts_and_nodes_and_must_be_pack_types() -> void:
	var document := _document()
	document["dormants"][0] = {"x": 2, "y": 4, "types": ["ouvrier"], "same_as": -1}
	assert_bool(_with_message(document, "closer than 3 to a start")).is_true()
	document = _document()
	document["dormants"][2] = {"x": 3, "y": 6, "types": ["eclaireur"], "same_as": -1}  # next to node (2,6)
	assert_bool(_with_message(document, "next to a node")).is_true()
	document = _document()
	document["dormants"][2]["types"] = ["eclaireur", "chasseur"]
	assert_bool(_with_message(document, "chasseur is not a pack type")).is_true()
	document = _document()
	document["dormants"][3]["types"] = ["assaut"]
	assert_bool(_with_message(document, "same_as needs the same type list")).is_true()
	document = _document()
	document["dormants"][2]["same_as"] = 3
	assert_bool(_with_message(document, "must name an earlier dormant")).is_true()
	document = _document()
	document["dormants"][0] = {"x": 7, "y": 4, "types": ["ouvrier"], "same_as": -1}  # water
	assert_bool(_with_message(document, "not on plain or forest")).is_true()


func test_ruin_zones_need_enough_candidates_away_from_starts() -> void:
	var document := _document()
	document["ruin_zones"][0]["draw"] = 4
	assert_bool(_with_message(document, "draws more ruins than it has candidates")).is_true()
	document = _document()
	document["ruin_zones"][0]["candidates"][0] = {"x": 2, "y": 2}
	assert_bool(_with_message(document, "closer than 3 to a start")).is_true()
	document = _document()
	document["ruin_zones"][0]["candidates"][1] = document["ruin_zones"][1]["candidates"][0]
	assert_bool(_with_message(document, "shares its tile")).is_true()


func test_units_are_checked() -> void:
	var document := _document()
	document["units"][0]["type"] = "dragon"
	assert_bool(_with_message(document, "unknown type dragon")).is_true()
	document = _document()
	document["units"][3]["faction"] = "meute"
	assert_bool(_with_message(document, "does not belong to that faction")).is_true()
	document = _document()
	document["units"][1] = {"type": "assaut", "faction": "meute", "x": 7, "y": 4, "post_x": -1, "post_y": -1}
	assert_bool(_with_message(document, "stands on water")).is_true()
	document = _document()
	document["units"][0]["type"] = "assaut"
	assert_bool(_with_message(document, "starts without a unit that can capture")).is_true()
	document = _document()
	document["units"][1]["x"] = 2
	document["units"][1]["y"] = 3
	assert_bool(_with_message(document, "shares its tile")).is_true()


func test_a_declared_symmetry_is_verified() -> void:
	var document := _document()
	document["terrain"][0] = "f..........."
	assert_bool(_with_message(document, "not symmetric")).is_true()
	document = _document()
	document["nodes"][3]["level"] = 2
	assert_bool(_with_message(document, "no symmetric partner of the same level")).is_true()
	document = _document()
	document["dormants"][1]["types"] = ["assaut"]
	assert_bool(_with_message(document, "dormant at tile")).is_true()
	document = _document()
	document["symmetry"] = "none"
	document["terrain"][0] = "f..........."
	assert_bool(_with_message(document, "not symmetric")).is_false()


func test_a_dormant_on_the_ai_side_must_be_covered() -> void:
	var document := _document()
	document["units"] = document["units"].filter(func(unit: Dictionary) -> bool: return unit["type"] != "chasseur")

	assert_bool(_with_message(document, "not covered by an armed Guardian")).is_true()


## ADR-0005 §4: plaine has 4 Guardians and 6 nodes (4 neutral, 2 starts), so 12 planner calls;
## 12 x 1 000 evaluations fit EVALS_MAX, 12 x 2 000 do not.
func test_the_ai_turn_budget_of_the_map_is_checked() -> void:
	var docs := CatalogFactory.documents()
	docs["ai.json"]["planner"]["evals_per_call"] = 2000
	var catalog := CatalogFactory.load_documents(docs).catalog
	var errors: Array[DataError] = []

	MapDefinition.parse(FileAccess.get_file_as_string(MAP_PATH), "plaine.json", catalog, errors)

	assert_int(AiPlanner.max_calls_per_turn(4, 6)).is_equal(12)
	assert_bool(errors.any(func(error: DataError) -> bool: return error.message.contains("AI turn budget"))).is_true()


func test_every_shipped_map_is_valid_and_symmetric_with_its_own_size() -> void:
	var catalog := CatalogFactory.standard()
	var sizes := {}
	for file in DirAccess.get_files_at("res://assets/data/maps"):
		if not file.ends_with(".json"):
			continue
		var errors: Array[DataError] = []
		var map := MapDefinition.parse(FileAccess.get_file_as_string("res://assets/data/maps/" + file), file, catalog, errors)
		assert_array(errors).override_failure_message("%s: %s" % [file, errors]).is_empty()
		assert_object(map).is_not_null()
		sizes[file] = Vector2i(map.width, map.height)
	var full := Vector2i(MapDefinition.MAX_SIZE, MapDefinition.MAX_SIZE)
	assert_dict(sizes).is_equal({"plaine.json": Vector2i(12, 12), "marais.json": Vector2i(14, 14), "cretes.json": full,
			"foret.json": full, "archipel.json": full, "mesas.json": full, "landes.json": full})


func test_a_map_needs_a_title_and_a_summary_for_the_choice_screen() -> void:
	var document := _document()
	assert_str(document["title"]).is_not_empty()
	document["title"] = "  "
	assert_bool(_with_message(document, "title and summary")).is_true()
	document = _document()
	document["summary"] = ""
	assert_bool(_with_message(document, "title and summary")).is_true()
	document = _document()
	document.erase("title")
	assert_bool(_errors_of(document).is_empty()).is_false()  # the schema is strict: a missing key is refused
