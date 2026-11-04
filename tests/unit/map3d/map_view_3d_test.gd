extends GdUnitTestSuite

const KEYS := ["eclaireur", "assaut", "rempart", "ouvrier", "sentinelle", "chasseur", "bastion"]


static func _triangles(mesh: ArrayMesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		count += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return count


## 3 x 2: a mountain the player has seen, an undiscovered mountain with a Guardian on it, an
## explored forest with a Guardian on it; below, the player's Assaut, a Guardian in view, a plain.
func _snapshot() -> TileSnapshot:
	var s := TileSnapshot.new()
	s.columns = 3
	s.rows = 2
	s.terrain = PackedByteArray([TerrainGrid.MOUNTAIN, TerrainGrid.MOUNTAIN, TerrainGrid.FOREST, TerrainGrid.PLAIN, TerrainGrid.PLAIN, TerrainGrid.PLAIN])
	s.fog = PackedByteArray([VisionService.FOG_VISIBLE, VisionService.FOG_UNDISCOVERED, VisionService.FOG_EXPLORED,
			VisionService.FOG_VISIBLE, VisionService.FOG_VISIBLE, VisionService.FOG_VISIBLE])
	s.owners = PackedByteArray([Faction.PLAYER, Faction.NONE, Faction.AI, Faction.PLAYER, Faction.AI, Faction.NONE])
	s.units = [[0, 3, Faction.PLAYER, 1, 8, 8, false, false, false], [1, 4, Faction.AI, 5, 8, 8, false, false, false],
			[2, 1, Faction.AI, 6, 14, 14, false, false, false], [3, 2, Faction.AI, 5, 8, 8, false, false, false]]
	return s


func _view() -> MapView3D:
	var view := MapView3D.new()
	var types := {}
	for type in KEYS.size():
		types[type] = [KEYS[type], type >= 4]
	view.set_unit_types(types)
	add_child(view)
	return view


func test_every_piece_is_low_poly_and_a_unit_stays_in_the_art_bibles_budget() -> void:
	for kind in [TerrainGrid.PLAIN, TerrainGrid.FOREST, TerrainGrid.MOUNTAIN, TerrainGrid.WATER]:
		for variant in 3:
			assert_int(_triangles(LowPoly.terrain(kind, variant))).is_between(2, 300)
	for key: String in KEYS:
		for asleep in [false, true]:
			assert_int(_triangles(LowPoly.unit(key, TilePalette.PLAYER, KEYS.find(key) >= 4, asleep))).override_failure_message(key).is_between(20, 400)
	for level in [1, 2, 3]:
		assert_int(_triangles(LowPoly.node(level, TilePalette.PLAYER))).is_less(200)
	assert_int(_triangles(LowPoly.ruin(false, 0))).is_less(200)


func test_an_undiscovered_tile_is_the_fog_slab_and_a_hostile_unit_out_of_view_is_not_drawn() -> void:
	var view := _view()

	view.show_snapshot(_snapshot())

	var fog_mesh: Mesh = view.tiles[1].mesh
	assert_object(fog_mesh).is_same(view.tiles[1].mesh)
	assert_int(_triangles(fog_mesh)).is_equal(12)  # a plain box: nothing of the mountain under it
	assert_bool(fog_mesh != view.tiles[0].mesh).is_true()
	assert_int(view.units.size()).is_equal(2)  # the player's Assaut and the Guardian in view, not the two in the fog
	var drawn := view.units.map(func(unit: MeshInstance3D) -> Vector3: return unit.position.round())
	assert_bool(drawn.has(MapView3D.center_of_tile(4, 3).round())).is_true()
	view.free()


func test_an_owned_tile_takes_its_sides_tint_and_a_remembered_one_is_dimmed() -> void:
	var view := _view()

	view.show_snapshot(_snapshot())

	var owned := view.tiles[0].material_override as ShaderMaterial
	assert_float(owned.get_shader_parameter(&"strength")).is_equal(1.0)
	assert_object(owned.get_shader_parameter(&"tint")).is_equal(TilePalette.PLAYER)
	assert_float((view.tiles[5].material_override as ShaderMaterial).get_shader_parameter(&"strength")).is_equal(0.0)
	assert_float((view.tiles[2].material_override as ShaderMaterial).get_shader_parameter(&"memory")).is_equal(1.0)
	view.free()


func test_the_focus_keeps_the_map_in_the_area_and_centres_a_small_map() -> void:
	assert_vector(MapView3D.clamp_focus(Vector2(0, 0), 8.0, 6.0, 12, 12)).is_equal(Vector2(3.5, 2.5))
	assert_vector(MapView3D.clamp_focus(Vector2(12, 12), 8.0, 6.0, 12, 12)).is_equal(Vector2(8.5, 9.5))
	assert_vector(MapView3D.clamp_focus(Vector2(6, 6), 8.0, 6.0, 12, 12)).is_equal(Vector2(6, 6))
	assert_vector(MapView3D.clamp_focus(Vector2(0, 0), 20.0, 20.0, 12, 12)).is_equal(Vector2(6, 6))


func test_the_tile_under_the_centre_of_the_area_is_the_focused_one() -> void:
	var view := _view()
	view.show_snapshot(_snapshot())
	var viewport := Vector2(1200, 300)  # wide: the focus is not moved by the clamp

	view.frame_camera(Rect2(Vector2.ZERO, viewport), viewport, 3.0, Vector2(1.5, 0.5))

	assert_int(view.tile_at(viewport / 2.0)).is_equal(1)
	assert_int(view.tile_at(viewport / 2.0 + Vector2(viewport.x / 3.0, 0))).is_equal(2)  # one column to the right
	assert_int(view.tile_at(Vector2(-5000, -5000))).is_equal(-1)
	view.free()
