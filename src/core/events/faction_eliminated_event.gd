# FACTION_ÉLIMINÉE (GDD 3 rule 10): the faction holds no node any more. Public.
class_name FactionEliminatedEvent
extends PresentationEvent

var eliminated: int


func _init(p_eliminated: int) -> void:
	eliminated = p_eliminated
