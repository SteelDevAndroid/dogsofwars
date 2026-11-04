extends GdUnitTestSuite

## The checks of design/art/asset-specs.md (section 8) on every model delivered in assets/art/3d.
## A model that fails one is not accepted: the first delivery of terrain had every face inside out,
## and nothing but a render showed it.

const DIR := "res://assets/art/3d"
const TERRAIN_TRIANGLES_MAX := 300
const HEIGHT_MAX := {"plaine": 0.06, "foret": 0.31, "montagne": 0.43, "eau": 0.001}


static func _delivered() -> PackedStringArray:
	var names := PackedStringArray()
	for file in DirAccess.get_files_at(DIR):
		if file.ends_with(".glb"):
			names.append(file.trim_suffix(".glb"))
	names.sort()
	return names


static func _all_names() -> Array:
	var names := []
	for kind in [TerrainGrid.PLAIN, TerrainGrid.FOREST, TerrainGrid.MOUNTAIN, TerrainGrid.WATER]:
		for variant in 3:
			names.append(ModelLibrary.terrain_name(kind, variant))
	for level in [1, 2, 3]:
		names.append(ModelLibrary.node_name(level))
	for variant in 3:
		names.append(ModelLibrary.ruin_name(variant))
	for key in ["eclaireur", "assaut", "rempart", "ouvrier", "sentinelle", "chasseur", "bastion"]:
		names.append(ModelLibrary.unit_name(key, false))
		names.append(ModelLibrary.unit_name(key, true))
	return names


## The area of the faces turned up, minus the area of those turned down, in the way the game
## draws them (Godot: a face is seen from the side its corners go clockwise).
static func _upward_area(mesh: Mesh) -> float:
	var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var total := 0.0
	for triangle in points.size() / 3:
		var a := points[triangle * 3]
		var normal := (points[triangle * 3 + 2] - a).cross(points[triangle * 3 + 1] - a)  # twice the area, along the front
		total += normal.y / 2.0
	return total


func test_every_delivered_model_has_a_name_the_game_looks_for() -> void:
	var known := _all_names()
	for name in _delivered():
		assert_bool(known.has(name)).override_failure_message("%s.glb: no piece of the game has this name (a typo is a model that is never used)" % name).is_true()


func test_every_delivered_model_loads_inside_its_tile_and_within_its_budget() -> void:
	var library := ModelLibrary.new()
	for name in _delivered():
		var mesh := library.mesh(name)
		assert_object(mesh).override_failure_message("%s.glb does not load" % name).is_not_null()
		var box := mesh.get_aabb()
		assert_float(box.position.x).override_failure_message("%s: beyond the tile on the left" % name).is_greater_equal(-0.5)
		assert_float(box.end.x).override_failure_message("%s: beyond the tile on the right" % name).is_less_equal(0.5 + 0.001)
		assert_float(box.position.z).override_failure_message("%s: beyond the tile at the back" % name).is_greater_equal(-0.5)
		assert_float(box.end.z).override_failure_message("%s: beyond the tile at the front" % name).is_less_equal(0.5 + 0.001)
		var triangles := (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		if name.begins_with("terrain_"):
			assert_int(triangles).override_failure_message("%s: %d triangles" % [name, triangles]).is_between(2, TERRAIN_TRIANGLES_MAX)
		elif name.begins_with("unit_"):
			assert_int(triangles).override_failure_message("%s: %d triangles" % [name, triangles]).is_between(150, 400)


func test_a_terrain_tile_faces_up_stands_at_its_height_and_has_a_slab_of_the_right_thickness() -> void:
	var library := ModelLibrary.new()
	for name in _delivered():
		if not name.begins_with("terrain_"):
			continue
		var mesh := library.mesh(name)
		assert_float(_upward_area(mesh)).override_failure_message("%s: its faces look down (inside out): reverse the order of the corners of each triangle" % name).is_greater(0.5)
		var kind: String = name.split("_")[1]
		var box := mesh.get_aabb()
		assert_float(box.end.y).override_failure_message("%s: %.3f high, at most %.2f" % [name, box.end.y, HEIGHT_MAX[kind]]).is_less_equal(HEIGHT_MAX[kind])
		var variant := int(name.right(2)) - 1
		var top := -0.10 if kind == "eau" else (LowPoly.plain_lift(variant) if kind == "plaine" else 0.0)
		assert_float(box.position.y).override_failure_message("%s: the slab goes down to %.3f, %.3f expected (its top %.3f less 0.22)" % [name, box.position.y, top - 0.22, top]).is_equal_approx(top - 0.22, 0.011)
		assert_float(box.size.x).override_failure_message("%s: the slab is %.3f wide, 0.98 expected" % [name, box.size.x]).is_equal_approx(0.98, 0.011)


func test_the_terrain_delivered_so_far_is_complete() -> void:
	var delivered := _delivered()
	for kind in [TerrainGrid.PLAIN, TerrainGrid.FOREST, TerrainGrid.MOUNTAIN, TerrainGrid.WATER]:
		for variant in 3:
			var name := ModelLibrary.terrain_name(kind, variant)
			assert_bool(delivered.has(name)).override_failure_message("%s.glb is missing" % name).is_true()


func test_an_inside_out_mesh_is_caught_by_the_check() -> void:
	var points := PackedVector3Array([Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(0.5, 0, -0.5)])  # (a, c, b) of a top face seen clockwise
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	assert_float(_upward_area(mesh)).is_less(0.0)
	assert_float(_upward_area(ModelLibrary.ready_mesh(mesh))).is_less(0.0)  # making it ready does not flip it
