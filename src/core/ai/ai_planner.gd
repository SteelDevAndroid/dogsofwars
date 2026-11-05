# AI planner (GDD 9, ADR-0005): a pure function of a frozen state (the AI's filtered
# copy), the data and a budget. No hidden information, no clock, no draw, no write on
# the frozen state. It returns the next ordinary command (DÉPLACER, then MONTER_NŒUD)
# or null when nothing is left, and the announcement of the end of the phase.
#
# Order (rule 10): capturers (the Bastion) first, then the armed movers (Chasseurs),
# then the rest, by ascending id; `curseur_ia` skips the units already planned in a
# resumed phase. Each unit scores its reachable tiles with F1 (the K_DEST nearest to its
# objective plus staying) and moves only when the best beats staying by `state_margin`
# (anti-oscillation). Ties: score, then unit id, then tile index (rule 14).
# MVP subset (ADR-0005 §4): no tracks in the exposure, no raid term, no covered dormant
# veto, hard budget cap.
class_name AiPlanner
extends RefCounted

const RANK_CAPTURER := 0
const RANK_HUNTER := 1
const RANK_OTHER := 2
## Copies of one enemy phase at most (formula 5 of GDD 1, ADR-0005 §4).
const COPIES_PER_TURN_MAX := 2500


## Upper bound on the plan_next calls of one enemy phase (ADR-0005 §4), structural at the
## MVP: a call returns at most one command per AI unit (one MOVE, then "has moved"; a refused
## unit is skipped) and per node (one upgrade a turn), a refused upgrade ends the moves, and
## the last call returns null. Each call perceives once; the announcement adds one copy.
static func max_calls_per_turn(ai_units: int, nodes: int) -> int:
	return ai_units + nodes + 2


## The next ordinary command of the phase, or null. `skipped`: units whose command was
## refused this phase.
func plan_next(frozen: GameState, catalog: DataCatalog, budget: AiBudget, skipped: PackedInt32Array = PackedInt32Array()) -> Command:
	var view := frozen.view()
	if frozen.header.value(HeaderSlice.AI_PASSIVE) == 1:
		return null
	if frozen.turn() < frozen.header.value(HeaderSlice.T_MAX):
		var cursor := frozen.ai_cursor.cursor()
		var cursor_key := _order_key(view, cursor, catalog) if cursor > 0 and view.unit_tile(cursor) >= 0 else -1
		for unit_id in _planning_order(view, catalog):
			if skipped.has(unit_id) or _order_key(view, unit_id, catalog) < cursor_key:
				continue
			var move := _best_move(frozen, unit_id, catalog, budget)
			if move != null:
				return move
	return _best_upgrade(frozen, catalog)


