# The map in 3D (ADR-0014; art bible 1 "Production hybride"): low-poly tiles in flat colours,
# a three-quarter orthographic camera, one light from the left. It reads a TileSnapshot only, so
# it shows nothing the player does not know: an undiscovered tile is the same dark slab whatever
# is under it, an explored one out of view is dimmed and shows no unit.
# In the match it shows a TileRenderer that no longer draws (`renderer`): that node keeps the
# snapshot, the effects (slides, attacks, waves, ghosts), the selection and the targets, with
# their timing already tested; `sync` copies them to the scene each frame and frames the camera
# from the MapCamera. The colour of a tile is one shader per tile (grey -> tint by `strength`),
# which the colour wave of GDD 15 drives through `shown_state`.
class_name MapView3D
extends Node3D

## Camera pitch: a three-quarter view, low enough for the relief, high enough to read the grid.
const PITCH_DEGREES := 42.0
## Units a little larger than their tile slot in the art bible's 31 pt, so the trait reads.
const UNIT_SCALE := 1.25
const TERRAIN_SHADER := preload("res://src/presentation/map3d/terrain.gdshader")
const OUTLINE_SHADER := preload("res://src/presentation/map3d/outline.gdshader")
const OVERLAY_SHADER := preload("res://src/presentation/map3d/overlay.gdshader")
## An undiscovered tile: a flat dark slab, a step above the background so the map edge reads.
const FOG_SLAB := Color("323A44")

var snapshot: TileSnapshot
var colorblind := false
var camera := Camera3D.new()
var light := DirectionalLight3D.new()
## tile -> its MeshInstance3D (terrain or fog slab).
var tiles := {}
var units: Array[MeshInstance3D] = []

## The model shown in the match, and the logical camera (centre, zoom, area) it frames from.
var renderer: TileRenderer
var map_camera: MapCamera

var _content := Node3D.new()
var _fx_root := Node3D.new()
var _viewport := Vector2(1, 1)
var _unit_nodes := {}  # unit id -> MeshInstance3D
var _fx := {}  # TileEffect -> Node3D
var _tinted := {}  # tile -> Vector2i (owner, saturation) shown by a wave
var _selection_key := []
var _hint: MeshInstance3D
var _meshes := {}
var _unit_types := {}


