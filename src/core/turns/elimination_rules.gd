# Elimination (GDD 3 rules 9 to 12, GDD 11 rule 16), owned by the turn system: a
# faction holding no node is eliminated in the command that took its last node.
# Its units are destroyed (ascending ids), its ruin tiles released, then
# FACTION_ÉLIMINÉE, then PARTIE_TERMINÉE when no adverse faction is left.
class_name EliminationRules
extends RefCounted


static func eliminate(state: GameState, faction: int, nodes: NodeParams, events: Array[PresentationEvent]) -> void:
	for row in state.units.live_rows():
		if state.units.faction_of(row) == faction:
			var unit_id := state.units.id_of(row)
			var tile := state.units.tile_of(row)
			UnitWrites.destroy(state, unit_id)
			events.append(UnitDestroyedEvent.new(faction, unit_id, tile, -1))
	TurnWrites.eliminate(state, faction)
	TerritoryRules.release_ruin_tiles(state, faction)
	events.append(FactionEliminatedEvent.new(faction))
	var survivors := PackedInt32Array()
	for f in state.faction_count():
		if not state.factions.is_eliminated(f):
			survivors.append(f)
	if survivors.size() == 1:
		var status := HeaderSlice.END_DOMINATION if survivors[0] == Faction.PLAYER else HeaderSlice.END_ELIMINATED
		TurnWrites.finish(state, status)
		events.append(MatchEndedEvent.new(status))
