# Where the tiles are on screen (GDD 2, ADR-0010): square tiles of one size from an origin.
# Pure geometry, no node; the renderer and the input surface share one layout.
class_name TileLayout
extends RefCounted

var columns := 1
var rows := 1
var tile_size := 32.0
var origin := Vector2.ZERO


func _init(p_columns: int = 1, p_rows: int = 1, p_tile_size: float = 32.0, p_origin: Vector2 = Vector2.ZERO) -> void:
	columns = p_columns
	rows = p_rows
	tile_size = p_tile_size
	origin = p_origin


## The largest tile that fits the whole map in `area` (a Rect2), centred in it.
static func fitting(p_columns: int, p_rows: int, area: Rect2) -> TileLayout:
	var size := floorf(minf(area.size.x / p_columns, area.size.y / p_rows))
	size = maxf(size, 1.0)
	var map_size := Vector2(p_columns, p_rows) * size
	return TileLayout.new(p_columns, p_rows, size, area.position + (area.size - map_size) / 2.0)


func rect_of(tile: int) -> Rect2:
	return Rect2(origin + Vector2(tile % columns, tile / columns) * tile_size, Vector2(tile_size, tile_size))


func center_of(tile: int) -> Vector2:
	return rect_of(tile).get_center()


## The tile under a point, -1 outside the map.
func tile_at(point: Vector2) -> int:
	var local := (point - origin) / tile_size
	var x := int(floorf(local.x))
	var y := int(floorf(local.y))
	if local.x < 0.0 or local.y < 0.0 or x >= columns or y >= rows:
		return -1
	return y * columns + x