func _init() -> void:
	add_child(_content)
	add_child(_fx_root)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.rotation_degrees = Vector3(-PITCH_DEGREES, 0, 0)
	camera.near = 0.1
	camera.far = 100.0
	add_child(camera)
	# from the left, a little in front: the faces turned to the camera are lit (art bible 6: light
	# at the top left, read from the camera)
	light.rotation_degrees = Vector3(-55, -50, 0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	light.shadow_opacity = 0.6
	add_child(light)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = TilePalette.FOG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("AEB8C4")
	env.ambient_light_energy = 0.85
	world.environment = env
	add_child(world)


## `unit_types`: type id -> [key, guardian] (from the catalog), for the shapes of the units.
func set_unit_types(types: Dictionary) -> void:
	_unit_types = types


func show_snapshot(p_snapshot: TileSnapshot) -> void:
	snapshot = p_snapshot
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	tiles.clear()
	units.clear()
	_unit_nodes.clear()
	_tinted.clear()
	_selection_key = []
	_hint = null
	for tile in snapshot.columns * snapshot.rows:
		_add_tile(tile)
	for node: Array in snapshot.nodes:
		if snapshot.fog_at(node[0]) != VisionService.FOG_UNDISCOVERED:
			var level: int = node[2]
			var color: Color = TilePalette.owner(node[1], colorblind) if node[1] != Faction.NONE else LowPoly.FOREST
			_place(_mesh("node|%d|%s" % [level, color.to_html()], func() -> ArrayMesh: return LowPoly.node(level, color)), node[0], 0.0,
					snapshot.fog_at(node[0]) == VisionService.FOG_EXPLORED)
	for ruin: Array in snapshot.ruins:  # seen above the fog by their glow (art bible 6)
		var read: bool = ruin[1]
		var variant := TileRenderer.variant_of(ruin[0]) % 2
		_place(_mesh("ruin|%s|%d" % [read, variant], func() -> ArrayMesh: return LowPoly.ruin(read, variant)), ruin[0], 0.0, false)
		if not read:
			var glow := OmniLight3D.new()
			glow.light_color = TilePalette.RUIN
			glow.light_energy = 0.7
			glow.omni_range = 1.1
			glow.position = center_of(ruin[0]) + Vector3(0, 0.45, 0.2)
			_content.add_child(glow)
	for unit: Array in snapshot.units:
		if snapshot.fog_at(unit[1]) == VisionService.FOG_VISIBLE or unit[2] == Faction.PLAYER:
			_add_unit(unit)
	for threat: Array in snapshot.threats:
		var marker := _place(_mesh("threat", func() -> ArrayMesh: return LowPoly.threat(TilePalette.THREAT)), threat[2], 0.0, false)
		marker.material_override = _overlay(TilePalette.THREAT, 1.0)


## Copies the model to the scene: a new snapshot (only when its content changed: a tap makes a
## new one each time), the selection and the targets, the tints of the waves, the slides, the
## transient effects, the arrow of the first turns; then frames the camera. `viewport`: the size
## of the viewport in the units of the HUD (the taps' units).
func sync(viewport: Vector2) -> void:
	if renderer == null or renderer.snapshot == null:
		return
	if renderer.colorblind != colorblind:
		colorblind = renderer.colorblind
		snapshot = null
	if not same_content(renderer.snapshot, snapshot):
		show_snapshot(renderer.snapshot)
	var key := [renderer.selected_tile, renderer.highlighted, renderer.targets, renderer.chosen_target]
	if key != _selection_key:
		_selection_key = key
		set_selection(renderer.selected_tile, renderer.highlighted)
		set_targets(renderer.targets, renderer.chosen_target)
	var now := renderer.clock.current() if renderer.clock != null else INF
	_sync_tints(now)
	_sync_units(now)
	_sync_effects(now)
	_sync_hint(now)
	if map_camera != null:
		frame_camera(map_camera.area, viewport, map_camera.area.size.x / map_camera.tile_size, map_camera.center)


## Two snapshots that would draw the same scene.
static func same_content(a: TileSnapshot, b: TileSnapshot) -> bool:
	return b != null and a.columns == b.columns and a.rows == b.rows and a.fog == b.fog and a.terrain == b.terrain \
			and a.owners == b.owners and a.units == b.units and a.nodes == b.nodes and a.ruins == b.ruins \
			and a.threats == b.threats and a.player_turn == b.player_turn


## The selected tile (a light frame) and the move range (a light fill and a frame per tile).
func set_selection(tile: int, reachable: PackedInt32Array) -> void:
	for child in _content.get_children():
		if child.has_meta(&"selection"):
			_content.remove_child(child)
			child.queue_free()
	for reach in reachable:
		var fill := _place(_mesh("reach", func() -> ArrayMesh: return LowPoly.quad(0.96, 0.0)), reach, _top(reach) + 0.012, false)
		fill.material_override = _overlay(TilePalette.SELECTION, 0.22)
		fill.set_meta(&"selection", true)
		var edge := _place(_mesh("reach_frame", func() -> ArrayMesh: return LowPoly.frame(0.9, 0.03, 0.0)), reach, _top(reach) + 0.014, false)
		edge.material_override = _overlay(TilePalette.SELECTION, 0.85)
		edge.set_meta(&"selection", true)
	if tile >= 0:
		var ring := _place(_mesh("select_frame", func() -> ArrayMesh: return LowPoly.frame(0.98, 0.06, 0.0)), tile, _top(tile) + 0.016, false)
		ring.material_override = _overlay(TilePalette.SELECTION, 1.0)
		ring.set_meta(&"selection", true)


## The units the selected one may strike (orange-red frames), the chosen one brighter.
func set_targets(target_tiles: PackedInt32Array, chosen: int) -> void:
	for child in _content.get_children():
		if child.has_meta(&"target"):
			_content.remove_child(child)
			child.queue_free()
	for tile in target_tiles:
		var frame := _place(_mesh("target_frame", func() -> ArrayMesh: return LowPoly.frame(0.94, 0.07, 0.0)), tile, _top(tile) + 0.018, false)
		frame.material_override = _overlay(TilePalette.THREAT, 1.0 if tile == chosen else 0.75)
		frame.set_meta(&"target", true)


## Frames the camera: `columns` tiles across `area` (a rectangle of the viewport of size
## `viewport`), the tile `focus` (x, y in tiles, fractional) at the centre of `area`.
func frame_camera(area: Rect2, viewport: Vector2, columns: float, focus: Vector2) -> void:
	_viewport = viewport
	camera.size = columns * viewport.x / maxf(area.size.x, 1.0)
	if snapshot != null:
		focus = clamp_focus(focus, columns, area.size.y / area.size.x * columns / sin(deg_to_rad(PITCH_DEGREES)), snapshot.columns, snapshot.rows)
	var target := Vector3(focus.x, 0.0, focus.y)
	camera.position = target + camera.transform.basis.z * 30.0
	var per_pixel := camera.size / viewport.x
	var offset := area.get_center() - viewport / 2.0
	camera.h_offset = -offset.x * per_pixel
	camera.v_offset = offset.y * per_pixel


## The centre kept so the map fills the area, with half a tile of margin (GDD 4): the ground
## seen is `width` x `depth` tiles (the tilt stretches the depth); a map smaller than that is centred.
static func clamp_focus(focus: Vector2, width: float, depth: float, columns: int, rows: int) -> Vector2:
	var margin := 0.5
	var half := Vector2(width, depth) / 2.0
	var size := Vector2(columns, rows)
	var out := focus
	for axis in 2:
		if 2.0 * half[axis] >= size[axis] + 2.0 * margin:
			out[axis] = size[axis] / 2.0
		else:
			out[axis] = clampf(focus[axis], half[axis] - margin, size[axis] + margin - half[axis])
	return out


## The tile under a point of the screen (the ray meets the ground plane), -1 off the map.
func tile_at(screen_point: Vector2) -> int:
	if snapshot == null:
		return -1
	# the orthographic projection by hand (the engine's needs a rendering viewport): the ray
	# leaves the camera plane at the point's offset from the centre, along the view direction
	var per_pixel := camera.size / _viewport.x
	var offset := screen_point - _viewport / 2.0
	var basis := camera.transform.basis
	var origin := camera.position + basis.x * (offset.x * per_pixel + camera.h_offset) + basis.y * (-offset.y * per_pixel + camera.v_offset)
	var direction := -basis.z
	if absf(direction.y) < 0.0001:
		return -1
	var hit := origin + direction * (-origin.y / direction.y)
	var x := floori(hit.x)
	var y := floori(hit.z)
	if x < 0 or y < 0 or x >= snapshot.columns or y >= snapshot.rows:
		return -1
	return y * snapshot.columns + x


## Where the centre of a tile's top shows on the screen (the inverse of tile_at).
func screen_of(tile: int) -> Vector2:
	var basis := camera.transform.basis
	var relative := center_of(tile) + Vector3(0, _top(tile), 0) - camera.position
	var per_pixel := camera.size / _viewport.x
	var x := (relative.dot(basis.x) - camera.h_offset) / per_pixel
	var y := -(relative.dot(basis.y) - camera.v_offset) / per_pixel
	return _viewport / 2.0 + Vector2(x, y)


static func center_of_tile(tile: int, columns: int) -> Vector3:
	return Vector3(tile % columns + 0.5, 0.0, tile / columns + 0.5)


func center_of(tile: int) -> Vector3:
	return center_of_tile(tile, snapshot.columns)


func _add_tile(tile: int) -> void:
	var level := snapshot.fog_at(tile)
	var instance: MeshInstance3D
	if level == VisionService.FOG_UNDISCOVERED:
		instance = _place(_mesh("fog", func() -> ArrayMesh: return LowPoly.fog()), tile, 0.0, false)
		instance.material_override = _overlay(FOG_SLAB, 1.0)  # unlit: no relief, no shading, nothing told
	else:
		var kind: int = snapshot.terrain[tile]
		var variant := TileRenderer.variant_of(tile)
		instance = _place(_mesh("terrain|%d|%d" % [kind, variant], func() -> ArrayMesh: return LowPoly.terrain(kind, variant)), tile, 0.0, false)
		var owner: int = snapshot.owners[tile]
		var material := ShaderMaterial.new()
		material.shader = TERRAIN_SHADER
		material.set_shader_parameter(&"tint", TilePalette.owner(owner, colorblind))
		material.set_shader_parameter(&"strength", 1.0 if owner != Faction.NONE else 0.0)
		material.set_shader_parameter(&"memory", 1.0 if level == VisionService.FOG_EXPLORED else 0.0)
		instance.material_override = material
		if owner == Faction.PLAYER or owner == Faction.AI:  # a shape besides the colour (accessibility)
			var mark_color := TilePalette.owner(owner, colorblind).darkened(0.35)
			var mark := _place(_mesh("mark|%d|%s" % [owner, mark_color.to_html()], func() -> ArrayMesh: return LowPoly.owner_mark(owner == Faction.PLAYER, mark_color)),
					tile, _top(tile), level == VisionService.FOG_EXPLORED)
			mark.position += Vector3(0.3, 0, 0.3)  # in a corner, out of the way of what stands on the tile
	tiles[tile] = instance


func _add_unit(unit: Array) -> void:
	var type: int = unit[3]
	var info: Array = _unit_types.get(type, ["assaut", false])
	var color := TilePalette.owner(unit[2], colorblind) if unit[2] != Faction.NONE else LowPoly.ASLEEP
	var asleep: bool = unit[6] or unit[2] == Faction.NONE
	var guardian: bool = info[1]
	var key := "unit|%s|%s|%s|%s" % [info[0], color.to_html(), guardian, asleep]
	var instance := _place(_mesh(key, func() -> ArrayMesh: return LowPoly.unit(info[0], color, guardian, asleep)), unit[1], _top(unit[1]), false)
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter(&"color", TilePalette.ENEMY_OUTLINE if unit[2] == Faction.AI else TilePalette.OUTLINE)
	material.next_pass = outline
	instance.material_override = material
	instance.rotation.y = PI if unit[2] == Faction.AI else 0.0  # the Guardians face the pack
	instance.scale = Vector3.ONE * UNIT_SCALE
	if unit[4] < unit[5]:  # hit points: a white gauge above the unit (art bible 4), shorter as it falls
		var back := _bar(0.5, TilePalette.OUTLINE)
		back.position = Vector3(0, 0.62, 0)
		instance.add_child(back)
		var fill := _bar(0.48 * float(unit[4]) / float(unit[5]), TilePalette.SELECTION)
		fill.position = Vector3(-0.24 + 0.24 * float(unit[4]) / float(unit[5]), 0.625, 0.01 if unit[2] != Faction.AI else -0.01)
		instance.add_child(fill)
	if snapshot.player_turn and unit[2] == Faction.PLAYER and not unit[7] and not unit[8]:  # has not played
		var mark := MeshInstance3D.new()
		mark.mesh = _mesh("idle", func() -> ArrayMesh: return LowPoly.idle_mark())
		mark.material_override = _overlay(TilePalette.SELECTION, 1.0)
		mark.position = Vector3(0.24, 0.58, 0)
		instance.add_child(mark)
	units.append(instance)
	_unit_nodes[unit[0]] = instance


func _bar(width: float, color: Color) -> MeshInstance3D:
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.05, 0.02)
	bar.mesh = box
	bar.material_override = _overlay(color, 1.0)
	return bar


