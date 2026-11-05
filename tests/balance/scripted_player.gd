# A simple player for balance runs (not a game system): each unit, in id order, captures the
# node it stands on, else strikes what it can reach, else walks toward the nearest objective
# (a node not held, a ruin not read, an enemy), then strikes or captures again; affordable
# upgrades are bought first. Distances are path costs (MovementRules.cost_field), so a canyon
# or a ridge is walked around. With `use_abilities` it also uses the pack's abilities: Charge
# before a strike, Sprint toward a far objective, Repair when a neighbour is hurt, Hold when an
# enemy is near and nothing else was done. The pipeline is the oracle: a refused command is
# simply skipped.
class_name ScriptedPlayer
extends RefCounted

var commands := 0
var abilities_used := 0
var use_abilities := true


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
		_last_resort(state, pipeline, catalog, unit_id)


func _act(state: GameState, pipeline: CommandPipeline, catalog: DataCatalog, unit_id: int) -> void:
	if not _submit(pipeline, CaptureCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, unit_id)):
		var view := FactionView.new(state, Faction.PLAYER)
		if view.unit_at(view.unit_tile(unit_id)) != unit_id:
			return
		for target_id in view.unit_ids():
			if view.unit_faction(target_id) != Faction.AI or view.unit_asleep(target_id):
				continue
			var attack := AttackCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, unit_id, target_id)
			if not pipeline.check(attack).permitted:
				continue
			if _ability_is(catalog, view, unit_id, UnitTypes.ABILITY_CHARGE):
				_use_ability(pipeline, unit_id)
			if _submit(pipeline, attack):
				return


func _walk(state: GameState, pipeline: CommandPipeline, catalog: DataCatalog, unit_id: int) -> void:
	var view := FactionView.new(state, Faction.PLAYER)
	if view.unit_moved(unit_id) or view.unit_hp(unit_id) <= 0:
		return
	var start := view.unit_tile(unit_id)
	var goal := _objective(state, view, unit_id, catalog)
	if goal < 0:
		return
	var field := MovementRules.cost_field(view, goal, catalog, true)
	if _distance(field, start) > MovementRules.remaining_points(view, unit_id, catalog) \
			and _ability_is(catalog, view, unit_id, UnitTypes.ABILITY_SPRINT):
		_use_ability(pipeline, unit_id)
		view = FactionView.new(state, Faction.PLAYER)
	var best := start
	var best_distance := _distance(field, start)
	for tile in pipeline.check_move_range(view, Faction.PLAYER, unit_id):
		var distance := _distance(field, tile)
		if distance < best_distance or (distance == best_distance and tile < best and best != start):
			best = tile
			best_distance = distance
	if best != start:
		_submit(pipeline, MoveCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, unit_id, best))


func _objective(state: GameState, view: StateView, unit_id: int, catalog: DataCatalog) -> int:
	var start := view.unit_tile(unit_id)
	var reach := MovementRules.cost_field(view, start, catalog, false)
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
		var distance := _distance(reach, tile)
		if distance > 0 and distance < UNREACHABLE and (best < 0 or distance < best_distance):
			best = tile
			best_distance = distance
	return best if best >= 0 else AiPlanner.nearest_unknown(state, Faction.PLAYER, reach)


const UNREACHABLE := 9999


static func _distance(field: PackedInt32Array, tile: int) -> int:
	return field[tile] if field[tile] != MovementRules.UNREACHED else UNREACHABLE


## What a unit does when it has neither captured nor struck: Repair when it or a neighbour has
## lost at least the repair amount, Hold when an enemy is two tiles away or closer.
func _last_resort(state: GameState, pipeline: CommandPipeline, catalog: DataCatalog, unit_id: int) -> void:
	var view := FactionView.new(state, Faction.PLAYER)
	if view.unit_tile(unit_id) < 0 or view.unit_acted(unit_id):
		return
	var tile := view.unit_tile(unit_id)
	if _ability_is(catalog, view, unit_id, UnitTypes.ABILITY_REPAIR):
		for other in view.unit_ids():
			if view.unit_faction(other) == Faction.PLAYER and not view.unit_asleep(other) \
					and CombatRules.distance(view.width(), tile, view.unit_tile(other)) <= 1 \
					and catalog.units.hp(view.unit_type(other)) - view.unit_hp(other) >= catalog.units.repair_amount():
				_use_ability(pipeline, unit_id)
				return
	if _ability_is(catalog, view, unit_id, UnitTypes.ABILITY_HOLD):
		for other in view.unit_ids():
			if view.unit_faction(other) == Faction.AI and not view.unit_asleep(other) \
					and CombatRules.distance(view.width(), tile, view.unit_tile(other)) <= 2:
				_use_ability(pipeline, unit_id)
				return


func _ability_is(catalog: DataCatalog, view: StateView, unit_id: int, ability: int) -> bool:
	return use_abilities and catalog.units.ability(view.unit_type(unit_id)) == ability and view.unit_cooldown(unit_id) == 0


func _use_ability(pipeline: CommandPipeline, unit_id: int) -> void:
	if _submit(pipeline, AbilityCommand.new(Faction.PLAYER, Command.EMITTER_PLAYER, unit_id)):
		abilities_used += 1


func _submit(pipeline: CommandPipeline, command: Command) -> bool:
	var result := pipeline.submit(command)
	if result.permitted:
		commands += 1
	return result.permitted
