# Port called after every command applied by the real pipeline, before the profile
# and the event push (ADR-0004 §4): the save coordinator in a match, a null port in
# replay. Interface by convention.
class_name PostCommitPort
extends RefCounted


func on_commit(_state: GameState, _command: Command, _result: ApplyResult) -> void:
	assert(false, "PostCommitPort.on_commit is not implemented")