## ANNONCER_LES_INTENTIONS for the end of the phase, on the final positions; null at
## turn T_MAX, against a passive AI, or when the AI fields no unit.
func plan_announcement(frozen: GameState, catalog: DataCatalog) -> Command:
	var view := frozen.view()
	if frozen.turn() >= frozen.header.value(HeaderSlice.T_MAX) or frozen.header.value(HeaderSlice.AI_PASSIVE) == 1:
		return null
	var params := catalog.ai
	var intentions := PackedInt64Array()
	var agents := PackedInt64Array()
	var siege_node := -1
	var siege_count := 0
	var player_nodes := 0
	for node_id in view.node_ids():
		if view.node_owner(node_id) == Faction.PLAYER:
			player_nodes += 1
	var ids := _ai_units(view)
	ids.sort()
	for unit_id in ids:
		var tile := view.unit_tile(unit_id)
		var role := AiAgentsSlice.ROLE_IMMOBILE
		var motive := AiAgentsSlice.NO_MOTIVE
		var idle := 0
		var row := frozen.ai_agents.find_row(unit_id)
		var post := frozen.ai_agents.post_tile_of(row) if row >= 0 and frozen.ai_agents.post_tile_of(row) >= 0 else tile
		var previous_role := frozen.ai_agents.role_of(row) if row >= 0 else AiAgentsSlice.ROLE_POST
		var previous_idle := frozen.ai_agents.idle_turns_of(row) if row >= 0 else 0
		match _rank(view, unit_id, catalog):
			RANK_CAPTURER:
				role = AiAgentsSlice.ROLE_CAPTURE
				var node_id := view.node_at(tile)
				if node_id >= 0 and view.node_owner(node_id) != Faction.AI:
					var last := view.node_owner(node_id) == Faction.PLAYER and player_nodes == 1
					var step := 2 if view.siege_node() == node_id and view.siege_count() == 1 else 1
					if not last or (siege_node < 0 and (step == 2 or frozen.turn() < frozen.header.value(HeaderSlice.T_MAX) - 1)):
						intentions.append_array(PackedInt64Array([unit_id, IntentionsSlice.TARGET_NODE, node_id,
								IntentionsSlice.ACTION_CAPTURE, IntentionsSlice.MOTIVE_CAPTURE]))
						motive = IntentionsSlice.MOTIVE_CAPTURE
						if last:
							siege_node = node_id
							siege_count = step
				elif node_id >= 0:
					role = AiAgentsSlice.ROLE_HOLD
					var target := _best_target(view, unit_id, tile, catalog)
					if target[0] >= 0 and target[1] > 0:
						intentions.append_array(PackedInt64Array([unit_id, IntentionsSlice.TARGET_UNIT, target[0],
								IntentionsSlice.ACTION_ATTACK, IntentionsSlice.MOTIVE_DEFENSE]))
						role = AiAgentsSlice.ROLE_RIPOSTE
						motive = IntentionsSlice.MOTIVE_DEFENSE
			RANK_HUNTER:
				var target := _best_target(view, unit_id, tile, catalog)
				if target[0] >= 0 and target[1] > 0:
					intentions.append_array(PackedInt64Array([unit_id, IntentionsSlice.TARGET_UNIT, target[0],
							IntentionsSlice.ACTION_ATTACK, IntentionsSlice.MOTIVE_HUNT]))
					motive = IntentionsSlice.MOTIVE_HUNT
				var sees_player := _nearest_player_unit(view, tile) >= 0
				if sees_player:
					role = AiAgentsSlice.ROLE_HUNT
				elif previous_role == AiAgentsSlice.ROLE_HUNT:
					idle = previous_idle + 1
					role = AiAgentsSlice.ROLE_RETURN if idle >= params.planner("return_after") else AiAgentsSlice.ROLE_HUNT
				elif previous_role == AiAgentsSlice.ROLE_RETURN and tile != post:
					role = AiAgentsSlice.ROLE_RETURN
				else:
					role = AiAgentsSlice.ROLE_POST
				if role == AiAgentsSlice.ROLE_RETURN:
					idle = 0
		agents.append_array(PackedInt64Array([unit_id, role, idle, post, motive]))
	if agents.is_empty():
		return null
	return AnnounceIntentionsCommand.new(siege_node, siege_count, intentions, agents)


# ---------------------------------------------------------------------------- order

## 0 capturer, 1 armed mover, 2 other (data-driven: no unit type is named).
func _rank(view: StateView, unit_id: int, catalog: DataCatalog) -> int:
	var type := view.unit_type(unit_id)
	if catalog.units.can_capture(type):
		return RANK_CAPTURER
	if ProtocolEffects.unit_stat(view, Faction.AI, type, ProtocolEffects.ATTACK, catalog) > 0 \
			and ProtocolEffects.unit_stat(view, Faction.AI, type, ProtocolEffects.MOVE, catalog) > 0:
		return RANK_HUNTER
	return RANK_OTHER


func _order_key(view: StateView, unit_id: int, catalog: DataCatalog) -> int:
	return _rank(view, unit_id, catalog) * GameState.ID_MAX + unit_id


func _ai_units(view: StateView) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for unit_id in view.unit_ids():
		if view.unit_faction(unit_id) == Faction.AI and not view.unit_asleep(unit_id):
			ids.append(unit_id)
	return ids


func _planning_order(view: StateView, catalog: DataCatalog) -> PackedInt32Array:
	var ids := Array(_ai_units(view))
	ids.sort_custom(func(a: int, b: int) -> bool: return _order_key(view, a, catalog) < _order_key(view, b, catalog))
	return PackedInt32Array(ids)


# ---------------------------------------------------------------------------- moves

func _best_move(frozen: GameState, unit_id: int, catalog: DataCatalog, budget: AiBudget) -> Command:
	var view := frozen.view()
	var type := view.unit_type(unit_id)
	if view.unit_moved(unit_id) or view.unit_acted(unit_id) \
			or ProtocolEffects.unit_stat(view, Faction.AI, type, ProtocolEffects.MOVE, catalog) == 0:
		return null
	var start := view.unit_tile(unit_id)
	var objective := _objective(frozen, unit_id, catalog)
	if objective < 0:
		return null
	# The path cost to the objective, not the straight distance: a canyon or a ridge between the
	# unit and its objective would otherwise hold it against the obstacle.
	var field := MovementRules.cost_field(view, objective, catalog, true)
	var candidates := Array(MovementRules.move_range(view, unit_id, catalog))
	candidates.sort_custom(func(a: int, b: int) -> bool:
		var da := _path_distance(field, a)
		var db := _path_distance(field, b)
		return da < db or (da == db and a < b))
	candidates = candidates.slice(0, catalog.ai.planner("k_dest"))
	var stay_score := _score(frozen, unit_id, start, start, objective, catalog, field)
	var best_tile := start
	var best_score := stay_score
	for tile: int in candidates:
		if not budget.spend():
			break
		var score := _score(frozen, unit_id, tile, start, objective, catalog, field)
		if score > best_score or (score == best_score and best_tile != start and tile < best_tile):
			best_score = score
			best_tile = tile
	if best_tile == start or best_score < stay_score + catalog.ai.planner("state_margin"):
		return null
	return MoveCommand.new(Faction.AI, Command.EMITTER_AI, unit_id, best_tile)


