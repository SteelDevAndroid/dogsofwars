# CAPTURER (GDD 11 rules 4 to 7 and 16), owned by the nodes system. Validation order
# after the prefix: AUCUNE_INTENTION (an AI capture only comes from an intention,
# ADR-0004 §9), UNITÉ_INCONNUE, TYPE_NON_CAPABLE, DÉJÀ_AGI, PAS_SUR_UN_NŒUD,
# NŒUD_DÉJÀ_POSSÉDÉ (a neutral or enemy node is capturable). Application: the unit
# has acted, the node changes hands and loses a level, the territory is recomputed,
# the view of both factions too (GDD 5 rule 9); the previous owner holding no node
# any more is eliminated in the same command.
class_name CaptureHandler
extends CommandHandler


func validate(view: StateView, command: Command, rules: RuleTable) -> ValidationResult:
	var capture := command as CaptureCommand
	if capture.emitter == Command.EMITTER_AI:
		return ValidationResult.refused(Refusal.NO_INTENTION)
	if view.unit_faction(capture.unit_id) != capture.faction:
		return ValidationResult.refused(Refusal.UNKNOWN_UNIT)
	if not rules.catalog.units.can_capture(view.unit_type(capture.unit_id)):
		return ValidationResult.refused(Refusal.TYPE_NOT_CAPABLE)
	if view.unit_acted(capture.unit_id):
		return ValidationResult.refused(Refusal.ALREADY_ACTED)
	var node_id := view.node_at(view.unit_tile(capture.unit_id))
	if node_id < 0:
		return ValidationResult.refused(Refusal.NOT_ON_A_NODE)
	if view.node_owner(node_id) == capture.faction:
		return ValidationResult.refused(Refusal.NODE_ALREADY_OWNED)
	return ValidationResult.ok()


func apply(state: GameState, command: Command, rules: RuleTable) -> ApplyResult:
	var capture := command as CaptureCommand
	var result := ApplyResult.new()
	var tile := state.view().unit_tile(capture.unit_id)
	var node_id := state.view().node_at(tile)
	var previous := state.view().node_owner(node_id)
	UnitWrites.set_acted(state, capture.unit_id)
	NodeWrites.capture(state, node_id, capture.faction)
	result.events.append(NodeCapturedEvent.new(node_id, capture.faction, previous, tile))
	_territory_events(TerritoryRules.recompute(state, rules.catalog.nodes, MapSlice.CAUSE_CAPTURE), result.events)
	if previous != Faction.NONE and not _holds_a_node(state, previous):
		EliminationRules.eliminate(state, previous, rules.catalog.nodes, result.events)
		_territory_events(TerritoryRules.recompute(state, rules.catalog.nodes, MapSlice.CAUSE_CAPTURE), result.events)
	result.vision = VisionService.recompute(state, rules.vision)
	if not result.vision.discovered_tiles.is_empty():
		result.events.append(TilesRevealedEvent.new(result.vision.discovered_tiles))
	return result


static func _holds_a_node(state: GameState, faction: int) -> bool:
	for row in state.nodes.row_count():
		if state.nodes.owner_of(row) == faction:
			return true
	return false


static func _territory_events(groups: Array, events: Array[PresentationEvent]) -> void:
	for group: Array in groups:
		events.append(TileOwnersChangedEvent.new(group[0], group[1], group[2]))
