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
## An older content schema that could not be migrated: the file was set aside (GDD 16 rule 17bis).
const OLDER := &"OLDER"
## A match saved before the last reset of the profile: set aside (GDD 16 AC-18).
const STALE := &"STALE"

var code: StringName = NONE
var state: GameState
var vision: VisionContext
var from_backup := false
## The schema the loaded save was migrated from, 0 when it was current.
var migrated_from := 0
var warnings := PackedStringArray()
