# Precomputed fields of view (GDD 5 rule 10, ADR-0007 §3): for a (source tile,
# effective radius) pair, the tiles seen from it on the REAL terrain, ascending.
# Built lazily on the main thread from the real state only (simulations never
# recompute the view, ADR-0007 §8), then shared read-only.
class_name FieldTable
extends RefCounted

var _terrain: TerrainGrid
var _width: int
var _height: int
var _max_radius: int
var _fields: Array[PackedInt32Array] = []
var _built := PackedByteArray()


func _init(terrain: TerrainGrid, map_width: int, map_height: int, max_radius: int) -> void:
	_terrain = terrain
	_width = map_width
	_height = map_height
	_max_radius = max_radius
	var pairs := map_width * map_height * (max_radius + 1)
	_fields.resize(pairs)
	_built.resize(pairs)


func max_radius() -> int:
	return _max_radius


## Tiles at Chebyshev distance <= radius and not blocked (GDD 2 formula 3), ascending.
func field(source_tile: int, effective_radius: int) -> PackedInt32Array:
	assert(effective_radius >= 0 and effective_radius <= _max_radius, "radius outside the table")
	var k := source_tile * (_max_radius + 1) + effective_radius
	if _built[k] == 0:
		_fields[k] = _compute(source_tile, effective_radius)
		_built[k] = 1
	return _fields[k]


## GDD 2 formula 3: no mountain strictly between source and target on the Bresenham
## line, unless the source stands on a mountain. A neighbour is never hidden.
func blocked(source_tile: int, target_tile: int) -> bool:
	if _terrain.is_mountain(source_tile):
		return false
	var x0 := source_tile % _width
	var y0 := source_tile / _width
	var x1 := target_tile % _width
	var y1 := target_tile / _width
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := signi(x1 - x0)
	var sy := signi(y1 - y0)
	var x_major := dx >= dy
	var major := dx if x_major else dy
	var minor := dy if x_major else dx
	var d := 2 * minor - major
	var x := x0
	var y := y0
	for step in major:
		if step > 0 and _terrain.is_mountain(y * _width + x):
			return true
		if d > 0:
			if x_major:
				y += sy
			else:
				x += sx
			d -= 2 * major
		d += 2 * minor
		if x_major:
			x += sx
		else:
			y += sy
	return false


func _compute(source_tile: int, radius: int) -> PackedInt32Array:
	var tiles := PackedInt32Array()
	var sx := source_tile % _width
	var sy := source_tile / _width
	for y in range(maxi(0, sy - radius), mini(_height - 1, sy + radius) + 1):
		for x in range(maxi(0, sx - radius), mini(_width - 1, sx + radius) + 1):
			var tile := y * _width + x
			if not blocked(source_tile, tile):
				tiles.append(tile)
	return tiles