## The tile `faction` has never seen with the lowest path cost in `reach` (lowest index on a tie),
## or -1 when every reachable tile is known. Its own filtered copy is enough: nothing hidden is read.
static func nearest_unknown(state: GameState, faction: int, reach: PackedInt32Array) -> int:
	var discovered := VisionService.discovered_row(state, faction)
	var best := -1
	for tile in reach.size():
		if reach[tile] <= 0 or discovered[tile] == 1:
			continue
		if best < 0 or reach[tile] < reach[best]:
			best = tile
	return best


## Path cost from a cost field, a large number where the tile has no path (it never wins).
static func _path_distance(field: PackedInt32Array, tile: int) -> int:
	return field[tile] if field[tile] != MovementRules.UNREACHED else 9999


## Where the unit wants to be: a capturer heads for the nearest node not held by the AI (by path), an
## armed mover for the nearest visible player unit it can engage, else for its post.
func _objective(frozen: GameState, unit_id: int, catalog: DataCatalog) -> int:
	var view := frozen.view()
	var start := view.unit_tile(unit_id)
	var width := view.width()
	var type := view.unit_type(unit_id)
	if catalog.units.can_capture(type):
		var reach := MovementRules.cost_field(view, start, catalog, false)
		var best := -1
		var best_distance := 0
		for node_id in view.node_ids():
			if view.node_owner(node_id) == Faction.AI:
				continue
			var distance := _path_distance(reach, view.node_tile(node_id))
			if best < 0 or distance < best_distance:
				best = view.node_tile(node_id)
				best_distance = distance
		# No node known yet (all in the fog): explore toward the nearest tile the AI has never seen.
		return best if best >= 0 else nearest_unknown(frozen, Faction.AI, reach)
	var row := frozen.ai_agents.find_row(unit_id)
	var post := frozen.ai_agents.post_tile_of(row) if row >= 0 and frozen.ai_agents.post_tile_of(row) >= 0 else start
	var returning := row >= 0 and frozen.ai_agents.role_of(row) == AiAgentsSlice.ROLE_RETURN
	var engage := ProtocolEffects.unit_stat(view, Faction.AI, type, ProtocolEffects.MOVE, catalog) \
			+ catalog.units.attack_range(type) + catalog.ai.planner("leash")
	var target := _nearest_player_unit(view, start)
	if not returning and target >= 0 and CombatRules.distance(width, start, view.unit_tile(target)) <= engage:
		return view.unit_tile(target)
	return post


## F1 of a tile for a unit (GDD 9): the best strike from there, minus the exposure, plus
## the node value, minus the leash excess, plus the progress toward the objective.
func _score(frozen: GameState, unit_id: int, tile: int, start: int, objective: int, catalog: DataCatalog,
		field: PackedInt32Array = PackedInt32Array()) -> int:
	var view := frozen.view()
	var params := catalog.ai
	var width := view.width()
	var type := view.unit_type(unit_id)
	var total := maxi(0, _best_target(view, unit_id, tile, catalog)[1])
	total -= params.planner("w_danger") * _exposure(view, unit_id, tile, catalog)
	var node_id := view.node_at(tile)
	if node_id >= 0 and view.node_owner(node_id) != Faction.AI and catalog.units.can_capture(type):
		total += params.planner("w_node") * view.node_level(node_id)
	var row := frozen.ai_agents.find_row(unit_id)
	if row >= 0 and frozen.ai_agents.post_tile_of(row) >= 0 and not catalog.units.can_capture(type):
		var excess := CombatRules.distance(width, tile, frozen.ai_agents.post_tile_of(row)) - params.planner("leash")
		total -= params.planner("w_leash") * maxi(0, excess)
	if field.is_empty():
		field = MovementRules.cost_field(view, objective, catalog, true)
	total += params.planner("w_progress") * (_path_distance(field, start) - _path_distance(field, tile))
	return total


