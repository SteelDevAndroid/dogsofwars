# TOUR_COMMENCÉ (GDD 23): turn number, faction whose phase begins, new phase.
# Public: it belongs to no faction and passes the fog filter.
class_name TurnStartedEvent
extends PresentationEvent

var turn: int
var turn_faction: int
var phase: int


func _init(p_turn: int, p_faction: int, p_phase: int) -> void:
	turn = p_turn
	turn_faction = p_faction
	phase = p_phase
