# The relief of a map in miniature, for the map choice screen (art bible 6, "Illustrations et
# carte": a presentation shows the reliefs and the masses of water, never the nodes, the ruins
# or the starts). One square per tile in the greys of the world; the terrain also has a mark,
# so the colour is never the only signal: a dot for the forest, a triangle for the mountain, a
# dash for the water.
class_name MapThumbnail
extends Control

const PLAIN := Color("5B6670")
const FOREST := Color("46525C")
const MOUNTAIN := Color("98A2AC")
const WATER := Color("26394A")
const MARK := Color("1E2329")

var _map: MapDefinition


func show_map(map: MapDefinition) -> void:
	_map = map
	queue_redraw()


## The side of a tile, in points, so the whole map fits `size`.
func cell_size() -> float:
	if _map == null:
		return 0.0
	return floorf(minf(size.x / _map.width, size.y / _map.height))


func _draw() -> void:
	if _map == null:
		return
	var cell := cell_size()
	if cell <= 0.0:
		return
	var origin := (size - Vector2(_map.width, _map.height) * cell) / 2.0
	for tile in _map.width * _map.height:
		var rect := Rect2(origin + Vector2(tile % _map.width, tile / _map.width) * cell, Vector2(cell, cell))
		var terrain := _map.terrain_at_tile(tile)
		draw_rect(rect.grow(-0.5), _color_of(terrain))
		_draw_mark(rect, terrain)


static func _color_of(terrain: int) -> Color:
	match terrain:
		TerrainGrid.FOREST:
			return FOREST
		TerrainGrid.MOUNTAIN:
			return MOUNTAIN
		TerrainGrid.WATER:
			return WATER
	return PLAIN


func _draw_mark(rect: Rect2, terrain: int) -> void:
	if rect.size.x < 6.0:
		return  # too small to read a mark
	var c := rect.get_center()
	var s := rect.size.x * 0.22
	match terrain:
		TerrainGrid.FOREST:
			draw_circle(c, s * 0.8, Color(MOUNTAIN, 0.8))
		TerrainGrid.MOUNTAIN:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s, s), c + Vector2(0, -s), c + Vector2(s, s)]), MARK)  # dark on the light peak
		TerrainGrid.WATER:
			draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), Color(MOUNTAIN, 0.7), maxf(1.0, rect.size.x * 0.08))
