# AiRunnerPort over the AiRunner node of the match scene.
class_name NodeAiRunnerPort
extends AiRunnerPort

var _runner: AiRunner


func _init(runner: AiRunner) -> void:
	_runner = runner


func start_turn(state: GameState, pipeline: CommandPipeline, pacing: PacingGate, catalog: DataCatalog) -> void:
	_runner.on_turn_finished = on_turn_finished
	_runner.start_turn(state, pipeline, pacing, catalog)


func resume(state: GameState, pipeline: CommandPipeline, pacing: PacingGate, catalog: DataCatalog) -> void:
	_runner.on_turn_finished = on_turn_finished
	_runner.resume(state, pipeline, pacing, catalog)


func cancel() -> void:
	if is_instance_valid(_runner):
		_runner.cancel()
		_runner.on_turn_finished = Callable()


func is_running() -> bool:
	return is_instance_valid(_runner) and _runner.is_running()
