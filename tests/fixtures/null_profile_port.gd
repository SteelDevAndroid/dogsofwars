# ProfilePort of the replay (ADR-0004 §10): writes nothing and answers false, so no
# VALIDER_LA_LECTURE is submitted twice: the replayed log already holds it.
class_name NullProfilePort
extends ProfilePort


func apply(_effect: ProfileEffect) -> bool:
	return false
