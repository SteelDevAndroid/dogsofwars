extends GdUnitTestSuite


func _errors_with(change: Callable) -> PackedStringArray:
	var docs := CatalogFactory.documents()
	change.call(docs["fragments.json"])
	var result := CatalogFactory.load_documents(docs)
	var lines := PackedStringArray()
	for error in result.errors:
		lines.append(str(error))
	return lines


func _joined(lines: PackedStringArray) -> String:
	return "\n".join(lines)


func test_the_texts_are_served_by_id() -> void:
	var pool := CatalogFactory.standard().fragments

	assert_str(pool.title_of(2)).is_equal("Fragment")
	assert_str(pool.text_of(2)).is_equal("On allume les balises.")
	assert_str(pool.source_of(2)).is_equal("Journal")
	assert_bool(pool.has_fragment(5)).is_true()
	assert_bool(pool.has_fragment(6)).is_false()
	assert_str(pool.text_of(6)).is_empty()


func test_the_length_limits_are_enforced_at_the_boundary() -> void:
	var at_limit := _errors_with(func(d: Dictionary) -> void:
		d["fragments"][0]["title"] = "T".repeat(28)
		d["fragments"][0]["text"] = "t".repeat(140)
		d["fragments"][0]["source"] = "s".repeat(24))
	assert_str(_joined(at_limit)).is_empty()

	var over := _errors_with(func(d: Dictionary) -> void:
		d["fragments"][0]["title"] = "T".repeat(29)
		d["fragments"][1]["text"] = "t".repeat(141)
		d["fragments"][2]["source"] = "s".repeat(25))
	assert_str(_joined(over)).contains("fragments[0].title").contains("fragments[1].text").contains("fragments[2].source")


func test_an_empty_text_is_refused() -> void:
	var errors := _errors_with(func(d: Dictionary) -> void: d["fragments"][0]["text"] = "  ")

	assert_str(_joined(errors)).contains("fragments[0].text: must not be empty")


func test_a_number_is_refused_in_any_field() -> void:
	for field in ["title", "text", "source"]:
		for digit in ["0", "4", "9"]:
			var errors := _errors_with(func(d: Dictionary) -> void: d["fragments"][0][field] = "Cycle " + digit)
			assert_str(_joined(errors)).contains("holds no number")
	var around := _errors_with(func(d: Dictionary) -> void: d["fragments"][0]["text"] = "Entre / et : rien.")
	assert_str(_joined(around)).is_empty()


func test_the_source_names_no_faction_and_no_ruin() -> void:
	for source in ["Ordre de la Meute", "Les gardiens", "Ruine nord"]:
		var errors := _errors_with(func(d: Dictionary) -> void: d["fragments"][0]["source"] = source)
		assert_str(_joined(errors)).contains("fragments[0].source")


func test_a_linked_fragment_uses_the_verb_and_a_question_link_asks() -> void:
	var no_verb := _errors_with(func(d: Dictionary) -> void: d["fragments"][1]["text"] = "On garde les balises.")
	assert_str(_joined(no_verb)).contains("fragments[1].text")

	var no_question := _errors_with(func(d: Dictionary) -> void: d["fragments"][4]["text"] = "On allume encore.")
	assert_str(_joined(no_question)).contains("asks a question")


func test_two_equal_tones_and_an_unknown_tone_are_refused() -> void:
	var twice := _errors_with(func(d: Dictionary) -> void: d["fragments"][0]["tones"] = ["doute", "doute"])
	assert_str(_joined(twice)).contains("fragments[0].tones")

	var unknown := _errors_with(func(d: Dictionary) -> void: d["fragments"][0]["tones"] = ["joie"])
	assert_bool(unknown.size() > 0).is_true()

	var three := _errors_with(func(d: Dictionary) -> void: d["fragments"][0]["tones"] = ["doute", "usure", "absence"])
	assert_bool(three.size() > 0).is_true()


func test_the_last_fragment_of_the_pool_must_be_a_question() -> void:
	var errors := _errors_with(func(d: Dictionary) -> void:
		d["fragments"][4]["link"] = "verbe"
		d["fragments"][4]["text"] = "On allume.")

	assert_str(_joined(errors)).contains("the last fragment")


func test_act_three_needs_its_share_of_linked_fragments() -> void:
	var errors := _errors_with(func(d: Dictionary) -> void:
		d["fragments"][3]["link"] = "aucun"
		d["act3_link_percent"] = 100)
	assert_str(_joined(errors)).contains("too few linked fragments in act 3")

	var exact := _errors_with(func(d: Dictionary) -> void: d["fragments"][3]["link"] = "aucun")  # 1 of 2 = 50 %
	assert_str(_joined(exact)).is_empty()


func test_act_one_needs_a_verb_fragment() -> void:
	var errors := _errors_with(func(d: Dictionary) -> void:
		d["fragments"][1]["link"] = "aucun"
		d["act1_verb_min"] = 1)

	assert_str(_joined(errors)).contains("too few VERB fragments in act 1")


func test_the_acts_never_go_back_along_the_ids() -> void:
	var errors := _errors_with(func(d: Dictionary) -> void: d["fragments"][2]["act"] = 1)
	assert_str(_joined(errors)).is_empty()  # 1,1,1,3,3 is fine

	var back := _errors_with(func(d: Dictionary) -> void: d["fragments"][3]["act"] = 2; d["fragments"][2]["act"] = 3)
	assert_str(_joined(back)).contains("fragments[3].act")


func test_the_shipped_texts_pass_every_rule_and_are_in_the_catalog() -> void:
	var source := ResDataSource.new()
	var result := DataCatalog.load_all(source)

	assert_bool(result.ok).is_true()
	var pool := result.catalog.fragments
	for id in pool.ids_of(Faction.PLAYER):
		assert_bool(pool.text_of(id).length() >= 90).is_true()  # 90 to 120 aimed (rule 27)
		assert_bool(pool.text_of(id).length() <= 120).is_true()
