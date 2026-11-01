# Witness test of the test framework itself (ADR-0011, verification 1): the suite
# runs headless and reports green; the CI turns a red or orphan run into a failure.
extends GdUnitTestSuite


func test_assertion_on_values_passes() -> void:
	assert_int(2 + 2).is_equal(4)


func test_auto_free_leaves_no_orphan() -> void:
	var node: Node = auto_free(Node.new())
	assert_object(node).is_not_null()
