# ÉNERGIE_CHANGÉE (GDD 10 rule 11): faction, stock before, after. No tile: an event
# of the other faction never passes the player's fog filter.
class_name EnergyChangedEvent
extends PresentationEvent

var before: int
var after: int


func _init(p_faction: int, p_before: int, p_after: int) -> void:
	faction = p_faction
	before = p_before
	after = p_after
