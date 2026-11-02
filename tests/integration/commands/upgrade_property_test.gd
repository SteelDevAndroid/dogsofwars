# One node upgrade on random states (GDD 11 rule 12): the price is paid, exactly one
# node changes (one level up, upgraded this turn), the territory is a fixed point of
# its own recompute, the state stays valid and the preview shows the same events.
extends GdUnitTestSuite

const SEED := 4004
const STATES := 200
const MIN_UPGRADES := 8


func _first_upgrade(fx: PipelineFixture) -> UpgradeNodeCommand:
	for node_id in FactionView.new(fx.state, Faction.PLAYER).node_ids():
		var upgrade := UpgradeNodeCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, node_id)
		if fx.pipeline.check(upgrade).permitted:
			return upgrade
	return null


## Every node as [owner, level, tile, since, upgraded], by id.
func _nodes(state: GameState) -> Dictionary:
	var out := {}
	for row in state.nodes.row_count():
		out[state.nodes.id_of(row)] = [state.nodes.owner_of(row), state.nodes.level_of(row),
			state.nodes.tile_of(row), state.nodes.since_turn_of(row), state.nodes.upgraded_turn_of(row)]
	return out


func test_an_upgrade_changes_exactly_one_node_and_the_energy() -> void:
	var catalog := CatalogFactory.standard()
	var upgrades := 0
	var states := StateFactory.random_states(STATES, SEED)
	for k in states.size():
		var state := states[k]
		GameStateSetup.set_phase(state, HeaderSlice.PHASE_PLAYER, Faction.PLAYER)
		var fx := PipelineFixture.new(state)
		var upgrade := _first_upgrade(fx)
		if upgrade == null:
			continue
		upgrades += 1
		var context := "seed %d state %d" % [SEED, k]
		var before := _nodes(state)
		var energy := EnergyRules.stock(state, Faction.PLAYER)
		var price := catalog.nodes.upgrade_price(before[upgrade.node_id][1])
		var preview := fx.pipeline.preview(upgrade)

		assert_bool(fx.pipeline.submit(upgrade).permitted).is_true()

		var after := _nodes(state)
		assert_array(after.keys()).override_failure_message(context).is_equal(before.keys())
		assert_int(EnergyRules.stock(state, Faction.PLAYER)).override_failure_message(context).is_equal(energy - price)
		assert_array(after[upgrade.node_id]).override_failure_message(context).is_equal(
			[Faction.PLAYER, before[upgrade.node_id][1] + 1, before[upgrade.node_id][2], before[upgrade.node_id][3], state.turn()])
		for id: int in before:
			if id != upgrade.node_id:
				assert_array(after[id]).override_failure_message("%s: node %d" % [context, id]).is_equal(before[id])
		assert_array(TerritoryRules.recompute(state, catalog.nodes, MapSlice.CAUSE_UPGRADE)).override_failure_message(context).is_empty()
		assert_array(state.validate()).override_failure_message(context).is_empty()
		assert_int((fx.last_events()[0] as EnergyChangedEvent).after).is_equal((preview.events[0] as EnergyChangedEvent).after)
		assert_int((fx.last_events()[1] as NodeUpgradedEvent).level).is_equal((preview.events[1] as NodeUpgradedEvent).level)
	assert_int(upgrades).override_failure_message("too few upgrades found (%d): the property is vacuous" % upgrades).is_greater(MIN_UPGRADES)
