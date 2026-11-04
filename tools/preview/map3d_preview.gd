# Screenshots of the map, 2D (TileRenderer, the shipped drawing) and 3D (MapView3D, the
# prototype), with the real HUD over it, on the same game: "plaine", a few turns of the scripted
# player against the AI, a unit of the player selected with its move range. Needs a display
# (xvfb-run) and the project imported. Usage:
#   xvfb-run -a godot --rendering-driver opengl3 --resolution 780x1688 -s tools/preview/map3d_preview.gd -- 3d portrait out.png [rounds]
# The window is twice the HUD's points (390 x 844 portrait, 844 x 390 landscape).
extends SceneTree

const SEED := 6


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "3d"
	var landscape := args.size() > 1 and args[1] == "landscape"
	var out := args[2] if args.size() > 2 else "user://map_%s.png" % mode
	var rounds := int(args[3]) if args.size() > 3 else 6
	var points := Vector2(844, 390) if landscape else Vector2(390, 844)
	var catalog := CatalogFactory.standard()
	if mode == "gallery":
		await _gallery(catalog, out)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(points)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var fx := _play(catalog, rounds)
	var state := fx.state
	var view := FactionView.new(state, Faction.PLAYER)
	var selected := -1
	for id in view.unit_ids():
		if view.unit_faction(id) == Faction.PLAYER:
			selected = id
			break
	var reachable := fx.pipeline.check_move_range(view, Faction.PLAYER, selected) if selected >= 0 else PackedInt32Array()

	var hud := Hud.new()
	var layer := CanvasLayer.new()
	layer.add_child(hud)
	root.add_child(layer)
	hud.show_model(HudModel.build(state, catalog, false, selected, [], {"undo": fx.pipeline.check(UndoMoveCommand.new())}))
	await process_frame
	var needs := hud.measure()
	var layout := HudLayout.compute(points, Rect2(Vector2.ZERO, points), needs.x, needs.y)
	hud.apply_layout(layout)
	var camera := MapCamera.new(state.width(), state.height(), layout.map_area)
	var focus_tile := view.unit_tile(selected) if selected >= 0 else 0
	camera.start_recenter(focus_tile, 0.0, 0.0)
	camera.tick(1.0)

	if mode == "2d":
		var renderer := TileRenderer.new()
		var world := Node2D.new()
		world.add_child(renderer)
		root.add_child(world)
		root.move_child(world, 0)
		renderer.show_state(state, catalog)
		renderer.layout = camera.layout()
		renderer.set_clip_rect(camera.area)
		renderer.set_selection(view.unit_tile(selected), reachable)
	else:
		var map := MapView3D.new()
		var types := {}
		for type in catalog.units.count():
			types[type] = [catalog.units.key(type), catalog.units.side(type) != catalog.units.side(0)]
		map.set_unit_types(types)
		root.add_child(map)
		map.show_snapshot(TileSnapshot.take(state, catalog))
		map.set_selection(view.unit_tile(selected), reachable)
		# the same zoom and centre as the 2D map: as many columns across the map area
		map.frame_camera(_scaled(layout.map_area, points), Vector2(root.size), layout.map_area.size.x / camera.tile_size, camera.center)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("saved ", out, " turn ", state.turn(), " size ", root.size)
	quit()


## Every piece side by side, close: terrains (plain, forest, mountain, water, then owned by the
## pack and by the Guardians, then remembered), the seven units, the nodes and a ruin.
func _gallery(catalog: DataCatalog, out: String) -> void:
	var s := TileSnapshot.new()
	s.columns = 7
	s.rows = 3
	var terrains := [TerrainGrid.PLAIN, TerrainGrid.FOREST, TerrainGrid.MOUNTAIN, TerrainGrid.WATER, TerrainGrid.FOREST, TerrainGrid.PLAIN, TerrainGrid.MOUNTAIN]
	for tile in 21:
		var column := tile % 7
		s.terrain.append(terrains[column] if tile < 7 else (TerrainGrid.PLAIN if tile < 14 else [TerrainGrid.PLAIN, TerrainGrid.FOREST][column % 2]))
		s.fog.append(VisionService.FOG_EXPLORED if tile == 6 else (VisionService.FOG_UNDISCOVERED if tile == 20 else VisionService.FOG_VISIBLE))
		s.owners.append(Faction.PLAYER if tile in [4, 7, 8, 9, 10, 15] else (Faction.AI if tile in [5, 11, 12, 13, 17] else Faction.NONE))
	for type in 7:
		s.units.append([type, 7 + type, Faction.PLAYER if type < 4 else Faction.AI, type, 5, 8, false, false, false])
	s.units.append([9, 3, Faction.NONE, 1, 5, 8, true, false, false])
	s.nodes = [[14, Faction.NONE, 1, true], [15, Faction.PLAYER, 2, true], [17, Faction.AI, 3, true]]
	s.ruins = [[18, false], [19, true]]
	s.threats = [[0, 0, 16, -1, 0]]
	var map := MapView3D.new()
	var types := {}
	for type in catalog.units.count():
		types[type] = [catalog.units.key(type), catalog.units.side(type) != catalog.units.side(0)]
	map.set_unit_types(types)
	root.add_child(map)
	map.show_snapshot(s)
	map.set_selection(9, PackedInt32Array([2, 16]))
	map.frame_camera(Rect2(Vector2.ZERO, Vector2(root.size)), Vector2(root.size), 7.4, Vector2(3.5, 1.5))
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()


## A rectangle of the HUD's points in the window's pixels.
static func _scaled(area: Rect2, points: Vector2) -> Rect2:
	var factor := Vector2(DisplayServer.window_get_size()) / points
	return Rect2(area.position * factor, area.size * factor)


static func _play(catalog: DataCatalog, rounds: int) -> PipelineFixture:
	var errors: Array[DataError] = []
	var map := MapDefinition.parse(FileAccess.get_file_as_string("res://assets/data/maps/plaine.json"), "plaine.json", catalog, errors)
	var fx := PipelineFixture.new(GameStateFactory.new_game(catalog, map, SEED), true)
	var bot := ScriptedPlayer.new()
	for round in rounds:
		fx.begin_turn(Faction.PLAYER)
		bot.play_turn(fx.state, fx.pipeline, catalog)
		fx.end_turn()
		fx.begin_turn(Faction.AI)
		var runner := AiRunner.new()
		runner.start_turn(fx.state, fx.pipeline, AlwaysReadyPacingGate.new(), catalog)
		for step in 600:
			if not runner.is_running():
				break
			runner.advance()
		runner.free()
	fx.begin_turn(Faction.PLAYER)
	return fx
