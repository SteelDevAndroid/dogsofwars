# Match setup (GDD 1 state CRÉÉE, GDD 2 states MISE EN PLACE, ADR-0008): the new-game
# factory. The only writer outside the commands, together with GameStateSetup. From a
# checked map, a seed and the options it builds the state of turn 0 and draws what the
# file leaves open, with the state's own draw function and in a fixed order: dormant
# types first (dormant after dormant, a mirrored dormant repeating its model, GDD 7 rule 9),
# then the ruins (zone after zone, without replacement, GDD 2 rule 12). The same map, seed
# and options always give the same state; nothing is drawn after the setup.
class_name GameStateFactory
extends RefCounted


## `chronicle`: [faction, fragment id] rows of the profile, copied once (GDD 1 rule 10).
## Returns null when a draw refuses (a map with no candidate, never a valid one).
static func new_game(catalog: DataCatalog, map: MapDefinition, seed_value: int, ai_passive: bool = false,
		chronicle: Array = [], match_id: int = 0, profile_epoch: int = 0) -> GameState:
	var state := GameStateSetup.create(map.width, map.height, 2, seed_value, map.cells, match_id, profile_epoch)
	for faction: int in [Faction.PLAYER, Faction.AI]:
		GameStateSetup.add_node(state, map.start_tile[faction], faction, 1)
	for node: Array in map.nodes:
		GameStateSetup.add_node(state, node[0], Faction.NONE, node[1])
	for unit: Array in map.units:
		var type := catalog.units.type_of_key(unit[0])
		var id := GameStateSetup.add_unit(state, type, unit[1], unit[2], catalog.units.hp(type))
		if unit[1] == Faction.AI:
			AiWrites.set_agent(state, id, _initial_role(type, catalog), 0, unit[3] if unit[3] >= 0 else unit[2], AiAgentsSlice.NO_MOTIVE)
	if not _place_dormants(state, catalog, map) or not _place_ruins(state, map):
		return null
	var rows := chronicle.duplicate()
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for row: Array in rows:
		GameStateSetup.add_chronicle_fragment(state, row[0], row[1])
	EnergyRules.initialize(state, catalog.energy)
	GameStateSetup.set_ai_passive(state, ai_passive)
	TerritoryRules.recompute(state, catalog.nodes, MapSlice.CAUSE_NONE)
	VisionService.setup(state, VisionContext.for_map(catalog, state))
	return state


static func _place_dormants(state: GameState, catalog: DataCatalog, map: MapDefinition) -> bool:
	var types: Array[int] = []
	for k in map.dormants.size():
		var dormant: Array = map.dormants[k]
		var keys: Array = dormant[1]
		var type_key: String
		if dormant[2] >= 0:
			type_key = catalog.units.key(types[dormant[2]])
		elif keys.size() == 1:
			type_key = keys[0]
		else:
			var pick := state.draw(keys.size())
			if pick < 0:
				return false
			type_key = keys[pick]
		var type := catalog.units.type_of_key(type_key)
		types.append(type)
		GameStateSetup.add_unit(state, type, Faction.NONE, dormant[0], catalog.units.hp(type), true)
	return true


static func _place_ruins(state: GameState, map: MapDefinition) -> bool:
	for z in map.ruin_zones.size():
		var left := Array(map.ruin_zones[z][1])
		for k in map.ruin_zones[z][0]:
			var pick := state.draw(left.size())
			if pick < 0:
				return false
			GameStateSetup.add_ruin(state, left[pick], z, map.memory_faction)
			left.remove_at(pick)
	return true


## Starting role of a Guardian (GDD 9 rule 10), from what its type can do: a capturer
## heads for a node, an armed mover keeps a post, the rest never moves.
static func _initial_role(type: int, catalog: DataCatalog) -> int:
	if catalog.units.can_capture(type):
		return AiAgentsSlice.ROLE_CAPTURE
	if catalog.units.attack(type) > 0 and catalog.units.move(type) > 0:
		return AiAgentsSlice.ROLE_POST
	return AiAgentsSlice.ROLE_IMMOBILE
