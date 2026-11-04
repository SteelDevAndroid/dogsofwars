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


## The share of the near-vertical faces that look toward the middle of their own piece instead of
## away from it. A solid made right has none; a model written inside out (the walls of the first
## nodes, ruins and units) has all of them. A piece is a set of faces that share corners; two
## pieces that touch (the two horns of a Hunter) count as one, so a correct model can show a few.
static func _inward_share(mesh: Mesh) -> float:
	var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var triangles := points.size() / 3
	var ids := {}
	var parent := PackedInt32Array()
	var corner_id := PackedInt32Array()
	for corner in points.size():
		var key := Vector3i((points[corner] * 1000.0).round())
		if not ids.has(key):
			ids[key] = parent.size()
			parent.append(parent.size())
		corner_id.append(ids[key])
	for triangle in triangles:
		for k in [1, 2]:
			var a := _find(parent, corner_id[triangle * 3])
			var b := _find(parent, corner_id[triangle * 3 + k])
			parent[b] = a
	var centre := {}
	var count := {}
	for triangle in triangles:
		var piece := _find(parent, corner_id[triangle * 3])
		var middle := (points[triangle * 3] + points[triangle * 3 + 1] + points[triangle * 3 + 2]) / 3.0
		centre[piece] = centre.get(piece, Vector3.ZERO) + middle
		count[piece] = count.get(piece, 0) + 1
	var vertical := 0
	var inward := 0
	for triangle in triangles:
		var a := points[triangle * 3]
		var facing := (points[triangle * 3 + 2] - a).cross(points[triangle * 3 + 1] - a).normalized()
		if absf(facing.y) >= 0.5:
			continue
		var piece := _find(parent, corner_id[triangle * 3])
		var middle := (points[triangle * 3] + points[triangle * 3 + 1] + points[triangle * 3 + 2]) / 3.0
		var from_centre: Vector3 = middle - centre[piece] / count[piece]
		vertical += 1
		if Vector2(facing.x, facing.z).dot(Vector2(from_centre.x, from_centre.z)) < 0.0:
			inward += 1
	return float(inward) / maxf(vertical, 1.0)


static func _find(parent: PackedInt32Array, node: int) -> int:
	while parent[node] != node:
		parent[node] = parent[parent[node]]
		node = parent[node]
	return node


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


func test_no_delivered_model_has_its_walls_inside_out() -> void:
	var library := ModelLibrary.new()
	for name in _delivered():
		var share := _inward_share(library.mesh(name))
		assert_float(share).override_failure_message("%s: %.0f %% of its walls look inward (inside out): reverse the order of the corners of each triangle" % [name, share * 100.0]).is_less(0.25)


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


func test_a_model_turned_inside_out_is_caught_by_the_check() -> void:
	var right := ModelLibrary.new().mesh("node_niveau_2")  # delivered right: walls look outward
	assert_object(right).is_not_null()
	assert_float(_inward_share(right)).is_less(0.25)
	var arrays := right.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var flipped := PackedVector3Array()
	for triangle in points.size() / 3:  # every triangle turned over: (a, c, b)
		flipped.append_array([points[triangle * 3], points[triangle * 3 + 2], points[triangle * 3 + 1]])
	var inside_out := []
	inside_out.resize(Mesh.ARRAY_MAX)
	inside_out[Mesh.ARRAY_VERTEX] = flipped
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, inside_out)

	assert_float(_inward_share(mesh)).is_greater(0.75)
