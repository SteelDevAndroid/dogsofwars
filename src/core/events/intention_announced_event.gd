# INTENTION_ANNONCÉE (GDD 9 rule 18, GDD 23): one stored intention. An attack belongs
# to the AI: the player sees it when the target tile is visible (the marker is drawn
# on the target tile even when the author is in the fog); a node capture is shown even
# when the node is not visible. `siege` is the announcement count of the
# siege this intention carries (0 when it is not a siege announcement).
class_name IntentionAnnouncedEvent
extends PresentationEvent

var intention_id: int
var author_id: int
var target_kind: int
var target_id: int
var target_tile: int
var motive: int
var siege: int


func _init(p_intention_id: int, p_author_id: int, p_target_kind: int, p_target_id: int, p_target_tile: int,
		p_motive: int, p_siege: int) -> void:
	# GDD 9 rule 18: a node capture is shown even when the node is not visible, so it
	# belongs to nobody (visible to everyone); an attack is the AI's, filtered by the fog.
	faction = Faction.NONE if p_target_kind == IntentionsSlice.TARGET_NODE else Faction.AI
	intention_id = p_intention_id
	author_id = p_author_id
	target_kind = p_target_kind
	target_id = p_target_id
	target_tile = p_target_tile
	motive = p_motive
	siege = p_siege


func tiles() -> PackedInt32Array:
	return PackedInt32Array([target_tile])
