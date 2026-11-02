# Port through which the command layer applies profile effects after the commit
# (ADR-0004 §5): real port in a match, NullProfilePort in replay. Interface by
# convention.
class_name ProfilePort
extends RefCounted


## True when the profile file was written: only then is VALIDER_LA_LECTURE submitted.
## False on a write failure or a read-only profile (ADR-0006 §8).
func apply(_effect: ProfileEffect) -> bool:
	assert(false, "ProfilePort.apply is not implemented")
	return false
