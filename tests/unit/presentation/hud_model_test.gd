extends GdUnitTestSuite

const ASSAUT := 1
const CHASSEUR := 5


func _catalog() -> DataCatalog:
	return CatalogFactory.standard()


func _model(state: GameState, locked: bool = false, selected: int = -1, journal: Array[String] = []) -> HudModel:
	return HudModel.build(state, _catalog(), locked, selected, journal)


## 10 x 3, turn 4, the player's phase. Player Assaut 0 at (2,1); AI Chasseur 1 at (3,1)
## (visible); player node at (0,0); AI node at (9,2); ruin at (5,1).
func _board() -> GameState:
	var state := MapBuilder.state(PackedStringArray(["..........", "..........", ".........."]))
	MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 2, 1)
	MapBuilder.unit(state, CHASSEUR, Faction.AI, 3, 1)
	GameStateSetup.add_node(state, state.tile_index(0, 0), Faction.PLAYER, 1)
	GameStateSetup.add_node(state, state.tile_index(9, 2), Faction.AI, 1)
	GameStateSetup.add_ruin(state, state.tile_index(5, 1), 0, Faction.PLAYER)
	TerritoryRules.recompute(state, _catalog().nodes, MapSlice.CAUSE_NONE)
	GameStateSetup.set_turn(state, 4)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)
	return MapBuilder.ready(state)


func test_the_top_bar_and_the_score_row_read_the_state() -> void:
	var state := MapBuilder.with_energy(_board(), 17, 3)

	var model := _model(state)

	assert_str(model.turn_text).is_equal("Tour 4 / 30")
	assert_str(model.energy_text).is_equal("17")
	assert_str(model.fragments_text).is_equal("0 / %d" % FactionView.new(state, Faction.PLAYER).ruin_ids().size())
	var weights := _catalog().score
	assert_str(model.score_text).is_equal("Vous %d · Gardiens %d" % [ScoreRules.decisive(state, 0, weights), ScoreRules.decisive(state, 1, weights)])
	assert_array([model.score_player, model.score_ai]).is_equal([ScoreRules.decisive(state, 0, weights), ScoreRules.decisive(state, 1, weights)])


func test_the_end_turn_button_needs_the_players_phase_and_no_lock() -> void:
	var state := _board()
	assert_bool(_model(state).can_end_turn).is_true()
	assert_bool(_model(state, true).can_end_turn).is_false()
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	var enemy := _model(state)
	assert_bool(enemy.can_end_turn).is_false()
	assert_bool(enemy.enemy_turn).is_true()
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_FINISHED, Faction.PLAYER)
	assert_bool(_model(state).can_end_turn).is_false()


func test_a_visible_announced_intention_raises_the_threat_chip() -> void:
	var state := _board()
	assert_str(_model(state).threat_chip).is_empty()
	var fx := PipelineFixture.new(state)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	fx.announce([[1, IntentionsSlice.TARGET_UNIT, 0, IntentionsSlice.ACTION_ATTACK, IntentionsSlice.MOTIVE_HUNT]])
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)

	assert_str(_model(state).threat_chip).is_equal("Menace")
	assert_int(_model(state).threat_tile).is_equal(state.tile_index(2, 1))  # the target's tile, where the marker is


func test_losses_of_the_last_enemy_phase_give_chips() -> void:
	var state := _board()
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	RecallWrites.unit_lost(state, 5, Faction.PLAYER)
	RecallWrites.unit_lost(state, 6, Faction.AI)  # an enemy loss is not a loss for the player
	RecallWrites.tile_lost(state, 7)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)

	assert_array(_model(state).loss_chips).is_equal(["Drone perdu", "Territoire perdu"])
	assert_array(_model(state).loss_tiles).is_equal([5, 7])  # where the drone fell, the first tile lost


func test_the_ruin_chip_says_a_ruin_is_known_without_a_number() -> void:
	var state := _board()

	assert_str(_model(state).ruin_chip).is_equal("Ruine repérée")
	assert_int(_model(state).ruin_tile).is_equal(state.tile_index(5, 1))
	var catalog := _catalog()
	var read := RuinWrites
	read.mark_read(state, 0, Faction.PLAYER)
	assert_str(_model(state).ruin_chip).is_empty()


