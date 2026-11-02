# "Enregistrer un fragment" (ADR-0004 §5, ruines-fragments.md rule 14): adds a
# fragment to the faction's chronicle in the profile; idempotent by fragment id.
class_name RecordFragmentEffect
extends ProfileEffect

var faction: int
## Stable fragment id, never a position in the pool (GDD 1 rule 10).
var fragment_id: int
## Ruin whose journal entry the command layer validates after a successful write (-1: none).
var ruin_id: int


func _init(p_faction: int, p_fragment_id: int, p_ruin_id: int = -1) -> void:
	faction = p_faction
	fragment_id = p_fragment_id
	ruin_id = p_ruin_id
