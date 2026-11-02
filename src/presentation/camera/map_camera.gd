# The map camera (ADR-0010 §3), pure, with no Camera2D: the centre (in tiles), the zoom (the
# size of a tile on screen) and the rectangle of the map area. It yields the TileLayout the
# renderer and the taps share, scrolls and zooms with the rules of the GDD 4 (the map keeps
# EDGE_MARGIN_TILES of margin and never leaves the area empty, the zoom anchors on the point
# under the fingers), brings a tile into view by the smallest shift, and recentres with an
# interpolation timed on the presentation clock. It is neither state nor saved.
class_name MapCamera
extends RefCounted

const MIN_TILE := 24.0
const MAX_TILE := 64.0
const EDGE_MARGIN_TILES := 1.0
## GDD 4: 8 columns visible in portrait at the default zoom.
const DEFAULT_COLUMNS := 8.0

var columns: int
var rows: int
var area: Rect2
var tile_size: float
## The tile, as a point, at the middle of the area (a tile (x, y) has its centre at x + 0.5, y + 0.5).
var center: Vector2
## True after a change the renderer has not drawn yet.
var dirty := true

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _start := 0.0
var _duration := 0.0
var _animating := false
var _remembered_center := Vector2.ZERO
var _remembered_size := 0.0


func _init(p_columns: int, p_rows: int, p_area: Rect2) -> void:
	columns = p_columns
	rows = p_rows
	area = p_area
	tile_size = clampf(floorf(p_area.size.x / DEFAULT_COLUMNS), MIN_TILE, MAX_TILE)
	center = Vector2(p_columns, p_rows) / 2.0
	_clamp()


func layout() -> TileLayout:
	return TileLayout.new(columns, rows, tile_size, area.get_center() - center * tile_size)


func tile_to_screen(tile: int) -> Vector2:
	return layout().center_of(tile)


func screen_to_tile(point: Vector2) -> int:
	return layout().tile_at(point)


## The finger drags the map: it follows by `delta` pixels.
func scroll(delta: Vector2) -> void:
	_animating = false
	center -= delta / tile_size
	_clamp()
	dirty = true


## Pinch: the zoom changes by `factor`, the point under `anchor` stays under it.
func zoom(factor: float, anchor: Vector2) -> void:
	_animating = false
	var anchored := (anchor - layout().origin) / tile_size
	tile_size = clampf(tile_size * factor, MIN_TILE, MAX_TILE)
	center = anchored - (anchor - area.get_center()) / tile_size
	_clamp()
	dirty = true


func can_zoom_in() -> bool:
	return tile_size < MAX_TILE


func can_zoom_out() -> bool:
	return tile_size > MIN_TILE


## The smallest shift that brings `tile` fully into the area, with `margin_tiles` around it.
func ensure_visible(tile: int, margin_tiles: float = 1.0) -> void:
	var at := Vector2(tile % columns, tile / columns) + Vector2(0.5, 0.5)
	var half := area.size / (2.0 * tile_size) - Vector2(margin_tiles, margin_tiles)
	half = Vector2(maxf(half.x, 0.0), maxf(half.y, 0.0))
	center = Vector2(clampf(center.x, at.x - half.x, at.x + half.x), clampf(center.y, at.y - half.y, at.y + half.y))
	_clamp()
	dirty = true


func is_visible(tile: int) -> bool:
	return area.encloses(layout().rect_of(tile))


## An animated recentre on a tile (a ruin being read); an instant one when `duration` is 0.
func start_recenter(tile: int, now: float, duration: float) -> void:
	var target := Vector2(tile % columns, tile / columns) + Vector2(0.5, 0.5)
	if duration <= 0.0:
		center = target
		_animating = false
		_clamp()
	else:
		_from = center
		_to = target
		_start = now
		_duration = duration
		_animating = true
	dirty = true


## Moves an animated recentre along; true while the camera is still moving.
func tick(now: float) -> bool:
	if not _animating:
		return false
	var p := clampf((now - _start) / _duration, 0.0, 1.0)
	center = _from.lerp(_to, p * p * (3.0 - 2.0 * p))  # smoothstep
	_clamp()
	dirty = true
	if p >= 1.0:
		_animating = false
	return _animating


## Remembered at FINIR_LE_TOUR, given back at the start of the player's turn (ADR-0010 §3).
func remember() -> void:
	_remembered_center = center
	_remembered_size = tile_size


func restore() -> void:
	if _remembered_size > 0.0:
		center = _remembered_center
		tile_size = _remembered_size
		_animating = false
		_clamp()
		dirty = true


func set_area(p_area: Rect2) -> void:
	area = p_area
	_clamp()
	dirty = true


## The map keeps its edge margin; a map smaller than the area stays centred on that axis.
func _clamp() -> void:
	var half := area.size / (2.0 * tile_size)
	center.x = _clamp_axis(center.x, half.x, columns)
	center.y = _clamp_axis(center.y, half.y, rows)


static func _clamp_axis(value: float, half: float, extent: int) -> float:
	var low := half - EDGE_MARGIN_TILES
	var high := extent - half + EDGE_MARGIN_TILES
	return extent / 2.0 if low > high else clampf(value, low, high)
