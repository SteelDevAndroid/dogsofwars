# A button of the context panel: what it does, whether the pipeline would accept it now, and
# if not why (hud.md: a disabled button says so, and the reason is in the panel).
class_name ContextAction
extends RefCounted

var id: StringName
var label: String
var enabled: bool
var reason: String


func _init(p_id: StringName, p_label: String, p_enabled: bool, p_reason: String = "") -> void:
	id = p_id
	label = p_label
	enabled = p_enabled
	reason = p_reason