func test_the_unit_panel_shows_effective_stats_and_hides_other_units() -> void:
	var state := _board()

	var panel := _model(state, false, 0).unit_panel

	assert_str(panel["title"]).is_equal("Assaut")
	assert_array(panel["lines"]).is_equal(["PV 8 / 8", "MVT 3  ATQ 3  DÉF 1  Vue 2"])
	assert_array([panel["hp"], panel["hp_max"]]).is_equal([8, 8])
	assert_array(panel["stats"]).is_equal([["MVT", 3], ["ATQ", 3], ["DÉF", 1], ["VUE", 2]])
	assert_bool(_model(state, false, 1).unit_panel.is_empty()).is_true()  # an enemy unit has no panel
	assert_bool(_model(state, false, -1).unit_panel.is_empty()).is_true()
	assert_bool(_model(state, false, 99).unit_panel.is_empty()).is_true()
	UnitWrites.set_moved(state, 0)
	assert_array(_model(state, false, 0).unit_panel["lines"]).contains(["A bougé"])


func test_the_journal_has_a_line_per_event_that_matters() -> void:
	assert_str(HudModel.journal_line(IntentionAnnouncedEvent.new(0, 1, 0, 0, 5, 0, 0))).is_not_empty()
	assert_str(HudModel.journal_line(IntentionExecutedEvent.new(0, 1, 0, 5))).is_not_empty()
	assert_str(HudModel.journal_line(IntentionCancelledEvent.new(0, 1, 1, 0, 5))).is_not_empty()
	assert_str(HudModel.journal_line(UnitMovedEvent.new(Faction.AI, 1, 2, 3, 3))).is_not_empty()
	assert_str(HudModel.journal_line(UnitMovedEvent.new(Faction.PLAYER, 1, 2, 3, 3))).is_empty()
	assert_str(HudModel.journal_line(EnergyChangedEvent.new(0, 1, 2))).is_empty()


func test_the_context_actions_hide_under_a_lock_or_while_targeting_and_the_research_rows_grey_out() -> void:
	var state := _board()
	var extras: Array[ContextAction] = [ContextAction.new(&"capture", "Capturer", false, "A déjà agi")]
	var rows: Array[ContextAction] = [ContextAction.new(&"research:0", "Veille", true)]
	var actions := {"extras": extras, "research_open": true, "research": rows}

	var free := _model_with(state, false, actions)
	assert_array(free.extra_actions.map(func(a: ContextAction) -> StringName: return a.id)).is_equal([&"capture"])
	assert_str(free.reason_text).is_equal("A déjà agi")
	assert_bool(free.research_open).is_true()
	assert_bool(free.research_rows[0].enabled).is_true()

	var locked := _model_with(state, true, actions)
	assert_int(locked.extra_actions.size()).is_equal(0)
	assert_bool(locked.research_rows[0].enabled).is_false()
	assert_str(locked.research_rows[0].reason).is_equal("Patientez")

	actions["targeting"] = true
	assert_int(_model_with(state, false, actions).extra_actions.size()).is_equal(0)


func _model_with(state: GameState, locked: bool, actions: Dictionary) -> HudModel:
	return HudModel.build(state, _catalog(), locked, -1, [], actions)


## 5 x 5 plains, the Éclaireur (view 4) in the middle sees everything: its moves reveal nothing.
func _open_board() -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray([".....", ".....", ".....", ".....", "....."]))
	MapBuilder.unit(state, 0, Faction.PLAYER, 2, 2)
	MapBuilder.unit(state, ASSAUT, Faction.AI, 4, 4)
	return PipelineFixture.new(MapBuilder.ready(state))


func _undo_model(fx: PipelineFixture) -> HudModel:
	return HudModel.build(fx.state, _catalog(), false, -1, [], {"undo": fx.pipeline.check(UndoMoveCommand.new())})


func test_the_undo_button_shows_after_a_move_and_hides_once_something_else_happened() -> void:
	var fx := _open_board()
	assert_bool(_undo_model(fx).undo_visible).is_false()  # nothing to undo yet

	fx.move(0, fx.state.tile_index(3, 2))

	var model := _undo_model(fx)
	assert_array([model.undo_visible, model.undo_enabled, model.undo_reason]).is_equal([true, true, ""])
	assert_bool(HudModel.build(fx.state, _catalog(), true, -1, [], {"undo": fx.pipeline.check(UndoMoveCommand.new())}).undo_visible).is_false()  # locked
	fx.undo_move()
	assert_bool(_undo_model(fx).undo_visible).is_false()