## A wave shows each tile it covers with the tint and saturation of its fade (GDD 15); a tile it
## no longer covers goes back to the snapshot's colour.
func _sync_tints(now: float) -> void:
	var covered := renderer.wave_tiles()
	for tile in _tinted.keys():
		if not covered.has(tile):
			_set_tint(tile, renderer.shown_state(tile, now))
			_tinted.erase(tile)
	for tile: int in covered:
		var shown := renderer.shown_state(tile, now)
		if _tinted.get(tile, Vector2i(-9, -9)) != shown:
			_tinted[tile] = shown
			_set_tint(tile, shown)


func _set_tint(tile: int, shown: Vector2i) -> void:
	if not tiles.has(tile) or snapshot.fog_at(tile) == VisionService.FOG_UNDISCOVERED:
		return
	var material := (tiles[tile] as MeshInstance3D).material_override as ShaderMaterial
	material.set_shader_parameter(&"tint", TilePalette.owner(shown.x, colorblind))
	material.set_shader_parameter(&"strength", 0.0 if shown.x == Faction.NONE else shown.y / 1000.0)


## A sliding unit follows its MOVE effect from tile to tile (ADR-0002, the slide).
func _sync_units(now: float) -> void:
	for unit: Array in snapshot.units:
		if not _unit_nodes.has(unit[0]):
			continue
		var node: MeshInstance3D = _unit_nodes[unit[0]]
		var at := center_of(unit[1]) + Vector3(0, _top(unit[1]), 0)
		for effect in renderer.effects:
			if effect.kind == TileEffect.Kind.MOVE and effect.unit_id == unit[0]:
				var from := center_of(effect.tile) + Vector3(0, _top(effect.tile), 0)
				var to := center_of(effect.tile2) + Vector3(0, _top(effect.tile2), 0)
				at = from.lerp(to, effect.progress(now))
		node.position = at


