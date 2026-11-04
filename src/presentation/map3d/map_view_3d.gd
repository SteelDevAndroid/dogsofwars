# The map in 3D (art bible 1 "Production hybride"; prototype for the decision that would replace
# ADR-0012's 2D drawing): low-poly tiles in flat colours, a three-quarter orthographic camera,
# one light from the top left. It reads a TileSnapshot only, like TileRenderer, so it shows
# nothing the player does not know: an undiscovered tile is the same dark slab whatever is
# under it, an explored one out of view is dimmed and shows no unit.
# The colour of a side comes from one shader per tile (grey -> tint by `strength`), the hook
# the recoloration wave of GDD 15 would animate.
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
const FOG_SLAB := Color("2A3038")

var snapshot: TileSnapshot
var colorblind := false
var camera := Camera3D.new()
var light := DirectionalLight3D.new()
## tile -> its MeshInstance3D (terrain or fog slab).
var tiles := {}
var units: Array[MeshInstance3D] = []

var _content := Node3D.new()
var _viewport := Vector2(1, 1)
var _meshes := {}
var _unit_types := {}


func _init() -> void:
	add_child(_content)
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
	units.append(instance)


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
