# What SaveStore.load_match returns (ADR-0006 §3): the state and its vision context, or
# the reason there is none.
class_name LoadResult
extends RefCounted

const OK := &"OK"
## No save file at all.
const NONE := &"NONE"
## Every candidate is damaged: the game starts without a match.
const CORRUPT := &"CORRUPT"
## A save of a newer content schema: left untouched, never fallen back from (ADR-0006 §3).
const NEWER := &"NEWER"
## An older content schema: set aside before the closed test (ADR-0006 §3).
const OLDER := &"OLDER"

var code: StringName = NONE
var state: GameState
var vision: VisionContext
var from_backup := false
var warnings := PackedStringArray()