## [target id, F1 attack score] of the best strike from `tile` on a visible awake player
## unit within range: w_dmg x damage + w_lethal x lethal - w_loss x riposte. [-1, 0] when
## none. Ties: lower target id.
func _best_target(view: StateView, unit_id: int, tile: int, catalog: DataCatalog) -> Array:
	var type := view.unit_type(unit_id)
	var attack := ProtocolEffects.unit_stat(view, Faction.AI, type, ProtocolEffects.ATTACK, catalog)
	if attack == 0:
		return [-1, 0]
	var params := catalog.ai
	var combat := catalog.combat
	var reach := catalog.units.attack_range(type)
	var best := [-1, 0]
	for target_id in view.unit_ids():
		if view.unit_faction(target_id) != Faction.PLAYER or view.unit_asleep(target_id):
			continue
		var target_tile := view.unit_tile(target_id)
		if CombatRules.distance(view.width(), tile, target_tile) > reach:
			continue
		var hp := view.unit_hp(target_id)
		var dealt := CombatRules.damage_of(attack, view.unit_hp(unit_id), catalog.units.hp(type),
				CombatRules.defense_effective(view, target_id, catalog), combat)
		var lethal := dealt >= hp
		var riposte := 0
		if not lethal and CombatRules.distance(view.width(), tile, target_tile) <= catalog.units.attack_range(view.unit_type(target_id)):
			var target_type := view.unit_type(target_id)
			riposte = CombatRules.damage_of(
					ProtocolEffects.unit_stat(view, Faction.PLAYER, target_type, ProtocolEffects.ATTACK, catalog),
					hp - dealt, catalog.units.hp(target_type),
					CombatRules.defense_on(view, Faction.AI, type, tile, catalog), combat)
		var score: int = params.planner("w_damage") * mini(dealt, hp) + (params.planner("w_lethal") if lethal else 0) \
				- params.planner("w_loss") * riposte
		if best[0] < 0 or score > best[1]:
			best = [target_id, score]
	return best


## Potential damage of the visible player units that can reach `tile` next turn.
func _exposure(view: StateView, unit_id: int, tile: int, catalog: DataCatalog) -> int:
	var type := view.unit_type(unit_id)
	var total := 0
	for other in view.unit_ids():
		if view.unit_faction(other) != Faction.PLAYER or view.unit_asleep(other):
			continue
		var other_type := view.unit_type(other)
		var reach := ProtocolEffects.unit_stat(view, Faction.PLAYER, other_type, ProtocolEffects.MOVE, catalog) \
				+ catalog.units.attack_range(other_type)
		if CombatRules.distance(view.width(), view.unit_tile(other), tile) > reach:
			continue
		total += CombatRules.damage_of(ProtocolEffects.unit_stat(view, Faction.PLAYER, other_type, ProtocolEffects.ATTACK, catalog),
				view.unit_hp(other), catalog.units.hp(other_type), CombatRules.defense_on(view, Faction.AI, type, tile, catalog), catalog.combat)
	return total


func _nearest_player_unit(view: StateView, tile: int) -> int:
	var best := -1
	var best_distance := 0
	for unit_id in view.unit_ids():
		if view.unit_faction(unit_id) != Faction.PLAYER or view.unit_asleep(unit_id):
			continue
		var distance := CombatRules.distance(view.width(), tile, view.unit_tile(unit_id))
		if best < 0 or distance < best_distance:
			best = unit_id
			best_distance = distance
	return best


# ---------------------------------------------------------------------------- nodes

## Rule 17: the affordable upgrade with the best income gain per energy spent, then the
## lowest node id. Cross-multiplied: no division.
func _best_upgrade(frozen: GameState, catalog: DataCatalog) -> Command:
	var view := frozen.view()
	var best := -1
	var best_gain := 0
	var best_price := 1
	for node_id in view.node_ids():
		if view.node_owner(node_id) != Faction.AI or view.node_since_turn(node_id) >= view.turn() \
				or view.node_upgraded_turn(node_id) == view.turn():
			continue
		var level := view.node_level(node_id)
		if level >= catalog.nodes.max_level():
			continue
		var price := catalog.nodes.upgrade_price(level)
		if view.energy(Faction.AI) < price:
			continue
		var gain := catalog.energy.income(level + 1) - catalog.energy.income(level)
		if best < 0 or gain * best_price > best_gain * price:
			best = node_id
			best_gain = gain
			best_price = price
	return null if best < 0 else UpgradeNodeCommand.new(Faction.AI, Command.EMITTER_AI, best)
