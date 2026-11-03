extends GdUnitTestSuite


func _setup() -> Array:
	var hud := Hud.new()
	add_child(hud)
	var gate := CommandGate.new()
	var sequencer := PresentationSequencer.new()
	var params := CatalogFactory.standard().presentation
	return [HudPresenter.new(hud, gate, sequencer, params), hud, gate, sequencer, FakeClock.new(2.0)]


func _free(set_up: Array) -> void:
	set_up[1].free()
	set_up[3].free()


func test_a_reading_with_a_fragment_opens_the_panel_and_locks_the_player() -> void:
	var set_up := _setup()
	var presenter: HudPresenter = set_up[0]
	var hud: Hud = set_up[1]
	var gate: CommandGate = set_up[2]
	var sequencer: PresentationSequencer = set_up[3]

	var hold := presenter.handle(RuinReadEvent.new(0, 1, 3, 5), SequenceContext.new(2.0, set_up[4]))

	assert_int(hold.duration_ms).is_equal(0)
	assert_bool(hud.fragment_panel.is_open).is_true()
	assert_str(hud.fragment_panel.title_label.text).is_equal("Fragment 3")
	assert_bool(gate.is_locked(Faction.PLAYER, Command.EMITTER_PLAYER)).is_true()
	assert_bool(gate.is_locked(Faction.PLAYER, Command.EMITTER_AI)).is_false()
	assert_bool(sequencer.panel_open).is_true()
	_free(set_up)


func test_a_reading_without_fragment_gives_a_notice_with_the_tiles_gained() -> void:
	var set_up := _setup()
	var presenter: HudPresenter = set_up[0]
	var hud: Hud = set_up[1]
	var context := SequenceContext.new(2.0, set_up[4])

	presenter.handle(TileOwnersChangedEvent.new(PackedInt32Array([1, 2, 3]), Faction.NONE, Faction.PLAYER), context)
	presenter.handle(RuinReadEvent.new(0, 1, 0, 5), context)

	assert_str(presenter.notice).is_equal("Ruine lue · +3 tuiles")
	assert_bool(hud.fragment_panel.is_open).is_false()
	presenter.handle(RuinReadEvent.new(0, 2, 0, 6), context)
	assert_str(presenter.notice).is_equal("Ruine lue")  # the count starts over
	_free(set_up)


func test_the_journal_tells_the_enemy_actions_one_at_a_time_and_empties_with_the_players_turn() -> void:
	var set_up := _setup()
	var presenter: HudPresenter = set_up[0]
	var context := SequenceContext.new(2.0, set_up[4])

	assert_int(presenter.handle(IntentionExecutedEvent.new(0, 1, 0, 5), context).duration_ms).is_equal(500)
	assert_int(presenter.handle(IntentionExecutedEvent.new(0, 1, 0, 5), SequenceContext.new(2.0, set_up[4], true)).duration_ms).is_equal(0)
	assert_int(presenter.handle(IntentionAnnouncedEvent.new(1, 1, 0, 0, 5, 0, 0), context).duration_ms).is_equal(0)
	assert_int(presenter.journal.size()).is_equal(3)
	presenter.notice = "x"
	presenter.handle(TurnStartedEvent.new(2, Faction.AI, HeaderSlice.PHASE_ENEMY_EXECUTION), context)
	assert_int(presenter.journal.size()).is_equal(3)
	presenter.handle(TurnStartedEvent.new(2, Faction.PLAYER, HeaderSlice.PHASE_PLAYER), context)

	assert_int(presenter.journal.size()).is_equal(0)
	assert_str(presenter.notice).is_empty()
	_free(set_up)


func test_the_panel_cannot_be_closed_before_its_delay() -> void:
	var panel := FragmentPanel.new()
	add_child(panel)
	var closed := [0]
	panel.closed.connect(func() -> void: closed[0] += 1)
	panel.open(2, 10.0, 0.5)

	panel.tick(10.4)
	panel.continue_button.pressed.emit()
	assert_bool(panel.is_open).is_true()
	assert_int(closed[0]).is_equal(0)
	panel.tick(10.5)
	assert_bool(panel.continue_button.disabled).is_false()
	panel.continue_button.pressed.emit()

	assert_bool(panel.is_open).is_false()
	assert_bool(panel.visible).is_false()
	assert_int(closed[0]).is_equal(1)
	panel.free()


