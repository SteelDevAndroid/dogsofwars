# AC-X1 (GDD 8 rule 12, ADR-0004 §6): the preview of an attack, computed on the filtered
# copy with the simulation rules, equals the real application. Plus the invariants of
# one attack on random states.
extends GdUnitTestSuite

const SEED := 8080
const STATES := 150
const MIN_ATTACKS := 20


## One line per combat event, in order: what the HUD reads.
func _describe(events: Array[PresentationEvent]) -> Array:
	var lines := []
	for event in events:
		if event is AttackResolvedEvent:
			lines.append(["attack", event.attacker_id, event.target_id])
		elif event is UnitHitEvent:
			lines.append(["hit", event.unit_id, event.damage, event.hp_left])
		elif event is UnitDestroyedEvent:
			lines.append(["destroyed", event.unit_id, event.by])
	return lines


## First permitted attack of the player (ascending ids), or null.
func _first_attack(fx: PipelineFixture) -> AttackCommand:
	var view := FactionView.new(fx.state, Faction.PLAYER)
	for attacker in view.unit_ids():
		if view.unit_faction(attacker) != Faction.PLAYER:
			continue
		for target in view.unit_ids():
			if CombatRules.distance(view.width(), view.unit_tile(attacker), view.unit_tile(target)) > 1:
				continue
			var attack := AttackCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, attacker, target)
			if fx.pipeline.check(attack).permitted:
				return attack
	return null


func _live_count(state: GameState) -> int:
	return state.units.live_rows().size()


func test_preview_equals_the_real_attack_and_one_attack_destroys_at_most_one_unit() -> void:
	var attacks := 0
	var states := StateFactory.random_states(STATES, SEED)
	for k in states.size():
		var state := states[k]
		GameStateSetup.set_phase(state, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)
		var fx := PipelineFixture.new(state)
		var attack := _first_attack(fx)
		if attack == null:
			continue
		attacks += 1
		var before := state.duplicate_state()
		var live_before := _live_count(state)
		var hp_attacker := state.view().unit_hp(attack.attacker_id)
		var preview := fx.pipeline.preview(attack)
		assert_bool(state.equals(before)).override_failure_message("seed %d state %d: preview wrote" % [SEED, k]).is_true()

		assert_bool(fx.pipeline.submit(attack).permitted).is_true()

		var context := "seed %d state %d" % [SEED, k]
		assert_array(_describe(fx.last_events())).override_failure_message(context).is_equal(_describe(preview.events))
		assert_int(live_before - _live_count(state)).override_failure_message(context).is_between(0, 1)
		assert_bool(state.view().unit_acted(attack.attacker_id) or state.view().unit_tile(attack.attacker_id) < 0).is_true()
		assert_array(state.validate()).override_failure_message(context).is_empty()
		assert_int(state.view().unit_hp(attack.attacker_id)).is_less_equal(hp_attacker)
	assert_int(attacks).override_failure_message("too few attacks found (%d): the property is vacuous" % attacks).is_greater(MIN_ATTACKS)
