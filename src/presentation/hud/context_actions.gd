# What the player may do with the current selection, asked of the pipeline (`check`, so the
# greyed buttons and the real refusals are one and the same rule, ADR-0004 §6): capture on
# the node under the selected unit, wake a dormant next to it, raise the selected node, start a
# protocol. A button shows when the action applies to the selection and is greyed, with the
# reason, when the pipeline would refuse it.
class_name ContextActions
extends RefCounted


## Capture, wake and upgrade for a selected unit and/or node (-1 for none).
static func for_selection(state: GameState, catalog: DataCatalog, pipeline: CommandPipeline, unit_id: int, node_id: int) -> Array[ContextAction]:
	var actions: Array[ContextAction] = []
	var view := FactionView.new(state, Faction.PLAYER)
	if unit_id >= 0 and view.unit_faction(unit_id) == Faction.PLAYER:
		var type := view.unit_type(unit_id)
		node_id = view.node_at(view.unit_tile(unit_id))
		if catalog.units.can_capture(type) and node_id >= 0 and view.node_owner(node_id) != Faction.PLAYER:
			var capture := pipeline.check(CaptureCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, unit_id))
			actions.append(ContextAction.new(&"capture", "Capturer", capture.permitted, "" if capture.permitted else RefusalText.of(capture)))
		if not wake_targets(state, pipeline, unit_id, true).is_empty():
			var targets := wake_targets(state, pipeline, unit_id, false)
			actions.append(ContextAction.new(&"wake", "Réveiller", not targets.is_empty(),
					"" if not targets.is_empty() else _wake_reason(state, pipeline, unit_id)))
	if node_id >= 0 and view.node_owner(node_id) == Faction.PLAYER and view.node_level(node_id) < catalog.nodes.max_level():
		var upgrade := pipeline.check(UpgradeNodeCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, node_id))
		var price := catalog.nodes.upgrade_price(view.node_level(node_id))
		actions.append(ContextAction.new(&"upgrade", "Monter (%d)" % price, upgrade.permitted, "" if upgrade.permitted else RefusalText.of(upgrade)))
	if unit_id >= 0 and view.unit_faction(unit_id) == Faction.PLAYER and catalog.units.ability(view.unit_type(unit_id)) != UnitTypes.ABILITY_NONE:
		var use := pipeline.check(AbilityCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, unit_id))
		actions.append(ContextAction.new(&"ability", ability_label(catalog, view.unit_type(unit_id), view.unit_cooldown(unit_id)),
				use.permitted, "" if use.permitted else RefusalText.of(use)))
	return actions


## The button of a type's ability: its name, and the turns left while it recharges.
static func ability_label(catalog: DataCatalog, type: int, cooldown: int) -> String:
	var name: String = DisplayNames.ABILITIES.get(catalog.units.ability(type), "Capacité")
	return name if cooldown == 0 else "%s (%d)" % [name, cooldown]


## Dormant units next to a unit (distance 1, visible), with `any` the ones the pipeline accepts
## or not; otherwise only the accepted ones.
static func wake_targets(state: GameState, pipeline: CommandPipeline, unit_id: int, any: bool) -> Array[int]:
	var targets: Array[int] = []
	var view := FactionView.new(state, Faction.PLAYER)
	for id in view.unit_ids():
		if view.unit_asleep(id) and CombatRules.distance(view.width(), view.unit_tile(unit_id), view.unit_tile(id)) == 1:
			if any or pipeline.check(WakeCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, unit_id, id)).permitted:
				targets.append(id)
	return targets


## The price line shown when a dormant is chosen.
static func wake_text(state: GameState, catalog: DataCatalog, target_id: int) -> String:
	var view := FactionView.new(state, Faction.PLAYER)
	var type := view.unit_type(target_id)
	return "Réveiller %s : %d énergie" % [DisplayNames.unit(catalog.units.key(type)), WakeRules.price(view, Faction.PLAYER, type, catalog)]


## One row per protocol of the tree: the id is "research:<n>".
static func research_rows(state: GameState, catalog: DataCatalog, pipeline: CommandPipeline) -> Array[ContextAction]:
	var rows: Array[ContextAction] = []
	var view := FactionView.new(state, Faction.PLAYER)
	var tree := catalog.protocols
	for protocol in tree.count():
		var name := DisplayNames.protocol(tree.key(protocol))
		var id := StringName("research:%d" % protocol)
		if view.has_protocol(Faction.PLAYER, protocol):
			rows.append(ContextAction.new(id, "%s · acquis" % name, false, "Déjà acquis"))
		elif view.research(Faction.PLAYER) == protocol:
			rows.append(ContextAction.new(id, "%s · en cours" % name, false, "Recherche en cours"))
		else:
			var check := pipeline.check(ResearchCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, protocol))
			rows.append(ContextAction.new(id, "%s · %d énergie · %d tours" % [name, tree.price(protocol), tree.duration(protocol)],
					check.permitted, "" if check.permitted else RefusalText.of(check)))
	return rows


## The panel of a selected node of the player.
static func node_panel(state: GameState, catalog: DataCatalog, node_id: int) -> Dictionary:
	var view := FactionView.new(state, Faction.PLAYER)
	if node_id < 0 or view.node_owner(node_id) != Faction.PLAYER:
		return {}
	var level := view.node_level(node_id)
	var lines: Array[String] = ["Revenu +%d par tour" % catalog.energy.income(level)]
	if level < catalog.nodes.max_level():
		lines.append("Niveau suivant : revenu +%d, coût %d" % [catalog.energy.income(level + 1), catalog.nodes.upgrade_price(level)])
	else:
		lines.append("Niveau maximal")
	return {"title": "Nœud · niveau %d" % level, "lines": lines}


static func _wake_reason(state: GameState, pipeline: CommandPipeline, unit_id: int) -> String:
	for id in wake_targets(state, pipeline, unit_id, true):
		return RefusalText.of(pipeline.check(WakeCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, unit_id, id)))
	return ""
