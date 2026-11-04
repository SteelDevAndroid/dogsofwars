# The models of the 3D map delivered by an artist (design/art/asset-specs.md): a `.glb` named
# like the piece it replaces in `dir` (`unit_assaut.glb`, `terrain_foret_02.glb`...). When it is
# there its mesh is used, else MapView3D keeps the shape built in code (LowPoly). In the game the
# files are imported resources (a PackedScene); a raw `.glb` that was not imported (tests, a
# folder outside the project) is read with GLTFDocument. The first mesh found in the model is
# taken, cached by name; a name with no model is remembered as missing.
#
# A model is made ready as it loads (the artist's tools do not all write what the game needs):
# `COLOR_0` holds the colours as the art bible writes them (hex values, sRGB-coded numbers), the
# game turns them into the linear values its shader takes; a mesh without normals gets flat
# ones (faces are flat, art bible 1); the triangles are listed one by one, so no vertex is
# shared between two faces that would then share a normal.
class_name ModelLibrary
extends RefCounted

const DIR := "res://assets/art/3d"

var dir := DIR

var _meshes := {}  # name -> Mesh, or null when there is no model


func _init(p_dir: String = DIR) -> void:
	dir = p_dir


## The artist's mesh for `name` (without extension), or null: then the code's shape is used.
func mesh(name: String) -> Mesh:
	if not _meshes.has(name):
		_meshes[name] = _load(name)
	return _meshes[name]


func has(name: String) -> bool:
	return mesh(name) != null


func _load(name: String) -> Mesh:
	var path := "%s/%s.glb" % [dir, name]
	var root: Node = null
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		root = scene.instantiate() if scene != null else null
	elif FileAccess.file_exists(path):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(path, state) == OK:
			root = document.generate_scene(state)
	if root == null:
		return null
	var found := _first_mesh(root)
	var ready := ready_mesh(found) if found != null else null
	root.free()
	return ready


## `mesh` as the game draws it: flat normals when it has none, linear colours, one vertex per
## triangle corner. Godot lists the front of a face clockwise, so a face looks toward the
## cross product of (c - a) and (b - a).
static func ready_mesh(mesh: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for i in points.size():
				indices.append(i)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var vertices := PackedVector3Array()
		var shades := PackedColorArray()
		var facing := PackedVector3Array()
		for corner in indices.size():
			var index := indices[corner]
			vertices.append(points[index])
			if not colors.is_empty():
				var color := colors[index]
				shades.append(Color(color.srgb_to_linear(), color.a))
			if not normals.is_empty():
				facing.append(normals[index])
		if normals.is_empty():
			for triangle in indices.size() / 3:
				var a := vertices[triangle * 3]
				var normal := (vertices[triangle * 3 + 2] - a).cross(vertices[triangle * 3 + 1] - a).normalized()
				for corner in 3:
					facing.append(normal)
		var flat := []
		flat.resize(Mesh.ARRAY_MAX)
		flat[Mesh.ARRAY_VERTEX] = vertices
		flat[Mesh.ARRAY_NORMAL] = facing
		if not shades.is_empty():
			flat[Mesh.ARRAY_COLOR] = shades
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, flat)
	return out


static func _first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null


## The model names of the pieces (design/art/asset-specs.md, sections 4 and 5).
static func terrain_name(kind: int, variant: int) -> String:
	var names := {TerrainGrid.PLAIN: "plaine", TerrainGrid.FOREST: "foret", TerrainGrid.MOUNTAIN: "montagne", TerrainGrid.WATER: "eau"}
	return "terrain_%s_%02d" % [names.get(kind, "plaine"), variant % 3 + 1]


static func node_name(level: int) -> String:
	return "node_niveau_%d" % clampi(level, 1, 3)


static func ruin_name(variant: int) -> String:
	return ["ruin_arche_brisee_01", "ruin_arche_brisee_02", "ruin_dome_brise_01"][variant % 3]


static func unit_name(key: String, asleep: bool) -> String:
	return "unit_%s_endormi" % key if asleep else "unit_%s" % key
