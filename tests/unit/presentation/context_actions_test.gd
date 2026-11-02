extends GdUnitTestSuite


func test_a_refusal_is_told_in_words_with_its_amounts() -> void:
	assert_str(RefusalText.of(ValidationResult.refused(Refusal.NOT_ENOUGH_ENERGY, PackedInt64Array([12, 9])))).is_equal("Énergie insuffisante (12 requis, 9 disponibles)")
	assert_str(RefusalText.of(ValidationResult.refused(Refusal.MAX_LEVEL))).is_equal("Niveau maximal")
	assert_str(RefusalText.of(ValidationResult.refused(&"CODE_NEUF"))).is_equal("CODE_NEUF")


func test_names_fall_back_to_their_key() -> void:
	assert_str(DisplayNames.unit("eclaireur")).is_equal("Éclaireur")
	assert_str(DisplayNames.unit("nouveau_type")).is_equal("Nouveau Type")
	assert_str(DisplayNames.protocol("blindage_appoint")).is_equal("Blindage d'appoint")
	assert_str(DisplayNames.protocol("autre")).is_equal("Autre")


func test_a_max_level_node_offers_no_upgrade_and_says_so() -> void:
	var catalog := CatalogFactory.standard()
	var state := GameStateFactory.new_game(catalog, TestSessionFactory.shipped_map(catalog), 3)
	var fx := PipelineFixture.new(state, true)
	fx.begin_turn(Faction.PLAYER)
	for k in 2:
		NodeWrites.upgrade(state, 0)

	assert_array(ContextActions.for_selection(state, catalog, fx.pipeline, -1, 0)).is_empty()
	var panel := ContextActions.node_panel(state, catalog, 0)
	assert_str(panel["title"]).is_equal("Nœud · niveau 3")
	assert_str(panel["lines"][1]).is_equal("Niveau maximal")


func test_the_panel_of_a_node_that_is_not_the_players_is_empty() -> void:
	var catalog := CatalogFactory.standard()
	var state := GameStateFactory.new_game(catalog, TestSessionFactory.shipped_map(catalog), 3)

	assert_bool(ContextActions.node_panel(state, catalog, 1).is_empty()).is_true()
	assert_bool(ContextActions.node_panel(state, catalog, -1).is_empty()).is_true()
