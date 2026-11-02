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


func _init() -> void:
	process_priority = 10


func show_state(state: GameState, catalog: DataCatalog) -> void:
	snapshot = TileSnapshot.take(state, catalog)
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
	for tile in snapshot.columns * snapshot.rows:
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
	for tile in highlighted:
		draw_rect(layout.rect_of(tile).grow(-2.0), Color(TilePalette.SELECTION, 0.35))
	if selected_tile >= 0:
		draw_rect(layout.rect_of(selected_tile), TilePalette.SELECTION, false, 2.0)


func _draw_tile(tile: int) -> void:
	var rect := layout.rect_of(tile)
	var level := snapshot.fog_at(tile)
	if level == VisionService.FOG_UNDISCOVERED:
		draw_rect(rect, TilePalette.FOG)
		return
	var color := TilePalette.terrain(snapshot.terrain[tile])
	if level == VisionService.FOG_EXPLORED:
		color = color.darkened(1.0 - TilePalette.MEMORY_DIM)
	draw_rect(rect, color)
	var owner: int = snapshot.owners[tile]
	if owner != Faction.NONE:
		draw_rect(rect, Color(TilePalette.owner(owner), 0.30))
		# A pattern besides the colour (accessibility): a chevron for the pack, a bar for the enemy.
		var c := rect.get_center()
		var s := layout.tile_size * 0.12
		if owner == Faction.PLAYER:
			draw_polyline(PackedVector2Array([c + Vector2(-s, s), c + Vector2(0, -s), c + Vector2(s, s)]), TilePalette.owner(owner), 1.0)
		else:
			draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), TilePalette.owner(owner), 1.0)


func _draw_node(node: Array) -> void:
	var rect := layout.rect_of(node[0])
	if snapshot.fog_at(node[0]) == VisionService.FOG_UNDISCOVERED:
		return
	var c := rect.get_center()
	var r := layout.tile_size * 0.36
	var diamond := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(diamond, TilePalette.owner(node[1]))
	draw_polyline(diamond + PackedVector2Array([diamond[0]]), TilePalette.OUTLINE, 1.5)
	for k in node[2]:  # the level, one pip per level
		draw_circle(c + Vector2((k - (node[2] - 1) / 2.0) * layout.tile_size * 0.14, 0), layout.tile_size * 0.04, TilePalette.OUTLINE)


func _draw_ruin(ruin: Array) -> void:
	var rect := layout.rect_of(ruin[0])
	var c := rect.get_center()
	var s := layout.tile_size * 0.28
	var color: Color = TilePalette.RUIN if not ruin[1] else TilePalette.RUIN.darkened(0.5)
	draw_polyline(PackedVector2Array([c + Vector2(-s, s), c + Vector2(-s, -s), c + Vector2(s, -s * 0.2), c + Vector2(s, s)]), color, 2.0)


func _draw_unit(unit: Array) -> void:
	var rect := layout.rect_of(unit[1])
	var c := rect.get_center()
	var r := layout.tile_size * 0.30
	var fill := TilePalette.owner(unit[2]) if not unit[6] else TilePalette.NEUTRAL.darkened(0.3)
	var outline := TilePalette.ENEMY_OUTLINE if unit[2] == Faction.AI else TilePalette.OUTLINE
	var points := _shape(unit[3], c, r)
	draw_colored_polygon(points, fill)
	draw_polyline(points + PackedVector2Array([points[0]]), outline, 1.5)
	if unit[6]:  # asleep: a bar across the body
		draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), TilePalette.OUTLINE, 2.0)
	if unit[4] < unit[5]:
		var bar := Rect2(rect.position + Vector2(layout.tile_size * 0.1, layout.tile_size * 0.86), Vector2(layout.tile_size * 0.8, 3.0))
		draw_rect(bar, TilePalette.OUTLINE)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(unit[4]) / unit[5], bar.size.y)), TilePalette.PLAYER)


func _draw_threat(threat: Array) -> void:
	var rect := layout.rect_of(threat[2]).grow(-3.0)
	var corner := layout.tile_size * 0.25
	for sx in [0, 1]:
		for sy in [0, 1]:
			var p := rect.position + Vector2(rect.size.x * sx, rect.size.y * sy)
			var dx := Vector2(corner * (1 - 2 * sx), 0)
			var dy := Vector2(0, corner * (1 - 2 * sy))
			draw_line(p, p + dx, TilePalette.THREAT, 2.0)
			draw_line(p, p + dy, TilePalette.THREAT, 2.0)


## A polygon per unit type (the shape tells the type apart, not the colour).
static func _shape(type: int, c: Vector2, r: float) -> PackedVector2Array:
	var sides := 3 + (type % 5)
	var points := PackedVector2Array()
	for k in sides:
		var angle := -PI / 2.0 + TAU * k / sides
		points.append(c + Vector2(cos(angle), sin(angle)) * r)
	return points
