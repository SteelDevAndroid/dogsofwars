# Draws the map (GDD 2, GDD 5, art bible) from a TileSnapshot: terrain, fog, ownership with
# a pattern, nodes with their level, ruins, units with a shape per type and an outline per
# side, HP bars, the selection and its move range, and the threat markers of announced
# intentions. Process priority 10 (ADR-0002): after the sequencer's time sources.
class_name TileRenderer
extends Node2D

var snapshot: TileSnapshot
var layout := TileLayout.new()
var selected_tile := -1
var highlighted: PackedInt32Array = PackedInt32Array()
## The presentation clock the effects are timed on; null in a still image.
var clock: ClockSource
var effects: Array[TileEffect] = []
## Tiles of the units the selected one may strike, and the one chosen.
## The map shows inside this rectangle only (the engine clip is not relied on: tiles are cut here).
var clip_area := Rect2(-1e6, -1e6, 2e6, 2e6)
var targets := PackedInt32Array()
var chosen_target := -1
## The colour-blind palette of hud.md 10.5 (ownership colours only).
var colorblind := false

const GRAIN := 0.03
const SIDE_LEFT := 1
const SIDE_RIGHT := 2
const SIDE_UP := 4
const SIDE_DOWN := 8
const FOG_EDGE_DEPTH := 0.45
const FOG_EDGE_ALPHA := 0.7


func _init() -> void:
	process_priority = 10


func show_state(state: GameState, catalog: DataCatalog) -> void:
	snapshot = TileSnapshot.take(state, catalog)
	queue_redraw()


func add_effect(effect: TileEffect) -> void:
	effects.append(effect)
	queue_redraw()


## The map shows inside this rectangle only: scrolled tiles never cover the HUD bars. The cut is
## made here, in the drawing, not by the engine's canvas clip (which left stray tiles outside).
func set_clip_rect(rect: Rect2) -> void:
	clip_area = rect
	queue_redraw()


func set_targets(tiles: PackedInt32Array, chosen: int) -> void:
	targets = tiles
	chosen_target = chosen
	queue_redraw()


func clear_effects() -> void:
	effects.clear()
	queue_redraw()


func _process(_delta: float) -> void:
	if effects.is_empty() or clock == null:
		return
	var now := clock.current()
	effects = effects.filter(func(effect: TileEffect) -> bool: return not effect.is_over(now))
	queue_redraw()


func set_selection(tile: int, reachable: PackedInt32Array) -> void:
	selected_tile = tile
	highlighted = reachable
	queue_redraw()


func fit(area: Rect2) -> void:
	if snapshot != null:
		layout = TileLayout.fitting(snapshot.columns, snapshot.rows, area)
		queue_redraw()


func _draw() -> void:
	if snapshot == null:
		return
	for tile in visible_tiles():
		_draw_tile(tile)
	for node: Array in snapshot.nodes:
		_draw_node(node)
	for ruin: Array in snapshot.ruins:
		_draw_ruin(ruin)
	for unit: Array in snapshot.units:
		if snapshot.fog_at(unit[1]) == VisionService.FOG_VISIBLE or unit[2] == Faction.PLAYER:
			_draw_unit(unit)
	for threat: Array in snapshot.threats:
		_draw_threat(threat)
	for effect in effects:
		_draw_effect(effect)
	for tile in targets:
		if _inside(tile):
			_draw_brackets(tile, TilePalette.THREAT, 3.0 if tile == chosen_target else 2.0)
	for tile in highlighted:
		var shown := layout.rect_of(tile).grow(-2.0).intersection(clip_area)
		if shown.size.x > 0.0 and shown.size.y > 0.0:
			draw_rect(shown, Color(TilePalette.SELECTION, 0.35))
	if selected_tile >= 0 and _inside(selected_tile):
		draw_rect(layout.rect_of(selected_tile), TilePalette.SELECTION, false, 2.0)


## The tiles that show, at least in part, inside the map area.
func visible_tiles() -> PackedInt32Array:
	var shown := PackedInt32Array()
	if snapshot == null:
		return shown
	for tile in snapshot.columns * snapshot.rows:
		if layout.rect_of(tile).intersects(clip_area):
			shown.append(tile)
	return shown


func _draw_tile(tile: int) -> void:
	var rect := layout.rect_of(tile).intersection(clip_area)
	var level := snapshot.fog_at(tile)
	if level == VisionService.FOG_UNDISCOVERED:
		draw_rect(rect, TilePalette.FOG)
		return
	var color := TilePalette.terrain(snapshot.terrain[tile])
	color = color.lightened(grain(tile)) if grain(tile) >= 0.0 else color.darkened(-grain(tile))
	if level == VisionService.FOG_EXPLORED:
		color = color.darkened(1.0 - TilePalette.MEMORY_DIM)
	draw_rect(rect, color)
	_draw_fog_edges(tile)
	var owner: int = snapshot.owners[tile]
	if owner != Faction.NONE:
		draw_rect(rect, Color(TilePalette.owner(owner, colorblind), 0.30))
		# A pattern besides the colour (accessibility): a chevron for the pack, a bar for the enemy.
		var c := rect.get_center()
		var s := layout.tile_size * 0.12
		if owner == Faction.PLAYER:
			draw_polyline(PackedVector2Array([c + Vector2(-s, s), c + Vector2(0, -s), c + Vector2(s, s)]), TilePalette.owner(owner, colorblind), 1.0)
		else:
			draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), TilePalette.owner(owner, colorblind), 1.0)


