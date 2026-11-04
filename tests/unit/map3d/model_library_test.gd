extends GdUnitTestSuite

const DIR := "user://model_library_test"


## A small model: a white base whose top takes the side's tint (alpha 1) and a grey body (alpha 0).
static func _model_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(-0.3, 0, -0.3), Vector3(0.3, 0, -0.3), Vector3(0.3, 0, 0.3),
			Vector3(-0.3, 0, -0.3), Vector3(0.3, 0, 0.3), Vector3(-0.3, 0, 0.3),
			Vector3(-0.1, 0, 0), Vector3(0.1, 0, 0), Vector3(0, 0.4, 0)]
	for i in points.size():
		st.set_color(Color(0.8, 0.8, 0.8, 1.0 if i < 6 else 0.0))
		st.add_vertex(points[i])
	st.generate_normals()
	return st.commit()


## Writes `name`.glb into the test folder with GLTFDocument, as an artist's export would be.
static func _write_glb(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var root := Node3D.new()
	var instance := MeshInstance3D.new()
	instance.name = "model"
	instance.mesh = _model_mesh()
	root.add_child(instance)
	instance.owner = root
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	document.append_from_scene(root, state)
	document.write_to_filesystem(state, "%s/%s.glb" % [DIR, name])
	root.free()


static func _triangles(mesh: Mesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		count += (indices.size() if indices != null and indices.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return count


func after_test() -> void:
	for name in ["unit_assaut", "terrain_plaine_01", "terrain_plaine_02", "terrain_plaine_03"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s.glb" % [DIR, name]))


func test_a_piece_without_a_model_keeps_the_codes_shape() -> void:
	var models := ModelLibrary.new(DIR)

	assert_object(models.mesh("unit_inconnu")).is_null()
	assert_bool(models.has("unit_inconnu")).is_false()


func test_a_glb_is_read_with_its_faction_mask_in_the_vertex_alpha() -> void:
	_write_glb("unit_assaut")
	var models := ModelLibrary.new(DIR)

	var mesh := models.mesh("unit_assaut")

	assert_object(mesh).is_not_null()
	assert_int(_triangles(mesh)).is_equal(3)
	var colors := mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
	var alphas := {}
	for color in colors:
		alphas[snappedf(color.a, 0.01)] = true
	assert_bool(alphas.has(1.0) and alphas.has(0.0)).override_failure_message("alpha values %s" % [alphas.keys()]).is_true()
	assert_object(models.mesh("unit_assaut")).is_same(mesh)  # cached


func test_the_names_follow_the_asset_specs() -> void:
	assert_str(ModelLibrary.terrain_name(TerrainGrid.FOREST, 1)).is_equal("terrain_foret_02")
	assert_str(ModelLibrary.terrain_name(TerrainGrid.WATER, 2)).is_equal("terrain_eau_03")
	assert_str(ModelLibrary.node_name(3)).is_equal("node_niveau_3")
	assert_str(ModelLibrary.ruin_name(2)).is_equal("ruin_dome_brise_01")
	assert_str(ModelLibrary.unit_name("rempart", false)).is_equal("unit_rempart")
	assert_str(ModelLibrary.unit_name("rempart", true)).is_equal("unit_rempart_endormi")


func test_the_map_uses_a_delivered_model_with_its_mask_and_the_codes_shape_elsewhere() -> void:
	var plain := ModelLibrary.terrain_name(TerrainGrid.PLAIN, TileRenderer.variant_of(0))
	_write_glb("unit_assaut")
	_write_glb(plain)
	var view := MapView3D.new()
	view.models = ModelLibrary.new(DIR)
	view.set_unit_types({1: ["assaut", false], 5: ["chasseur", true]})
	add_child(view)
	var s := TileSnapshot.new()
	s.columns = 2
	s.rows = 1
	s.terrain = PackedByteArray([TerrainGrid.PLAIN, TerrainGrid.PLAIN])
	s.fog = PackedByteArray([VisionService.FOG_VISIBLE, VisionService.FOG_VISIBLE])
	s.owners = PackedByteArray([Faction.PLAYER, Faction.NONE])
	s.units = [[0, 0, Faction.PLAYER, 1, 8, 8, false, false, false], [1, 1, Faction.AI, 5, 8, 8, false, false, false]]

	view.show_snapshot(s)

	var assault: MeshInstance3D = view.units[0]
	assert_object(assault.mesh).is_same(view.models.mesh("unit_assaut"))
	var material := assault.material_override as ShaderMaterial
	assert_bool(material.get_shader_parameter(&"use_mask")).is_true()
	assert_object(material.get_shader_parameter(&"tint")).is_equal(TilePalette.PLAYER)
	assert_object(material.next_pass).is_not_null()  # the outline hull stays
	var hunter: MeshInstance3D = view.units[1]
	assert_object(hunter.mesh).is_not_same(view.models.mesh("unit_assaut"))  # no chasseur model: the code's shape
	assert_object(view.tiles[0].mesh).is_same(view.models.mesh(plain))
	if ModelLibrary.terrain_name(TerrainGrid.PLAIN, TileRenderer.variant_of(1)) != plain:
		assert_object(view.tiles[1].mesh).is_not_same(view.models.mesh(plain))  # another variant: the code's shape
	view.free()
