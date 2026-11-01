# Edits a serialized state column by column, to build states the setup cannot
# (corrupt payloads, a given revision) without writing a private field.
class_name StatePayload
extends RefCounted


## Index of a column in the to_bytes payload (index 0 is the terrain).
static func column_index(state: GameState, column: StringName) -> int:
	var index := 1
	for slice in state.slices():
		for spec: Array in slice.columns():
			if spec[0] == column:
				return index
			index += 1
	assert(false, "unknown column %s" % column)
	return -1


## Payload of `state` with one column replaced.
static func with_column(state: GameState, column: StringName, value: Variant) -> PackedByteArray:
	var data: Array = bytes_to_var(state.to_bytes())
	data[column_index(state, column)] = value
	return var_to_bytes(data)


## Decoded state with one column replaced, or null when from_bytes refuses it.
static func decoded_with(state: GameState, column: StringName, value: Variant) -> GameState:
	return GameState.from_bytes(with_column(state, column, value), GameState.SCHEMA_VERSION)
