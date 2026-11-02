# Start of the game and flow between the screens (ADR-0008 §1 to §6): builds the AppContext
# (catalog, files, profile) in order, then shows the data-error screen or the main menu; a
# new game or a continued one builds a MatchScreen and a session through SessionFactory; the
# end of a match shows the end screen; leaving tears the match down in the ADR sequence.
# Dependencies are injectable before `_ready` (tests); by default the real ones.
class_name Bootstrap
extends Node

const MAP_FILE := "maps/plaine.json"

var data_source: DataSource
var file_store: FileStore
var save_dir := "user://"
## A fixed seed for the next new game, -1 for a random one.
var forced_seed := -1

var app: AppContext
var profile: ProfileStore
var match_screen: MatchScreen
## The screen being shown (main menu, end screen, error screen), or null during a match.
var screen: Control

var _ui: CanvasLayer
var _pause: PauseMenu
var _ending := false


func _ready() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	data_source = data_source if data_source != null else ResDataSource.new()
	file_store = file_store if file_store != null else RealFileStore.new()
	profile = ProfileStore.new(file_store, save_dir)
	profile.load_profile()
	app = AppContext.create(data_source, file_store, profile, save_dir)
	if app.is_ready():
		show_menu()
	else:
		_show_data_errors(app.errors)


func _process(_delta: float) -> void:
	if match_screen != null and match_screen.session != null and match_screen.session.is_over() and not _ending:
		_show_end()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if match_screen != null and not _ending:
			toggle_pause()
		elif screen is MainMenu:
			get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED and match_screen != null and match_screen.session != null:
		(match_screen.session.post_commit as SaveCoordinator).retry(match_screen.session.state)


func show_menu() -> void:
	var menu := MainMenu.new()
	var best := profile.best_score(Faction.PLAYER, SubmitScoreEffect.DIFFICULTY_STANDARD)
	menu.configure(app.save_store.has_match(), best)
	menu.continue_requested.connect(continue_match)
	menu.new_game_requested.connect(start_new_game)
	menu.quit_requested.connect(func() -> void: get_tree().quit())
	_show(menu)


func start_new_game() -> void:
	var errors: Array[DataError] = []
	var map := MapDefinition.parse(data_source.read_text(MAP_FILE), MAP_FILE, app.catalog, errors)
	if map == null:
		_show_data_errors(errors)
		return
	_leave_match()
	var seed_value := forced_seed if forced_seed >= 0 else randi()
	var screen_node := _new_match_screen()
	var session := SessionFactory.new_game(app, map, seed_value, screen_node.ports(EventQueue.new(app.catalog.presentation.value("queue_max"))), screen_node.runner_port(),
			false, profile.chronicle(), profile.next_match_id(), profile.epoch)
	_bind(screen_node, session)


func continue_match() -> void:
	_leave_match()
	var screen_node := _new_match_screen()
	var reason := [LoadResult.NONE]
	var session := SessionFactory.resume(app, screen_node.ports(EventQueue.new(app.catalog.presentation.value("queue_max"))), screen_node.runner_port(), reason)
	if session == null:
		screen_node.free()
		show_menu()  # nothing to continue: the menu offers a new game
		return
	_bind(screen_node, session)


func toggle_pause() -> void:
	if _pause != null:
		_pause.queue_free()
		_pause = null
		return
	_pause = PauseMenu.new()
	_pause.resume_requested.connect(toggle_pause)
	_pause.menu_requested.connect(_to_menu_keeping_match)
	_pause.abandon_requested.connect(abandon_match)
	_ui.add_child(_pause)


func abandon_match() -> void:
	if match_screen != null and match_screen.session != null:
		match_screen.session.pipeline.submit(AbandonCommand.new())
	if _pause != null:
		toggle_pause()


## From the end screen: the finished match is erased, then the menu.
func leave_finished_match() -> void:
	app.save_store.delete_match()
	_leave_match()
	show_menu()


func _to_menu_keeping_match() -> void:
	_leave_match()
	show_menu()


func _new_match_screen() -> MatchScreen:
	var node: MatchScreen = load("res://src/app/match_screen.tscn").instantiate()
	add_child(node)
	node.pause_requested.connect(toggle_pause)
	return node


func _bind(node: MatchScreen, session: GameSession) -> void:
	_clear_screen()
	match_screen = node
	_ending = false
	node.bind(session)


func _show_end() -> void:
	_ending = true
	var state := match_screen.session.state
	var weights := app.catalog.score
	var end := EndScreen.new()
	end.show_result(state.header.value(HeaderSlice.END_STATUS), ScoreRules.decisive(state, Faction.PLAYER, weights),
			ScoreRules.decisive(state, Faction.AI, weights))
	end.back_requested.connect(leave_finished_match)
	_show(end)


func _show_data_errors(errors: Array[DataError]) -> void:
	var error_screen := DataErrorScreen.new()
	error_screen.show_errors(errors)
	error_screen.quit_requested.connect(func() -> void: get_tree().quit())
	_show(error_screen)


func _show(new_screen: Control) -> void:
	_clear_screen()
	screen = new_screen
	_ui.add_child(new_screen)


func _clear_screen() -> void:
	if screen != null:
		screen.queue_free()
		screen = null
	if _pause != null:
		_pause.queue_free()
		_pause = null


func _leave_match() -> void:
	if match_screen != null:
		match_screen.shutdown()
		match_screen = null
	_ending = false
	_clear_screen()
