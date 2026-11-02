# One wake on random states (GDD 7 rule 3): the energy price is paid, exactly the
# dormant and its waker change, nothing is created, the state stays valid, and the
# preview shows the same energy and waking events.
extends GdUnitTestSuite

const SEED := 6502
const STATES := 150
const MIN_WAKES := 10


func _first_wake(fx: PipelineFixture) -> WakeCommand:
	var view := FactionView.new(fx.state, Faction.PLAYER)
	for waker in view.unit_ids():
		if view.unit_faction(waker) != Faction.PLAYER:
			continue
		for target in view.unit_ids():
			if CombatRules.distance(view.width(), view.unit_tile(waker), view.unit_tile(target)) != 1:
				continue
			var wake := WakeCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, waker, target)
			if fx.pipeline.check(wake).permitted:
				return wake
	return null


## Every unit as [faction, tile, hp, asleep, moved, acted, type], by id.
func _snapshot(state: GameState) -> Dictionary:
	var units := {}
	var view := state.view()
	for row in state.units.row_count():
		var id := state.units.id_of(row)
		units[id] = [state.units._unit_faction[row], state.units._unit_tile[row], state.units._unit_hp[row],
			state.units._unit_asleep[row], state.units._unit_moved[row], state.units._unit_acted[row],
			state.units._unit_type[row]]
	return units


func test_a_wake_changes_exactly_the_dormant_its_waker_and_the_energy() -> void:
	var wakes := 0
	var states := StateFactory.random_states(STATES, SEED)
	for k in states.size():
		var state := states[k]
		GameStateSetup.set_phase(state, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)
		var fx := PipelineFixture.new(state)
		var wake := _first_wake(fx)
		if wake == null:
			continue
		wakes += 1
		var context := "seed %d state %d" % [SEED, k]
		var before := _snapshot(state)
		var energy := EnergyRules.stock(state, Faction.PLAYER)
		var price := WakeRules.price(state.view(), Faction.PLAYER, state.view().unit_type(wake.target_id), CatalogFactory.standard())
		var next_id := state.header.value(HeaderSlice.NEXT_UNIT_ID)
		var preview := fx.pipeline.preview(wake)

		assert_bool(fx.pipeline.submit(wake).permitted).is_true()

		var after := _snapshot(state)
		assert_array(after.keys()).override_failure_message(context).is_equal(before.keys())
		assert_int(state.header.value(HeaderSlice.NEXT_UNIT_ID)).override_failure_message(context).is_equal(next_id)
		assert_int(EnergyRules.stock(state, Faction.PLAYER)).override_failure_message(context).is_equal(energy - price)
		var woken: Array = after[wake.target_id]
		var was: Array = before[wake.target_id]
		assert_array([woken[0], woken[3], woken[4], woken[5]]).override_failure_message(context).is_equal([Faction.PLAYER, 0, 1, 1])
		assert_array([woken[1], woken[2], woken[6]]).override_failure_message(context).is_equal([was[1], was[2], was[6]])
		assert_int(after[wake.waker_id][5]).override_failure_message(context).is_equal(1)
		for id: int in before:
			if id != wake.target_id and id != wake.waker_id:
				assert_array(after[id]).override_failure_message("%s: unit %d" % [context, id]).is_equal(before[id])
		assert_array(state.validate()).override_failure_message(context).is_empty()
		assert_int((fx.last_events()[0] as EnergyChangedEvent).after).is_equal((preview.events[0] as EnergyChangedEvent).after)
		assert_int((fx.last_events()[1] as DroneWokenEvent).unit_id).is_equal((preview.events[1] as DroneWokenEvent).unit_id)
	assert_int(wakes).override_failure_message("too few wakes found (%d): the property is vacuous" % wakes).is_greater(MIN_WAKES)
