# INTENTION_EXÉCUTÉE (GDD 9 rule 4): the intention was carried out; the attack or capture
# events follow in the same batch. Same visibility as INTENTION_ANNONCÉE.
class_name IntentionExecutedEvent
extends PresentationEvent

var intention_id: int
var author_id: int
var target_tile: int


func _init(p_intention_id: int, p_author_id: int, p_target_kind: int, p_target_tile: int) -> void:
	faction = Faction.NONE if p_target_kind == IntentionsSlice.TARGET_NODE else Faction.AI
	intention_id = p_intention_id
	author_id = p_author_id
	target_tile = p_target_tile


func tiles() -> PackedInt32Array:
	return PackedInt32Array([target_tile])
