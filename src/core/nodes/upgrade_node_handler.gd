# MONTER_NŒUD (GDD 11 rules 11 and 12), owned by the nodes system. Validation after
# the prefix, first failure returned, on the faction's view: NŒUD_INCONNU (an
# undiscovered node and a missing id alike), NŒUD_NON_POSSÉDÉ, NŒUD_ACQUIS_CE_TOUR
# (acquired this turn or later), NIVEAU_MAX, DÉJÀ_MONTÉ (one upgrade per node and
# turn), ÉNERGIE_INSUFFISANTE (need, available) last. No unit is required and an
# enemy unit standing on the node does not prevent it. Application: spend, level up,
# territory recomputed (it may widen), the view of both factions recomputed (a level 3
# node sees farther, GDD 5 rule 9); the income changes at the start of the next turn.
class_name UpgradeNodeHandler
extends CommandHandler


func validate(view: StateView, command: Command, rules: RuleTable) -> ValidationResult:
	var upgrade := command as UpgradeNodeCommand
	if view.node_tile(upgrade.node_id) < 0:
		return ValidationResult.refused(Refusal.UNKNOWN_NODE)
	if view.node_owner(upgrade.node_id) != upgrade.faction:
		return ValidationResult.refused(Refusal.NODE_NOT_OWNED)
	if view.node_since_turn(upgrade.node_id) >= view.turn():
		return ValidationResult.refused(Refusal.NODE_ACQUIRED_THIS_TURN)
	var level := view.node_level(upgrade.node_id)
	if level >= rules.catalog.nodes.max_level():
		return ValidationResult.refused(Refusal.MAX_LEVEL)
	if view.node_upgraded_turn(upgrade.node_id) == view.turn():
		return ValidationResult.refused(Refusal.ALREADY_UPGRADED)
	var price := rules.catalog.nodes.upgrade_price(level)
	if view.energy(upgrade.faction) < price:
		return ValidationResult.refused(Refusal.NOT_ENOUGH_ENERGY, PackedInt64Array([price, view.energy(upgrade.faction)]))
	return ValidationResult.ok()


func apply(state: GameState, command: Command, rules: RuleTable) -> ApplyResult:
	var upgrade := command as UpgradeNodeCommand
	var result := ApplyResult.new()
	var row := state.nodes.find_row(upgrade.node_id)
	assert(state.nodes.owner_of(row) == upgrade.faction, "validation let through a node the faction does not own")
	EnergyRules.spend(state, upgrade.faction, rules.catalog.nodes.upgrade_price(state.nodes.level_of(row)), result.events)
	NodeWrites.upgrade(state, upgrade.node_id)
	result.events.append(NodeUpgradedEvent.new(upgrade.faction, upgrade.node_id, state.nodes.level_of(row), state.nodes.tile_of(row)))
	for group: Array in TerritoryRules.recompute(state, rules.catalog.nodes, MapSlice.CAUSE_UPGRADE):
		result.events.append(TileOwnersChangedEvent.new(group[0], group[1], group[2]))
	result.vision = VisionService.recompute(state, rules.vision)
	WaveSource.stamp(result.events, state.nodes.tile_of(row), state)
	if not result.vision.discovered_tiles.is_empty():
		result.events.append(TilesRevealedEvent.new(result.vision.discovered_tiles))
	return result
