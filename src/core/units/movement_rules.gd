# Movement rules (GDD 2 rules 4 to 7 and formula 2, GDD 6 formula 1), pure, on a
# StateView: the faction's view at validation, so a refusal reveals nothing and an
# unknown tile counts as a plain of cost 1 (GDD 5 rule 12).
class_name MovementRules
extends RefCounted

const UNREACHED := -1


## Cheapest cost from the unit's tile to every tile (UNREACHED otherwise), within
## its remaining points; ties broken by the lowest tile index, so the path is the
## same on every device.
class Search:
	var start: int
	var points: int
	var full_points: bool
	var cost := PackedInt32Array()
	var previous := PackedInt32Array()
	## GDD 2 rule 6: passable known terrain...
	var passable := PackedByteArray()
	## ...and no unit the faction sees (a hidden enemy does not block the
	## validation: the ambush, GDD 23 rule 6). No passing through a friend.
	var enterable := PackedByteArray()


## GDD 6 formula 1: 0 once moved, the effective MVT otherwise (GDD 12 rule 11).
static func remaining_points(view: StateView, unit_id: int, catalog: DataCatalog) -> int:
	if view.unit_moved(unit_id):
		return 0
	var type := view.unit_type(unit_id)
	var points := ProtocolEffects.unit_stat(view, view.unit_faction(unit_id), type, ProtocolEffects.MOVE, catalog)
	if view.unit_ability_on(unit_id) and catalog.units.ability(type) == UnitTypes.ABILITY_SPRINT:
		points += catalog.units.sprint_bonus()
	return points


static func search(view: StateView, unit_id: int, catalog: DataCatalog) -> Search:
	var found := Search.new()
	var tiles := view.tile_count()
	found.start = view.unit_tile(unit_id)
	found.points = remaining_points(view, unit_id, catalog)
	found.full_points = not view.unit_moved(unit_id)
	found.passable.resize(tiles)
	for tile in tiles:
		found.passable[tile] = 1 if catalog.terrain.is_passable(view.terrain_at(tile)) else 0
	found.enterable = found.passable.duplicate()
	for other in view.unit_ids():
		found.enterable[view.unit_tile(other)] = 0
	found.cost.resize(tiles)
	found.cost.fill(UNREACHED)
	found.previous.resize(tiles)
	found.previous.fill(-1)
	found.cost[found.start] = 0
	var open := PackedInt32Array([found.start])
	while not open.is_empty():
		var pick := 0
		for k in range(1, open.size()):
			var a := found.cost[open[k]]
			var b := found.cost[open[pick]]
			if a < b or (a == b and open[k] < open[pick]):
				pick = k
		var current := open[pick]
		open.remove_at(pick)
		for next in _neighbours(view, current):
			if found.enterable[next] == 0 or not _step_allowed(view, found, current, next):
				continue
			var cost := found.cost[current] + catalog.terrain.entry_cost(view.terrain_at(next))
			if cost <= found.points and (found.cost[next] == UNREACHED or cost < found.cost[next]):
				if found.cost[next] == UNREACHED:
					open.append(next)
				found.cost[next] = cost
				found.previous[next] = current
	return found


## Refusal code for a destination after the unit checks, or "" when permitted:
## HORS_DE_PORTÉE off the map or too far, CASE_BLOQUÉE on water or a visible unit.
## The guaranteed step (GDD 2 rule 5) lets a unit with all its points enter any
## free passable neighbour.
static func destination_error(view: StateView, found: Search, tile: int) -> StringName:
	if tile < 0 or tile >= view.tile_count():
		return Refusal.OUT_OF_RANGE
	if found.enterable[tile] == 0:
		return Refusal.TILE_BLOCKED
	if found.cost[tile] != UNREACHED or _guaranteed_step(view, found, tile):
		return &""
	return Refusal.OUT_OF_RANGE