## A faint, fixed variation of a tile's value, in -GRAIN..GRAIN (the same for the same tile
## whatever the zoom): the ground reads as ground, not as a flat colour. Never a signal.
static func grain(tile: int) -> float:
	var h := (tile * 2654435761) & 0xFFFF
	return (float(h % 1000) / 999.0 - 0.5) * 2.0 * GRAIN


## Where a discovered tile touches the fog, a soft dark strip fades the edge in; a tile cut
## by the edge of the map area keeps its hard edge.
func _draw_fog_edges(tile: int) -> void:
	var full := layout.rect_of(tile)
	if not clip_area.encloses(full):
		return
	var sides := fog_sides(tile)
	if sides == 0:
		return
	var depth := full.size.x * FOG_EDGE_DEPTH
	var near := Color(TilePalette.FOG, FOG_EDGE_ALPHA)
	var far := Color(TilePalette.FOG, 0.0)
	if sides & SIDE_LEFT:
		draw_polygon(PackedVector2Array([full.position, full.position + Vector2(depth, 0), full.position + Vector2(depth, full.size.y), full.position + Vector2(0, full.size.y)]), PackedColorArray([near, far, far, near]))
	if sides & SIDE_RIGHT:
		var r := full.end.x
		draw_polygon(PackedVector2Array([Vector2(r - depth, full.position.y), Vector2(r, full.position.y), Vector2(r, full.end.y), Vector2(r - depth, full.end.y)]), PackedColorArray([far, near, near, far]))
	if sides & SIDE_UP:
		draw_polygon(PackedVector2Array([full.position, full.position + Vector2(full.size.x, 0), full.position + Vector2(full.size.x, depth), full.position + Vector2(0, depth)]), PackedColorArray([near, near, far, far]))
	if sides & SIDE_DOWN:
		var d := full.end.y
		draw_polygon(PackedVector2Array([Vector2(full.position.x, d - depth), Vector2(full.end.x, d - depth), full.end, Vector2(full.position.x, d)]), PackedColorArray([far, far, near, near]))


## The sides of a tile that touch undiscovered ground (SIDE_* bits); 0 for an undiscovered tile.
func fog_sides(tile: int) -> int:
	if snapshot == null or snapshot.fog_at(tile) == VisionService.FOG_UNDISCOVERED:
		return 0
	var x := tile % snapshot.columns
	var y := tile / snapshot.columns
	var sides := 0
	if x > 0 and snapshot.fog_at(tile - 1) == VisionService.FOG_UNDISCOVERED:
		sides |= SIDE_LEFT
	if x < snapshot.columns - 1 and snapshot.fog_at(tile + 1) == VisionService.FOG_UNDISCOVERED:
		sides |= SIDE_RIGHT
	if y > 0 and snapshot.fog_at(tile - snapshot.columns) == VisionService.FOG_UNDISCOVERED:
		sides |= SIDE_UP
	if y < snapshot.rows - 1 and snapshot.fog_at(tile + snapshot.columns) == VisionService.FOG_UNDISCOVERED:
		sides |= SIDE_DOWN
	return sides


func _draw_node(node: Array) -> void:
	if not clip_area.encloses(layout.rect_of(node[0]).grow(-layout.tile_size * 0.2)):
		return
	var rect := layout.rect_of(node[0])
	if snapshot.fog_at(node[0]) == VisionService.FOG_UNDISCOVERED:
		return
	var c := rect.get_center()
	var r := layout.tile_size * 0.36
	var diamond := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(diamond, TilePalette.owner(node[1], colorblind))
	draw_polyline(diamond + PackedVector2Array([diamond[0]]), TilePalette.OUTLINE, 1.5)
	for k in node[2]:  # the level, one pip per level
		draw_circle(c + Vector2((k - (node[2] - 1) / 2.0) * layout.tile_size * 0.14, 0), layout.tile_size * 0.04, TilePalette.OUTLINE)


func _draw_ruin(ruin: Array) -> void:
	if not clip_area.encloses(layout.rect_of(ruin[0]).grow(-layout.tile_size * 0.2)):
		return
	var rect := layout.rect_of(ruin[0])
	var c := rect.get_center()
	var s := layout.tile_size * 0.28
	var color: Color = TilePalette.RUIN if not ruin[1] else TilePalette.RUIN.darkened(0.5)
	draw_polyline(PackedVector2Array([c + Vector2(-s, s), c + Vector2(-s, -s), c + Vector2(s, -s * 0.2), c + Vector2(s, s)]), color, 2.0)


