# A command (ADR-0004 §1, GDD 23 rule 17): pure data, integers and ids only, no
# logic. One subclass per type; params() and from_params() are its codec.
class_name Command
extends RefCounted

const EMITTER_PLAYER := 0
const EMITTER_AI := 1
const EMITTER_SYS := 2

var faction: int
var emitter: int


func type() -> int:
	assert(false, "Command.type is not implemented")
	return -1


## The type-specific integers, in a fixed order.
func params() -> PackedInt64Array:
	return PackedInt64Array()
