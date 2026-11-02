# PROPRIÉTAIRE_DES_TUILES_CHANGÉ (GDD 11 rule 7): one per (old, new) pair. A change
# that takes or gives the player a tile always reaches the player, even out of view
# (GDD 5 rule 5 exception); otherwise it belongs to the new owner and is filtered by
# the fog.
class_name TileOwnersChangedEvent
extends PresentationEvent

var changed_tiles: PackedInt32Array
var old_owner: int
var new_owner: int


func _init(p_tiles: PackedInt32Array, p_old: int, p_new: int) -> void:
	changed_tiles = p_tiles
	old_owner = p_old
	new_owner = p_new
	var concerns_player := p_old == Faction.PLAYER or p_new == Faction.PLAYER
	faction = Faction.PLAYER if concerns_player else p_new


func tiles() -> PackedInt32Array:
	return changed_tiles