func _draw_unit(unit: Array) -> void:
	if not clip_area.encloses(layout.rect_of(unit[1]).grow(-layout.tile_size * 0.2)):
		return
	var rect := layout.rect_of(unit[1])
	var c := rect.get_center()
	var moving := _moving_center(unit[0])
	if moving.x >= 0.0:
		rect.position += moving - c
		c = moving
	var r := layout.tile_size * 0.30
	var fill := TilePalette.owner(unit[2], colorblind) if not unit[6] else TilePalette.owner(Faction.NONE, colorblind).darkened(0.3)
	var outline := TilePalette.ENEMY_OUTLINE if unit[2] == Faction.AI else TilePalette.OUTLINE
	var points := _shape(unit[3], c, r)
	draw_colored_polygon(points, fill)
	draw_polyline(points + PackedVector2Array([points[0]]), outline, 1.5)
	if unit[6]:  # asleep: a bar across the body
		draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), TilePalette.OUTLINE, 2.0)
	if unit[4] < unit[5]:
		var bar := Rect2(rect.position + Vector2(layout.tile_size * 0.1, layout.tile_size * 0.86), Vector2(layout.tile_size * 0.8, 3.0))
		draw_rect(bar, TilePalette.OUTLINE)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(unit[4]) / unit[5], bar.size.y)), TilePalette.owner(Faction.PLAYER, colorblind))


## Where an animated unit is drawn: along its MOVE effect, (-1, -1) when it is not moving.
func _moving_center(unit_id: int) -> Vector2:
	if clock == null:
		return Vector2(-1, -1)
	for effect in effects:
		if effect.kind == TileEffect.Kind.MOVE and effect.unit_id == unit_id:
			return layout.center_of(effect.tile).lerp(layout.center_of(effect.tile2), effect.progress(clock.current()))
	return Vector2(-1, -1)


func _draw_effect(effect: TileEffect) -> void:
	var now := clock.current() if clock != null else effect.start + effect.duration
	var p := effect.progress(now)
	match effect.kind:
		TileEffect.Kind.LINE:
			draw_line(layout.center_of(effect.tile), layout.center_of(effect.tile2), Color(TilePalette.SELECTION, 1.0 - 0.5 * p), 3.0)
		TileEffect.Kind.FLOAT_TEXT:
			var at := layout.center_of(effect.tile) + Vector2(-layout.tile_size * 0.2, -layout.tile_size * 0.3 - layout.tile_size * 0.4 * p)
			draw_string(ThemeDB.fallback_font, at, effect.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(effect.color, 1.0 - p * p))
		TileEffect.Kind.GHOST:
			var c := layout.center_of(effect.tile)
			var r := layout.tile_size * 0.30
			var points := _shape(effect.unit_type, c + Vector2(0, r * 0.4 * p), r)
			for k in points.size():
				points[k].y = c.y + (points[k].y - c.y) * (1.0 - 0.5 * p)  # it sags
			draw_colored_polygon(points, Color(TilePalette.NEUTRAL, 0.8 * (1.0 - p)))
		TileEffect.Kind.PULSE:  # a ring leaves the selected tile and fades
			var ring := layout.rect_of(effect.tile).grow(layout.tile_size * 0.3 * p)
			draw_rect(ring, Color(TilePalette.SELECTION, 0.9 * (1.0 - p)), false, 2.0)
		TileEffect.Kind.MOVE:  # the path the unit has taken, fading
			var here := layout.center_of(effect.tile).lerp(layout.center_of(effect.tile2), p)
			draw_line(layout.center_of(effect.tile), here, Color(TilePalette.SELECTION, 0.55 * (1.0 - p * p)), 3.0)
		TileEffect.Kind.WAVE:
			for tile in effect.tiles:
				var shown := layout.rect_of(tile).intersection(clip_area)
				if shown.size.x > 0.0 and shown.size.y > 0.0:
					draw_rect(shown, Color(effect.color, 0.30 * p))


func _draw_threat(threat: Array) -> void:
	_draw_brackets(threat[2], TilePalette.THREAT, 2.0)


## True when the whole tile is inside the shown part of the map.
func _inside(tile: int) -> bool:
	return clip_area.encloses(layout.rect_of(tile))


func _draw_brackets(tile: int, color: Color, width: float) -> void:
	if not _inside(tile):
		return
	var rect := layout.rect_of(tile).grow(-3.0)
	var corner := layout.tile_size * 0.25
	for sx in [0, 1]:
		for sy in [0, 1]:
			var p := rect.position + Vector2(rect.size.x * sx, rect.size.y * sy)
			var dx := Vector2(corner * (1 - 2 * sx), 0)
			var dy := Vector2(0, corner * (1 - 2 * sy))
			draw_line(p, p + dx, color, width)
			draw_line(p, p + dy, color, width)


## A polygon per unit type (the shape tells the type apart, not the colour).
static func _shape(type: int, c: Vector2, r: float) -> PackedVector2Array:
	var sides := 3 + (type % 5)
	var points := PackedVector2Array()
	for k in sides:
		var angle := -PI / 2.0 + TAU * k / sides
		points.append(c + Vector2(cos(angle), sin(angle)) * r)
	return points
