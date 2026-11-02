# Balance run: whole matches of the AI against the scripted player over many seeds, with the
# shipped data, printing the outcomes. Usage:
#   godot --headless -s tests/balance/run_matches.gd -- [first_seed] [count]
# Further arguments override data (see _catalog). Output: one line per match, then the totals (JSON-ish, for a spreadsheet).
extends SceneTree

const MAX_ROUNDS := 35


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 1
	var count := int(args[1]) if args.size() > 1 else 20
	var overrides := {}
	for k in range(2, args.size()):  # "file.key=value", e.g. ai.json.w_danger=3 (ai.json: planner weights)
		var pair := args[k].split("=")
		overrides[pair[0]] = int(pair[1])
	var catalog := _catalog(overrides)
	var results := []
	for seed_value in range(first, first + count):
		results.append(play(seed_value, catalog))
		print(JSON.stringify(results[-1]))
	print("SUMMARY ", JSON.stringify(summarize(results)))
	quit()


static func play(seed_value: int, catalog: DataCatalog) -> Dictionary:
	var errors: Array[DataError] = []
	var map := MapDefinition.parse(FileAccess.get_file_as_string("res://assets/data/maps/plaine.json"), "plaine.json", catalog, errors)
	var fx := PipelineFixture.new(GameStateFactory.new_game(catalog, map, seed_value), true)
	var bot := ScriptedPlayer.new()
	var refusals := 0
	var fragments := 0
	for round in MAX_ROUNDS:
		if fx.state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_FINISHED:
			break
		refusals += 0 if fx.begin_turn(Faction.PLAYER).permitted else 1
		if fx.state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_FINISHED:
			break
		bot.play_turn(fx.state, fx.pipeline, catalog)
		if fx.state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_FINISHED:
			break
		refusals += 0 if fx.end_turn().permitted else 1
		refusals += 0 if fx.begin_turn(Faction.AI).permitted else 1
		var runner := AiRunner.new()
		runner.start_turn(fx.state, fx.pipeline, AlwaysReadyPacingGate.new(), catalog)
		for step in 600:
			if not runner.is_running():
				break
			runner.advance()
		refusals += runner.refusals
		runner.free()
	var player_units := 0
	var ai_units := 0
	for unit_id in fx.state.view().unit_ids():
		if fx.state.view().unit_faction(unit_id) == Faction.PLAYER:
			player_units += 1
		elif fx.state.view().unit_faction(unit_id) == Faction.AI:
			ai_units += 1
	var player_nodes := 0
	var ai_nodes := 0
	for node_id in fx.state.view().node_ids():
		if fx.state.view().node_owner(node_id) == Faction.PLAYER:
			player_nodes += 1
		elif fx.state.view().node_owner(node_id) == Faction.AI:
			ai_nodes += 1
	return {"seed": seed_value, "status": fx.state.header.value(HeaderSlice.END_STATUS), "turn": fx.state.turn(),
			"player_units": player_units, "ai_units": ai_units, "player_nodes": player_nodes, "ai_nodes": ai_nodes,
			"ruins_read": fx.state.ruin_journal.read_by(Faction.PLAYER),
			"refusals": refusals, "commands": bot.commands}


static func summarize(results: Array) -> Dictionary:
	var by_status := {}
	var turns := 0
	var refusals := 0
	for r in results:
		by_status[r["status"]] = by_status.get(r["status"], 0) + 1
		turns += r["turn"]
		refusals += r["refusals"]
	return {"matches": results.size(), "by_status": by_status, "mean_turn": float(turns) / maxi(results.size(), 1), "refusals": refusals}


## The shipped data with some values replaced: "ai.json.w_danger" (a planner weight),
## "energie.json.start", "combat.json.dmg_scale"... (a top-level integer or a planner weight).
static func _catalog(overrides: Dictionary) -> DataCatalog:
	var texts := {}
	for file in DirAccess.get_files_at("res://assets/data"):
		texts[file] = FileAccess.get_file_as_string("res://assets/data/" + file)
	texts["maps/plaine.json"] = FileAccess.get_file_as_string("res://assets/data/maps/plaine.json")
	for key: String in overrides:
		var parts := key.split(".json.")
		var doc: Dictionary = JSON.parse_string(texts[parts[0] + ".json"])
		if doc.has(parts[1]):
			doc[parts[1]] = overrides[key]
		else:
			doc["planner"][parts[1]] = overrides[key]
		texts[parts[0] + ".json"] = JSON.stringify(doc)
	var result := DataCatalog.load_all(MemoryDataSource.new(texts))
	assert(result.catalog != null, "the data does not load: %s" % str(result.errors))
	return result.catalog
