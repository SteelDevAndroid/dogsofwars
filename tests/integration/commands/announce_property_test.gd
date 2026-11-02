# One announcement on random states (GDD 9 step 6): every attack the AI can announce
# (an AI unit with ATQ, a visible player unit within range) is stored once with the
# positions of the state; the state stays valid, nothing but the AI data, the intention
# id counter and the log changes, the replay of the log gives an equal state and the
# preview shows the same events.
extends GdUnitTestSuite

const SEED := 9009
const STATES := 200
const MIN_ANNOUNCEMENTS := 8


## Strictly ascending authors, each one the first player unit its view lets it attack.
func _announcement(fx: PipelineFixture) -> AnnounceIntentionsCommand:
	var view := FactionView.new(fx.state, Faction.AI)
	var intentions := PackedInt64Array()
	for author in view.unit_ids():
		if view.unit_faction(author) != Faction.AI:
			continue
		for target in view.unit_ids():
			if view.unit_faction(target) != Faction.PLAYER:
				continue
			var candidate := AnnounceIntentionsCommand.new(-1, 0, PackedInt64Array([author, IntentionsSlice.TARGET_UNIT, target,
					IntentionsSlice.ACTION_ATTACK, IntentionsSlice.MOTIVE_HUNT]))
			if fx.pipeline.check(candidate).permitted:
				intentions.append_array(candidate.intentions)
				break
	var agents := PackedInt64Array()
	for author_index in intentions.size() / AnnounceIntentionsCommand.INTENTION_WIDTH:
		agents.append_array(PackedInt64Array([intentions[author_index * AnnounceIntentionsCommand.INTENTION_WIDTH],
				AiAgentsSlice.ROLE_HUNT, 0, AiAgentsSlice.NO_POST, IntentionsSlice.MOTIVE_HUNT]))
	return null if intentions.is_empty() else AnnounceIntentionsCommand.new(-1, 0, intentions, agents)


func test_an_announcement_stores_its_intentions_and_changes_nothing_else() -> void:
	var announced := 0
	var states := StateFactory.random_states(STATES, SEED)
	for k in states.size():
		var initial := states[k]
		GameStateSetup.set_phase(initial, HeaderSlice.PHASE_ENEMY_EXECUTION, Faction.AI)
		var state := initial.duplicate_state()
		var fx := PipelineFixture.new(state)
		var command := _announcement(fx)
		if command == null:
			continue
		announced += 1
		var context := "seed %d state %d" % [SEED, k]
		var count := command.intentions.size() / AnnounceIntentionsCommand.INTENTION_WIDTH
		var preview := fx.pipeline.preview(command)

		assert_bool(fx.pipeline.submit(command).permitted).override_failure_message(context).is_true()

		assert_int(state.intentions.row_count()).override_failure_message(context).is_equal(count)
		for i in count:
			var tile_of_author := state.view().unit_tile(state.intentions.author_of(i))
			assert_int(state.intentions.author_tile_of(i)).override_failure_message(context).is_equal(tile_of_author)
			assert_int(state.intentions.target_tile_of(i)).override_failure_message(context).is_equal(
					state.view().unit_tile(state.intentions.target_id_of(i)))
		assert_array(state.validate()).override_failure_message(context).is_empty()
		var expected := initial.duplicate_state()
		expected.intentions.copy_from(state.intentions)
		expected.ai_agents.copy_from(state.ai_agents)
		expected.header.copy_from(state.header)
		expected.command_log.copy_from(state.command_log)
		assert_bool(expected.equals(state)).override_failure_message(context).is_true()
		assert_int(fx.last_events().size()).override_failure_message(context).is_equal(count)
		assert_int(preview.events.size()).override_failure_message(context).is_equal(count)
		var replay := CommandReplay.replay(initial, fx.log, CatalogFactory.standard())
		assert_int(replay.divergence).override_failure_message(context).is_equal(-1)
		assert_bool(replay.state.equals(state)).override_failure_message(context).is_true()
	assert_int(announced).override_failure_message("too few announcements (%d): the property is vacuous" % announced).is_greater(MIN_ANNOUNCEMENTS)
