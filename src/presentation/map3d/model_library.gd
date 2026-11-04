# The models of the 3D map delivered by an artist (design/art/asset-specs.md): a `.glb` named
# like the piece it replaces in `dir` (`unit_assaut.glb`, `terrain_foret_02.glb`...). When it is
# there its mesh is used, else MapView3D keeps the shape built in code (LowPoly). In the game the
# files are imported resources (a PackedScene); a raw `.glb` that was not imported (tests, a
# folder outside the project) is read with GLTFDocument. The first mesh found in the model is
# taken, cached by name; a name with no model is remembered as missing.
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
	root.free()
	return found


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
