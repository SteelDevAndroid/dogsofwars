# A simple player for balance runs (not a game system): each unit, in id order, captures the
# node it stands on, else strikes what it can reach, else walks toward the nearest objective
# (a node not held, a ruin not read, an enemy), then strikes or captures again; affordable
# upgrades are bought first. The pipeline is the oracle: a refused command is simply skipped.
class_name ScriptedPlayer
extends RefCounted

var commands := 0


func play_turn(state: GameState, pipeline: CommandPipeline, catalog: DataCatalog) -> void:
	for node_id in FactionView.new(state, Faction.PLAYER).node_ids():
		if FactionView.new(state, Faction.PLAYER).node_owner(node_id) == Faction.PLAYER:
			_submit(pipeline, UpgradeNodeCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, node_id))
	for unit_id in FactionView.new(state, Faction.PLAYER).unit_ids():
		var view := FactionView.new(state, Faction.PLAYER)
		if view.unit_faction(unit_id) != Faction.PLAYER or view.unit_asleep(unit_id):
			continue
		_act(state, pipeline, catalog, unit_id)
		if state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_FINISHED:
			return
		_walk(state, pipeline, catalog, unit_id)
		_act(state, pipeline, catalog, unit_id)


func _act(state: GameState, pipeline: CommandPipeline, catalog: DataCatalog, unit_id: int) -> void:
	if not _submit(pipeline, CaptureCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, unit_id)):
		var view := FactionView.new(state, Faction.PLAYER)
		if view.unit_at(view.unit_tile(unit_id)) != unit_id:
			return
		for target_id in view.unit_ids():
			if view.unit_faction(target_id) == Faction.AI and not view.unit_asleep(target_id) \
					and _submit(pipeline, AttackCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, unit_id, target_id)):
				return


func _walk(state: GameState, pipeline: CommandPipeline, catalog: DataCatalog, unit_id: int) -> void:
	var view := FactionView.new(state, Faction.PLAYER)
	if view.unit_moved(unit_id) or view.unit_hp(unit_id) <= 0:
		return
	var start := view.unit_tile(unit_id)
	var goal := _objective(view, unit_id, catalog)
	if goal < 0:
		return
	var width := view.width()
	var best := start
	var best_distance := CombatRules.distance(width, start, goal)
	for tile in pipeline.check_move_range(view, Faction.PLAYER, unit_id):
		var distance := CombatRules.distance(width, tile, goal)
		if distance < best_distance or (distance == best_distance and tile < best and best != start):
			best = tile
			best_distance = distance
	if best != start:
		_submit(pipeline, MoveCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, unit_id, best))


func _objective(view: StateView, unit_id: int, catalog: DataCatalog) -> int:
	var start := view.unit_tile(unit_id)
	var width := view.width()
	var tiles: Array[int] = []
	if catalog.units.can_capture(view.unit_type(unit_id)):
		for node_id in view.node_ids():
			if view.node_owner(node_id) != Faction.PLAYER:
				tiles.append(view.node_tile(node_id))
		for ruin_id in view.ruin_ids():
			if view.ruin_read_pending(ruin_id) or true:
				tiles.append(view.ruin_tile(ruin_id))
	for other in view.unit_ids():
		if view.unit_faction(other) == Faction.AI and not view.unit_asleep(other):
			tiles.append(view.unit_tile(other))
	var best := -1
	var best_distance := 0
	for tile in tiles:
		var distance := CombatRules.distance(width, start, tile)
		if distance > 0 and (best < 0 or distance < best_distance):
			best = tile
			best_distance = distance
	return best


func _submit(pipeline: CommandPipeline, command: Command) -> bool:
	var result := pipeline.submit(command)
	if result.permitted:
		commands += 1
	return result.permitted
