# TestSessionFactory (ADR-0008 §8, ADR-0011 §4): the same SessionFactory with test doubles
# (in-memory data and files with fault injection, recording sink and profile).
class_name TestSessionFactory
extends RefCounted

var app: AppContext
var files := FaultInjectingFileStore.new()
var profile := RecordingProfilePort.new()
var sink := EventQueue.new()
var runner := AiRunner.new()
var ai_port: NodeAiRunnerPort
var ports: SessionPorts
var session: GameSession


func _init(p_files: FaultInjectingFileStore = null) -> void:
	if p_files != null:
		files = p_files
	var documents := CatalogFactory.documents()
	var texts := {}
	for name: String in documents:
		texts[name] = JSON.stringify(documents[name])
	app = AppContext.create(MemoryDataSource.new(texts), files, profile, "user://")
	assert(app.is_ready(), "the test catalog must load")
	ai_port = NodeAiRunnerPort.new(runner)
	ports = SessionPorts.new(sink, ImmediatePacingGate.new())


func map() -> MapDefinition:
	return shipped_map(app.catalog)


static func shipped_map(catalog: DataCatalog) -> MapDefinition:
	var errors: Array[DataError] = []
	var parsed := MapDefinition.parse(FileAccess.get_file_as_string("res://assets/data/maps/plaine.json"), "plaine.json", catalog, errors)
	assert(parsed != null, "the shipped map must be valid")
	return parsed


## The runner is a Node: free it when the test is done.
func dispose() -> void:
	runner.free()


func new_game(seed_value: int = 1) -> GameSession:
	session = SessionFactory.new_game(app, map(), seed_value, ports, ai_port)
	return session


func resume() -> GameSession:
	var reason := [LoadResult.NONE]
	session = SessionFactory.resume(app, ports, ai_port, reason)
	return session


## Drives the runner until the AI phase is over (the session's turn system then opens the
## player's next turn).
func run_ai(max_steps: int = 600) -> void:
	for step in max_steps:
		if not runner.is_running():
			return
		runner.advance()
