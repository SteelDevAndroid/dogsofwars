# RECHERCHE_TERMINÉE (GDD 12 rule 6): faction, protocol. No tile: the AI's never
# reaches the player.
class_name ResearchCompletedEvent
extends PresentationEvent

var protocol: int


func _init(p_faction: int, p_protocol: int) -> void:
	faction = p_faction
	protocol = p_protocol
