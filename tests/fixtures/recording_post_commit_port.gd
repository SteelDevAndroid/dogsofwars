# PostCommitPort that records the revision and the encoded command of every commit,
# and the events already pushed at that moment (the save precedes the push).
class_name RecordingPostCommitPort
extends PostCommitPort

var revisions := PackedInt64Array()
var commands: Array[PackedInt64Array] = []
var batches_pushed_before := PackedInt32Array()
var _sink: RecordingSink


func _init(sink: RecordingSink = null) -> void:
	_sink = sink


func on_commit(state: GameState, command: Command, _result: ApplyResult) -> void:
	revisions.append(state.revision())
	commands.append(CommandCodec.encode(command))
	batches_pushed_before.append(_sink.batches.size() if _sink != null else 0)
