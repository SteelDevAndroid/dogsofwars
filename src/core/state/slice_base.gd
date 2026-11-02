# Generic operations of a game-state slice, derived from its declarative column
# table (ADR-0003): copy, equality, serialization checks and compaction.
# A slice lists its columns in COLUMNS as [name, Variant.Type] pairs; only this
# table drives the generic code, so a new column cannot be forgotten by a copy.
class_name SliceBase
extends RefCounted


## [name: StringName, type: Variant.Type] pairs, in serialization order.
func columns() -> Array:
	assert(false, "SliceBase.columns is not implemented")
	return []


## Column of entity ids, sorted ascending; empty for grids and scalars.
func id_column() -> StringName:
	return &""


## Byte column marking live rows (1) for the end-of-turn compaction; empty if none.
func alive_column() -> StringName:
	return &""


## Faction whose filtered copy alone keeps this slice, or -1 (ADR-0003, ADR-0005 §2).
func private_to() -> int:
	return -1


## Error message when a column length does not fit the map, or "".
func length_error(_tiles: int, _factions: int) -> String:
	return ""


func copy_from(other: SliceBase) -> void:
	for spec: Array in columns():
		set(spec[0], other.get(spec[0]).duplicate())


func values() -> Array:
	var out := []
	for spec: Array in columns():
		out.append(get(spec[0]))
	return out


## Loads columns from deserialized values; false on a type mismatch.
func load_values(data: Array, offset: int) -> bool:
	var specs := columns()
	for k in specs.size():
		if typeof(data[offset + k]) != specs[k][1]:
			return false
	for k in specs.size():
		set(specs[k][0], data[offset + k])
	return true


func row_count() -> int:
	return get(columns()[0][0]).size()


## Rows kept by equality and compaction: all rows, or the live ones.
func live_rows() -> PackedInt32Array:
	var rows := PackedInt32Array()
	var alive: PackedByteArray = get(alive_column()) if alive_column() != &"" else PackedByteArray()
	for r in row_count():
		if alive.is_empty() or alive[r] == 1:
			rows.append(r)
	return rows


## Deep equality (GDD 1 rule 13): entity slices compare live rows by id, ignoring
## dead rows and internal layout; other slices compare column by column.
func equals(other: SliceBase) -> bool:
	if id_column() == &"":
		for spec: Array in columns():
			if get(spec[0]) != other.get(spec[0]):
				return false
		return true
	var mine := live_rows()
	var theirs := other.live_rows()
	if mine.size() != theirs.size():
		return false
	for spec: Array in columns():
		var a: Variant = get(spec[0])
		var b: Variant = other.get(spec[0])
		for k in mine.size():
			if a[mine[k]] != b[theirs[k]]:
				return false
	return true


## Drops dead rows; stable, so ids stay ascending (GDD 1 rule 12).
func compact() -> void:
	if alive_column() == &"":
		return
	var keep := live_rows()
	if keep.size() != row_count():
		keep_rows(keep)


## Keeps only `rows` (ascending) in every column; used by compaction and filtered copies.
func keep_rows(rows: PackedInt32Array) -> void:
	for spec: Array in columns():
		var source: Variant = get(spec[0])
		var kept: Variant = source.slice(0, 0)
		for r in rows:
			kept.append(source[r])
		set(spec[0], kept)


## Back to an empty slice of the same kind (filtered copy of a private slice).
func clear() -> void:
	copy_from(get_script().new())


## Row of an entity id by binary search, or -1.
func find_row(id: int) -> int:
	var ids: PackedInt32Array = get(id_column())
	var r := ids.bsearch(id)
	return r if r < ids.size() and ids[r] == id else -1


## Error when ids are not strictly ascending in 0..next_id-1, or "".
func id_error(next_id: int) -> String:
	var ids: PackedInt32Array = get(id_column())
	for r in ids.size():
		if ids[r] < 0 or ids[r] >= next_id or (r > 0 and ids[r] <= ids[r - 1]):
			return "%s: id %d out of order or not below %d" % [id_column(), ids[r], next_id]
	return ""


## Columns whose buffer is shared with `other` (copy independence, ADR-0003).
func shared_columns(other: SliceBase) -> PackedStringArray:
	var shared := PackedStringArray()
	for spec: Array in columns():
		if is_same(get(spec[0]), other.get(spec[0])):
			shared.append(spec[0])
	return shared


func _parallel_error() -> String:
	var n := row_count()
	for spec: Array in columns():
		if get(spec[0]).size() != n:
			return "%s: %d rows, expected %d" % [spec[0], get(spec[0]).size(), n]
	return ""


func _sized_error(column: StringName, expected: int) -> String:
	var n: int = get(column).size()
	return "" if n == expected else "%s: size %d, expected %d" % [column, n, expected]