func test_the_panel_shows_the_text_of_the_fragment_from_the_pool() -> void:
	var set_up := _setup()
	var hud: Hud = set_up[1]
	var pool := CatalogFactory.standard().fragments
	var presenter := HudPresenter.new(hud, set_up[2], set_up[3], CatalogFactory.standard().presentation, pool)

	presenter.handle(RuinReadEvent.new(0, 1, 2, 5), SequenceContext.new(2.0, set_up[4]))

	assert_str(hud.fragment_panel.title_label.text).is_equal("Fragment")
	assert_str(hud.fragment_panel.body_label.text).is_equal("On allume les balises.")
	assert_str(hud.fragment_panel.source_label.text).is_equal("Journal")
	_free(set_up)


func _turn(faction: int, turn: int) -> TurnStartedEvent:
	return TurnStartedEvent.new(turn, faction, HeaderSlice.PHASE_PLAYER if faction == Faction.PLAYER else HeaderSlice.PHASE_ENEMY_EXECUTION)


func test_the_enemy_phase_is_summed_up_when_the_players_turn_begins() -> void:
	var set_up := _setup()
	var presenter: HudPresenter = set_up[0]
	var hud: Hud = set_up[1]
	var context := SequenceContext.new(2.0, set_up[4])

	presenter.handle(_turn(Faction.AI, 1), context)
	presenter.handle(UnitDestroyedEvent.new(Faction.PLAYER, 3, 5, 9), context)
	presenter.handle(UnitDestroyedEvent.new(Faction.PLAYER, 4, 6, 9), context)
	presenter.handle(UnitDestroyedEvent.new(Faction.AI, 9, 7, 3), context)
	presenter.handle(NodeCapturedEvent.new(1, Faction.AI, Faction.PLAYER, 8), context)
	presenter.handle(NodeCapturedEvent.new(2, Faction.PLAYER, Faction.AI, 9), context)  # the player's own capture is not the enemy's
	presenter.handle(IntentionAnnouncedEvent.new(1, 9, 0, 3, 5, 0, 0), context)
	presenter.handle(_turn(Faction.PLAYER, 2), context)

	assert_str(presenter.summary).is_equal("Tour ennemi : 2 drones perdus · 1 Gardien détruit · 1 nœud pris par l'ennemi · 1 menace annoncée")
	assert_int(presenter.summary_tile).is_equal(5)  # the first drone lost
	assert_int(hud.toast_tile()).is_equal(5)  # a tap on the summary takes the camera there
	assert_bool(hud.toast_panel.visible).is_true()
	assert_str(hud.toast_label.text).is_equal(presenter.summary)
	hud.tick_toast(2.0 + HudPresenter.SUMMARY_SECONDS)
	assert_bool(hud.toast_panel.visible).is_false()
	_free(set_up)


func test_a_quiet_enemy_phase_is_said_so_and_the_first_turn_says_nothing() -> void:
	var set_up := _setup()
	var presenter: HudPresenter = set_up[0]
	var hud: Hud = set_up[1]
	var context := SequenceContext.new(2.0, set_up[4])

	presenter.handle(_turn(Faction.PLAYER, 1), context)  # no enemy phase before it
	assert_str(presenter.summary).is_empty()
	assert_bool(hud.toast_panel.visible).is_false()
	presenter.handle(_turn(Faction.AI, 1), context)
	presenter.handle(_turn(Faction.PLAYER, 2), context)

	assert_str(presenter.summary).is_equal("Tour ennemi : rien à signaler")
	assert_int(presenter.summary_tile).is_equal(-1)  # nothing to show
	_free(set_up)


func test_the_counts_start_over_every_enemy_phase_and_agree_in_number() -> void:
	var set_up := _setup()
	var presenter: HudPresenter = set_up[0]
	var context := SequenceContext.new(2.0, set_up[4])
	presenter.handle(_turn(Faction.AI, 1), context)
	presenter.handle(UnitDestroyedEvent.new(Faction.PLAYER, 3, 5, 9), context)
	presenter.handle(_turn(Faction.PLAYER, 2), context)
	assert_str(presenter.summary).is_equal("Tour ennemi : 1 drone perdu")

	presenter.handle(_turn(Faction.AI, 2), context)
	presenter.handle(_turn(Faction.PLAYER, 3), context)

	assert_str(presenter.summary).is_equal("Tour ennemi : rien à signaler")
	assert_str(HudPresenter.enemy_phase_line(0, 2, 2, 2)).is_equal("Tour ennemi : 2 Gardiens détruits · 2 nœuds pris par l'ennemi · 2 menaces annoncées")
	_free(set_up)
