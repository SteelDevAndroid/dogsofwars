# Migrations of the match save (GDD 16 rule 17bis, ADR-0006 §3): one pure, deterministic step
# per schema increment, `N -> N + 1`, chained. A step takes the decoded payload (the array of
# columns) and returns it in the next layout, or null when it cannot guarantee the resumed match.
# `FIRST_SUPPORTED` is the oldest schema that can be migrated; anything older is set aside by
# the store. Raising GameState.SCHEMA_VERSION without adding its step fails
# `test_every_schema_increment_has_a_migration` (the CI gate of rule 17bis).
class_name SaveMigrations
extends RefCounted

const FIRST_SUPPORTED := 2
## Columns that schema 4 added to the units slice.
const V4_UNIT_COLUMNS := 3


static func has_step(from_schema: int) -> bool:
	return from_schema == 2 or from_schema == 3


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
		3:
			return _v3_to_v4(data)
	return null


## v3 adds the turn of the last announcement to the AI cursor ([cursor] -> [cursor, turn]).
## A match saved in the middle of the enemy phase is refused: the cursor cannot say whether the
## announcement was made, and a resumed phase would announce twice (GDD 16 rule 17bis).
static func _v2_to_v3(data: Array) -> Variant:
	var probe := GameState.new()
	var offset := 1 - V4_UNIT_COLUMNS  # this step reads the layout of schema 2, before the units grew
	for slice in probe.slices():
		if slice == probe.ai_cursor:
			break
		offset += slice.columns().size()
	if data.size() <= offset or typeof(data[offset]) != TYPE_PACKED_INT32_ARRAY or data[offset].size() != 1:
		return null
	var migrated := data.duplicate()
	migrated[offset] = PackedInt32Array([data[offset][0], -1])
	# Checked in the layout of the latest schema (the step after this one only adds columns).
	var latest: Variant = _v3_to_v4(migrated)
	var state := GameState.from_bytes(var_to_bytes(latest), GameState.SCHEMA_VERSION) if latest != null else null
	if state == null or state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_ENEMY_EXECUTION:
		return null
	return migrated


## v4 adds three byte columns to the units (ability cooldown, ability effect on, ambush), all
## zero: a resumed match has no ability in use and no unit in ambush until its next turn starts.
static func _v3_to_v4(data: Array) -> Variant:
	const OLD_UNIT_COLUMNS := 9
	assert(UnitsSlice.COLUMNS.size() == OLD_UNIT_COLUMNS + V4_UNIT_COLUMNS, "the units slice changed after schema 4: add a step")
	var probe := GameState.new()
	var offset := 1  # the terrain comes first
	for slice in probe.slices():
		if slice == probe.units:
			break
		offset += slice.columns().size()
	if data.size() < offset + OLD_UNIT_COLUMNS or typeof(data[offset]) != TYPE_PACKED_INT32_ARRAY:
		return null
	var rows: int = data[offset].size()
	var migrated := data.slice(0, offset + OLD_UNIT_COLUMNS)
	for added in 3:
		var zeros := PackedByteArray()
		zeros.resize(rows)
		migrated.append(zeros)
	migrated.append_array(data.slice(offset + OLD_UNIT_COLUMNS))
	return migrated