## The transient effects: the attack line, the numbers that rise, the ghost of a destroyed unit
## that sinks and fades, the ring of a selection. One node per effect, dropped with it.
func _sync_effects(now: float) -> void:
	var alive := {}
	for effect in renderer.effects:
		if effect.kind == TileEffect.Kind.WAVE or effect.kind == TileEffect.Kind.MOVE:
			continue
		alive[effect] = true
		if not _fx.has(effect):
			_fx[effect] = _effect_node(effect)
			_fx_root.add_child(_fx[effect])
		_update_effect(effect, _fx[effect], effect.progress(now))
	for effect in _fx.keys():
		if not alive.has(effect):
			(_fx[effect] as Node).queue_free()
			_fx.erase(effect)


func _effect_node(effect: TileEffect) -> Node3D:
	match effect.kind:
		TileEffect.Kind.LINE:
			var line := MeshInstance3D.new()
			var from := center_of(effect.tile) + Vector3(0, _top(effect.tile) + 0.35, 0)
			var to := center_of(effect.tile2) + Vector3(0, _top(effect.tile2) + 0.35, 0)
			var box := BoxMesh.new()
			box.size = Vector3(0.05, 0.05, from.distance_to(to))
			line.mesh = box
			line.material_override = _overlay(TilePalette.SELECTION, 1.0)
			line.position = (from + to) / 2.0
			if from.distance_to(to) > 0.001:
				line.look_at_from_position(line.position, to, Vector3.UP)
			return line
		TileEffect.Kind.FLOAT_TEXT:
			var label := Label3D.new()
			label.text = effect.text
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 64
			label.outline_size = 16
			label.pixel_size = 0.005
			label.modulate = effect.color
			label.no_depth_test = true
			return label
		TileEffect.Kind.GHOST:
			var ghost := MeshInstance3D.new()
			var info: Array = _unit_types.get(effect.unit_type, ["assaut", false])
			ghost.mesh = _mesh("ghost|%s|%s" % info, func() -> ArrayMesh: return LowPoly.unit(info[0], LowPoly.ASLEEP, info[1], true))
			var material := ShaderMaterial.new()
			material.shader = TERRAIN_SHADER
			ghost.material_override = material
			ghost.scale = Vector3.ONE * UNIT_SCALE
			return ghost
		_:  # PULSE: a ring leaves the tile
			var ring := MeshInstance3D.new()
			ring.mesh = _mesh("pulse", func() -> ArrayMesh: return LowPoly.frame(1.0, 0.04, 0.0))
			ring.material_override = _overlay(TilePalette.SELECTION, 0.9)
			return ring


