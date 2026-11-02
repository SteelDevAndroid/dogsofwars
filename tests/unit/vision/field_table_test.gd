extends GdUnitTestSuite

const SIZE := 8


func _table(mountains: PackedInt32Array) -> FieldTable:
	var cells := PackedByteArray()
	cells.resize(SIZE * SIZE)
	for tile in mountains:
		cells[tile] = TerrainGrid.MOUNTAIN
	return FieldTable.new(TerrainGrid.new(cells), SIZE, SIZE, 5)


func _tile(x: int, y: int) -> int:
	return y * SIZE + x


func test_mountain_on_the_line_hides_the_tile_behind() -> void:
	var table := _table(PackedInt32Array([_tile(2, 1)]))

	assert_bool(table.blocked(_tile(0, 0), _tile(4, 2))).is_true()
	assert_bool(table.blocked(_tile(0, 0), _tile(2, 1))).is_false()


func test_line_passing_a_corner_does_not_advance_the_minor_axis() -> void:
	var on_line := _table(PackedInt32Array([_tile(1, 0)]))
	var off_line := _table(PackedInt32Array([_tile(1, 1)]))

	assert_bool(on_line.blocked(_tile(0, 0), _tile(2, 1))).is_true()
	assert_bool(off_line.blocked(_tile(0, 0), _tile(2, 1))).is_false()


func test_neighbour_is_never_hidden() -> void:
	var table := _table(PackedInt32Array([_tile(3, 3), _tile(4, 3), _tile(3, 4)]))

	for target in [_tile(4, 4), _tile(2, 2), _tile(4, 3)]:
		assert_bool(table.blocked(_tile(3, 3), target)).is_false()
		assert_bool(table.blocked(_tile(4, 4), _tile(3, 3))).is_false()


func test_source_on_a_mountain_is_not_blocked() -> void:
	var table := _table(PackedInt32Array([_tile(0, 0), _tile(2, 1)]))

	assert_bool(table.blocked(_tile(0, 0), _tile(4, 2))).is_false()


func test_field_is_bounded_by_the_map_and_ascending() -> void:
	var table := _table(PackedInt32Array())

	var field := table.field(_tile(0, 0), 2)

	assert_int(field.size()).is_equal(9)
	var sorted := field.duplicate()
	sorted.sort()
	assert_array(field).is_equal(sorted)
	assert_array(table.field(_tile(3, 3), 1)).has_size(9)
	assert_array(table.field(_tile(3, 3), 0)).is_equal(PackedInt32Array([_tile(3, 3)]))
