# TOUR_TERMINÉ (GDD 23): the faction has ended its phase of `turn`. Public.
class_name TurnEndedEvent
extends PresentationEvent

var turn: int
var turn_faction: int


func _init(p_turn: int, p_faction: int) -> void:
	turn = p_turn
	turn_faction = p_faction
