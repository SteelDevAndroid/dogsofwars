# DÉPLACER (GDD 23, GDD 6 rules 4 and 5, GDD 5 rules 11 and 12), owned by the units
# system. Validated on the faction's view; applied step by step on the state:
# an unseen unit on the path stops the move on the last free tile (ambush), an
# undiscovered obstacle or a real cost beyond the points left stops it too, with
# no penalty. The move is spent in every case.
class_name MoveHandler
extends CommandHandler


func validate(view: StateView, command: Command, rules: RuleTable) -> ValidationResult:
	var move := command as MoveCommand
	var unit_error := unit_error(view, move.faction, move.unit_id, rules.catalog)
	if unit_error != &"":
		return ValidationResult.refused(unit_error)
	var found := MovementRules.search(view, move.unit_id, rules.catalog)
	var tile_error := MovementRules.destination_error(view, found, move.tile)
	return ValidationResult.ok() if tile_error == &"" else ValidationResult.refused(tile_error)


func apply(state: GameState, command: Command, rules: RuleTable) -> ApplyResult:
	var move := command as MoveCommand
	var result := ApplyResult.new()
	var view := FactionView.new(state, move.faction)
	var found := MovementRules.search(view, move.unit_id, rules.catalog)
	var start := view.unit_tile(move.unit_id)
	var points := found.points
	var first := true
	var at := start
	for tile in MovementRules.path(found, move.tile):
		if state.units.live_row_at(tile) >= 0:
			break
		var cost := rules.catalog.terrain.entry_cost(state.terrain.at(tile))
		if cost == TerrainParams.IMPASSABLE or (cost > points and not (first and found.full_points)):
			break
		points = maxi(0, points - cost)
		first = false
		at = tile
		UnitWrites.move_to(state, move.unit_id, tile)
		result.vision.merge(VisionService.reveal_step(state, rules.vision, move.unit_id, tile))
	UnitWrites.set_moved(state, move.unit_id)
	result.vision.merge(VisionService.recompute(state, rules.vision))
	# An ambush (case d of GDD 5 rule 13) always reveals the enemy: it stands on a
	# neighbour, never hidden (GDD 5 rule 8), so case b covers it.
	result.revealed = move.faction == Faction.PLAYER and result.vision.revealed
	result.events.append(UnitMovedEvent.new(move.faction, move.unit_id, start, at, move.tile))
	if not result.vision.discovered_tiles.is_empty():
		result.events.append(TilesRevealedEvent.new(result.vision.discovered_tiles))
	return result


## Unit checks of DÉPLACER, in the order of GDD 23 and GDD 6, or "".
static func unit_error(view: StateView, faction: int, unit_id: int, catalog: DataCatalog) -> StringName:
	if view.unit_faction(unit_id) != faction:
		return Refusal.UNKNOWN_UNIT
	if view.unit_asleep(unit_id):
		return Refusal.UNIT_ASLEEP
	if view.unit_moved(unit_id):
		return Refusal.ALREADY_MOVED
	if ProtocolEffects.unit_stat(view, faction, view.unit_type(unit_id), ProtocolEffects.MOVE, catalog) == 0:
		return Refusal.UNIT_IMMOBILE
	return &""
