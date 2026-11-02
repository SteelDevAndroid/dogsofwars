# Replay log (ADR-0004 §10): every applied command, whatever its emitter, in
# revision order; refused commands are not logged. Tests and dev logs only.
class_name CommandLog
extends RefCounted

const FORMAT_VERSION := 1

var format_version := FORMAT_VERSION
## Hash of the data catalog (ADR-0009 §7): a replay with other data is flagged.
var content_hash: String
var commands: Array[PackedInt64Array] = []


func _init(p_content_hash: String = "") -> void:
	content_hash = p_content_hash


func append(command: Command) -> void:
	commands.append(CommandCodec.encode(command))
