# PARTIE_TERMINÉE (GDD 23): the end status (HeaderSlice.END_*). Public.
class_name MatchEndedEvent
extends PresentationEvent

var status: int


func _init(p_status: int) -> void:
	status = p_status