func test_a_move_that_revealed_the_map_shows_a_greyed_undo_and_its_reason() -> void:
	var state := MapBuilder.state(PackedStringArray(["........"]))
	var unit := MapBuilder.unit(state, ASSAUT, Faction.PLAYER, 0, 0)
	var fx := PipelineFixture.new(MapBuilder.ready(state))

	fx.move(unit, state.tile_index(3, 0))  # tiles 3 to 5 are discovered

	var model := _undo_model(fx)
	assert_array([model.undo_visible, model.undo_enabled]).is_equal([true, false])
	assert_str(model.undo_reason).contains("Impossible d'annuler")


func test_a_tapped_tile_tells_its_terrain_from_what_the_player_knows() -> void:
	var state := _board()
	var catalog := _catalog()
	var tile := state.tile_index(2, 0)  # plain, beside the player's Assaut
	assert_int(VisionService.fog_level(state, Faction.PLAYER, tile)).is_equal(VisionService.FOG_VISIBLE)

	var model := HudModel.build(state, catalog, false, -1, [], {"inspect": tile})

	assert_str(model.unit_panel["title"]).is_equal("Plaine")
	assert_str(model.unit_panel["lines"][0]).is_equal("Plaine : entrée %d MVT, défense +%d" % [
			catalog.terrain.entry_cost(TerrainGrid.PLAIN), catalog.terrain.defense_class(TerrainGrid.PLAIN)])
	assert_bool(model.unit_panel.has("hp")).is_false()


func test_an_undiscovered_tile_tells_nothing() -> void:
	var state := _board()
	var view := FactionView.new(state, Faction.PLAYER)
	var hidden := -1
	for tile in state.tile_count():
		if VisionService.fog_level(state, Faction.PLAYER, tile) == VisionService.FOG_UNDISCOVERED:
			hidden = tile
			break
	assert_int(hidden).is_greater_equal(0)

	var panel := HudModel.tile_panel(state, view, _catalog(), hidden)

	assert_dict(panel).is_equal({"title": "Zone inconnue", "lines": ["Pas encore explorée"]})


func test_a_visible_enemy_shows_its_card_with_the_stats_of_its_type() -> void:
	var state := _board()
	var catalog := _catalog()
	var tile := state.tile_index(3, 1)

	var panel := HudModel.tile_panel(state, FactionView.new(state, Faction.PLAYER), catalog, tile)

	assert_str(panel["title"]).is_equal("Gardien · Chasseur")
	assert_int(panel["hp_max"]).is_equal(catalog.units.hp(CHASSEUR))
	assert_array(panel["stats"]).is_equal([["MVT", catalog.units.move(CHASSEUR)], ["ATQ", catalog.units.attack(CHASSEUR)],
			["DÉF", catalog.units.defense(CHASSEUR)], ["VUE", catalog.units.vision(CHASSEUR)]])
	assert_str(panel["lines"][2]).starts_with("Plaine : ")


func test_a_selection_wins_over_the_tapped_tile() -> void:
	var state := _board()
	var assaut := state.view().unit_at(state.tile_index(2, 1))

	var model := HudModel.build(state, _catalog(), false, assaut, [], {"inspect": state.tile_index(2, 0)})

	assert_str(model.unit_panel["title"]).is_equal("Assaut")


func test_idle_units_are_counted_in_the_players_phase_and_the_end_turn_asks_only_when_it_can_end() -> void:
	var state := _board()

	var model := HudModel.build(state, _catalog(), false, -1, [], {"end_turn_armed": true})

	assert_int(model.idle_units).is_equal(1)
	assert_bool(model.end_turn_armed).is_true()
	assert_bool(HudModel.build(state, _catalog(), true, -1, [], {"end_turn_armed": true}).end_turn_armed).is_false()  # locked
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	assert_int(HudModel.build(state, _catalog(), false, -1, []).idle_units).is_equal(0)