## Tiles from the start (excluded) to a permitted destination.
static func path(found: Search, tile: int) -> PackedInt32Array:
	if found.cost[tile] == UNREACHED:
		return PackedInt32Array([tile])
	var steps := PackedInt32Array()
	var at := tile
	while at != found.start:
		steps.append(at)
		at = found.previous[at]
	steps.reverse()
	return steps


## Every destination permitted to the unit, ascending (ADR-0010 §7): the same code
## as the validation, tile by tile.
static func move_range(view: StateView, unit_id: int, catalog: DataCatalog) -> PackedInt32Array:
	var found := search(view, unit_id, catalog)
	var tiles := PackedInt32Array()
	for tile in view.tile_count():
		if destination_error(view, found, tile) == &"":
			tiles.append(tile)
	return tiles


## GDD 2 rule 7: no diagonal between two impassable orthogonal tiles.
static func _step_allowed(view: StateView, found: Search, from_tile: int, to_tile: int) -> bool:
	var w := view.width()
	var fx := from_tile % w
	var fy := from_tile / w
	var tx := to_tile % w
	var ty := to_tile / w
	if fx == tx or fy == ty:
		return true
	return found.passable[fy * w + tx] == 1 or found.passable[ty * w + fx] == 1


static func _guaranteed_step(view: StateView, found: Search, tile: int) -> bool:
	if not found.full_points or found.points < 1:
		return false
	return _neighbours(view, found.start).has(tile) and _step_allowed(view, found, found.start, tile)


## The eight neighbours inside the map, ascending.
static func _neighbours(view: StateView, tile: int) -> PackedInt32Array:
	var w := view.width()
	var x := tile % w
	var y := tile / w
	var out := PackedInt32Array()
	for ny in range(maxi(0, y - 1), mini(view.height() - 1, y + 1) + 1):
		for nx in range(maxi(0, x - 1), mini(w - 1, x + 1) + 1):
			if nx != x or ny != y:
				out.append(ny * w + nx)
	return out


## Path cost between `origin` and every tile on the terrain `view` knows (GDD 2: entry costs, no
## water, no diagonal between two impassable orthogonal tiles), units ignored. `toward` false: the
## cost of walking from `origin` to the tile; true: from the tile to `origin` (what a unit heading
## for `origin` still has to pay). UNREACHED where there is no path. Dial's buckets (costs are
## small integers): linear in the tiles, the same order on every device.
static func cost_field(view: StateView, origin: int, catalog: DataCatalog, toward: bool) -> PackedInt32Array:
	var tiles := view.tile_count()
	var entry := PackedInt32Array()
	entry.resize(tiles)
	for tile in tiles:
		entry[tile] = catalog.terrain.entry_cost(view.terrain_at(tile))
	var cost := PackedInt32Array()
	cost.resize(tiles)
	cost.fill(UNREACHED)
	if origin < 0 or origin >= tiles or entry[origin] == TerrainParams.IMPASSABLE:
		return cost
	var w := view.width()
	var h := view.height()
	var buckets: Array[PackedInt32Array] = [PackedInt32Array([origin])]
	cost[origin] = 0
	var level := 0
	while level < buckets.size():
		var bucket := buckets[level]
		var k := 0
		while k < bucket.size():
			var current := bucket[k]
			k += 1
			if cost[current] != level:
				continue
			var cx := current % w
			var cy := current / w
			for ny in range(maxi(0, cy - 1), mini(h - 1, cy + 1) + 1):
				for nx in range(maxi(0, cx - 1), mini(w - 1, cx + 1) + 1):
					var next := ny * w + nx
					if next == current or entry[next] == TerrainParams.IMPASSABLE:
						continue
					if nx != cx and ny != cy and entry[cy * w + nx] == TerrainParams.IMPASSABLE \
							and entry[ny * w + cx] == TerrainParams.IMPASSABLE:
						continue
					var total := level + (entry[current] if toward else entry[next])
					if cost[next] == UNREACHED or total < cost[next]:
						cost[next] = total
						while buckets.size() <= total:
							buckets.append(PackedInt32Array())
						buckets[total].append(next)
		level += 1
	return cost
