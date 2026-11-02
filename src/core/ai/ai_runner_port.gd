# Port the turn system uses to drive the AI runner (ADR-0008 §4): the runner is a Node in the
# match scene, the turn system a plain object. Interface by convention.
class_name AiRunnerPort
extends RefCounted

## Called once the AI phase is finished.
var on_turn_finished: Callable


func start_turn(_state: GameState, _pipeline: CommandPipeline, _pacing: PacingGate, _catalog: DataCatalog) -> void:
	assert(false, "AiRunnerPort.start_turn is not implemented")


func resume(_state: GameState, _pipeline: CommandPipeline, _pacing: PacingGate, _catalog: DataCatalog) -> void:
	assert(false, "AiRunnerPort.resume is not implemented")


func cancel() -> void:
	assert(false, "AiRunnerPort.cancel is not implemented")


func is_running() -> bool:
	assert(false, "AiRunnerPort.is_running is not implemented")
	return false
