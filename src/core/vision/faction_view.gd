# The state as one faction sees it, without a copy (ADR-0004 §3): every read goes
# through the VisionService predicates. Validation of real commands reads it; its
# answers equal those of filtered_copy(faction).view() (parity test, ADR-0007 §5).
class_name FactionView
extends StateView

var _faction: int


func _init(state: GameState, faction: int) -> void:
	super(state)
	assert(state.view_cache.valid, "FactionView needs a rebuilt view cache")
	_faction = faction


func faction() -> int:
	return _faction


func terrain_at(tile: int) -> int:
	return VisionService.known_terrain(_state, _faction, tile)


func tile_owner(tile: int) -> int:
	return VisionService.known_tile_owner(_state, _faction, tile)


func tile_anchor(tile: int) -> int:
	return VisionService.known_anchor(_state, _faction, tile)


## Another faction's energy and research are hidden (as in filtered_copy); its
## acquired protocols are kept.
func energy(faction: int) -> int:
	return super(faction) if faction == _faction else 0


func research(faction: int) -> int:
	return super(faction) if faction == _faction else ResearchRules.NONE


func unit_ids() -> PackedInt32Array:
	var ids := PackedInt32Array()
	for unit_id in super():
		if _sees_unit(unit_id):
			ids.append(unit_id)
	return ids


func unit_tile(unit_id: int) -> int:
	return super(unit_id) if _sees_unit(unit_id) else -1


func unit_faction(unit_id: int) -> int:
	return super(unit_id) if _sees_unit(unit_id) else Faction.NONE


func unit_hp(unit_id: int) -> int:
	return super(unit_id) if _sees_unit(unit_id) else 0


func unit_type(unit_id: int) -> int:
	return super(unit_id) if _sees_unit(unit_id) else -1


func unit_moved(unit_id: int) -> bool:
	return super(unit_id) if _sees_unit(unit_id) else false


func unit_acted(unit_id: int) -> bool:
	return super(unit_id) if _sees_unit(unit_id) else false


func node_at(tile: int) -> int:
	var node_id := super(tile)
	return node_id if node_id >= 0 and VisionService.knows_node(_state, _faction, node_id) else -1


func unit_asleep(unit_id: int) -> bool:
	return super(unit_id) if _sees_unit(unit_id) else false


func unit_at(tile: int) -> int:
	var unit_id := super(tile)
	return unit_id if unit_id >= 0 and _sees_unit(unit_id) else -1


func node_ids() -> PackedInt32Array:
	var ids := PackedInt32Array()
	for node_id in super():
		if VisionService.knows_node(_state, _faction, node_id):
			ids.append(node_id)
	return ids


func node_tile(node_id: int) -> int:
	return super(node_id) if VisionService.knows_node(_state, _faction, node_id) else -1


func node_owner(node_id: int) -> int:
	return VisionService.known_node_owner(_state, _faction, node_id)


func node_level(node_id: int) -> int:
	return VisionService.known_node_level(_state, _faction, node_id)


func ruin_ids() -> PackedInt32Array:
	return super() if VisionService.knows_ruins(_faction) else PackedInt32Array()


func ruin_tile(ruin_id: int) -> int:
	return super(ruin_id) if VisionService.knows_ruins(_faction) else -1


func _sees_unit(unit_id: int) -> bool:
	return VisionService.can_see_unit(_state, _state.view_cache, _faction, unit_id)
