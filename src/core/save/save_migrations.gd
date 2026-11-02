# Migrations of the match save (GDD 16 rule 17bis, ADR-0006 §3): one pure, deterministic step
# per schema increment, `N -> N + 1`, chained. A step takes the decoded payload (the array of
# columns) and returns it in the next layout, or null when it cannot guarantee the resumed match.
# `FIRST_SUPPORTED` is the oldest schema that can be migrated; anything older is set aside by
# the store. Raising GameState.SCHEMA_VERSION without adding its step fails
# `test_every_schema_increment_has_a_migration` (the CI gate of rule 17bis).
class_name SaveMigrations
extends RefCounted

const FIRST_SUPPORTED := 2


static func has_step(from_schema: int) -> bool:
	return from_schema == 2


## The payload of a save of `from_schema` brought to GameState.SCHEMA_VERSION, or an empty array
## when there is no chain or a step refuses. The input is never modified.
static func migrate(payload: PackedByteArray, from_schema: int) -> PackedByteArray:
	if from_schema < FIRST_SUPPORTED or from_schema >= GameState.SCHEMA_VERSION:
		return PackedByteArray()
	var data: Variant = bytes_to_var(payload)
	if typeof(data) != TYPE_ARRAY:
		return PackedByteArray()
	var current: Array = data
	for schema in range(from_schema, GameState.SCHEMA_VERSION):
		if not has_step(schema):
			return PackedByteArray()
		var next: Variant = _step(schema, current)
		if next == null:
			return PackedByteArray()
		current = next
	return var_to_bytes(current)


static func _step(from_schema: int, data: Array) -> Variant:
	match from_schema:
		2:
			return _v2_to_v3(data)
	return null


## v3 adds the turn of the last announcement to the AI cursor ([cursor] -> [cursor, turn]).
## A match saved in the middle of the enemy phase is refused: the cursor cannot say whether the
## announcement was made, and a resumed phase would announce twice (GDD 16 rule 17bis).
static func _v2_to_v3(data: Array) -> Variant:
	var probe := GameState.new()
	var offset := 1
	for slice in probe.slices():
		if slice == probe.ai_cursor:
			break
		offset += slice.columns().size()
	if data.size() <= offset or typeof(data[offset]) != TYPE_PACKED_INT32_ARRAY or data[offset].size() != 1:
		return null
	var migrated := data.duplicate()
	migrated[offset] = PackedInt32Array([data[offset][0], -1])
	var state := GameState.from_bytes(var_to_bytes(migrated), GameState.SCHEMA_VERSION)
	if state == null or state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_ENEMY_EXECUTION:
		return null
	return migrated
