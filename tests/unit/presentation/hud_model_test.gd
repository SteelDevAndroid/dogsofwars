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
	assert_str(model.energy_text).is_equal("Énergie 17")
	assert_str(model.fragments_text).is_equal("Ruines lues 0")
	var weights := _catalog().score
	assert_str(model.score_text).is_equal("Victoire : %d contre %d" % [ScoreRules.decisive(state, 0, weights), ScoreRules.decisive(state, 1, weights)])


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


func test_losses_of_the_last_enemy_phase_give_chips() -> void:
	var state := _board()
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
	RecallWrites.unit_lost(state, 5, Faction.PLAYER)
	RecallWrites.unit_lost(state, 6, Faction.AI)  # an enemy loss is not a loss for the player
	RecallWrites.tile_lost(state, 7)
	GameStateSetup.set_phase(state, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)

	assert_array(_model(state).loss_chips).is_equal(["Drone perdu", "Territoire perdu"])


func test_the_ruin_chip_says_a_ruin_is_known_without_a_number() -> void:
	var state := _board()

	assert_str(_model(state).ruin_chip).is_equal("Ruine repérée")
	var catalog := _catalog()
	var read := RuinWrites
	read.mark_read(state, 0, Faction.PLAYER)
	assert_str(_model(state).ruin_chip).is_empty()


func test_the_unit_panel_shows_effective_stats_and_hides_other_units() -> void:
	var state := _board()

	var panel := _model(state, false, 0).unit_panel

	assert_str(panel["title"]).is_equal("Assaut")
	assert_array(panel["lines"]).is_equal(["PV 8 / 8", "MVT 3  ATQ 3  DÉF 1  Vue 2"])
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