func _update_effect(effect: TileEffect, node: Node3D, p: float) -> void:
	match effect.kind:
		TileEffect.Kind.LINE:
			((node as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter(&"color", Color(TilePalette.SELECTION, 1.0 - 0.5 * p))
		TileEffect.Kind.FLOAT_TEXT:
			node.position = center_of(effect.tile) + Vector3(0, _top(effect.tile) + 0.7 + 0.5 * p, 0)
			(node as Label3D).modulate = Color(effect.color, 1.0 - p * p)
			(node as Label3D).outline_modulate = Color(TilePalette.OUTLINE, 1.0 - p * p)
		TileEffect.Kind.GHOST:  # it sags and fades
			node.position = center_of(effect.tile) + Vector3(0, _top(effect.tile), 0)
			node.scale = Vector3(UNIT_SCALE, UNIT_SCALE * (1.0 - 0.5 * p), UNIT_SCALE)
			(node as GeometryInstance3D).transparency = p
		TileEffect.Kind.PULSE:
			node.position = center_of(effect.tile) + Vector3(0, _top(effect.tile) + 0.02, 0)
			node.scale = Vector3.ONE * (1.0 + 0.6 * p)
			((node as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter(&"color", Color(TilePalette.SELECTION, 0.9 * (1.0 - p)))


## The arrow of the first turns above the unit to touch first; it bobs unless `still`.
func _sync_hint(now: float) -> void:
	var tile := renderer.hint_tile
	if tile < 0 or tile >= snapshot.columns * snapshot.rows:
		if _hint != null:
			_hint.visible = false
		return
	if _hint == null:
		_hint = MeshInstance3D.new()
		_hint.mesh = _mesh("hint", func() -> ArrayMesh: return LowPoly.arrow())
		_hint.material_override = _overlay(TilePalette.SELECTION, 1.0)
		_content.add_child(_hint)
	_hint.visible = true
	var bob := 0.0 if renderer.still or is_inf(now) else sin(now * 5.0) * 0.06
	_hint.position = center_of(tile) + Vector3(0, _top(tile) + 1.0 + bob, 0)


## Where things stand on a tile: its top, or the summit of a mountain, the water level.
func _top(tile: int) -> float:
	if snapshot.fog_at(tile) == VisionService.FOG_UNDISCOVERED:
		return 0.0
	match snapshot.terrain[tile]:
		TerrainGrid.WATER:
			return LowPoly.WATER_TOP
		TerrainGrid.MOUNTAIN:
			return 0.12
		TerrainGrid.PLAIN:
			return LowPoly.plain_lift(TileRenderer.variant_of(tile))
	return 0.0


func _place(mesh: ArrayMesh, tile: int, height: float, dim: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center_of(tile) + Vector3(0, height, 0)
	if dim:
		var material := ShaderMaterial.new()
		material.shader = TERRAIN_SHADER
		material.set_shader_parameter(&"memory", 1.0)
		instance.material_override = material
	elif instance.material_override == null:
		var plain := ShaderMaterial.new()
		plain.shader = TERRAIN_SHADER
		instance.material_override = plain
	_content.add_child(instance)
	return instance


func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		_meshes[key] = build.call()
	return _meshes[key]


static func _overlay(color: Color, alpha: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OVERLAY_SHADER
	material.set_shader_parameter(&"color", Color(color, alpha))
	return material
