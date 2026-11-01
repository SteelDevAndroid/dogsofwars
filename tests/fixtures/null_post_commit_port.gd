# PostCommitPort of the replay (ADR-0004 §10): saves nothing.
class_name NullPostCommitPort
extends PostCommitPort


func on_commit(_state: GameState, _command: Command, _result: ApplyResult) -> void:
	pass
