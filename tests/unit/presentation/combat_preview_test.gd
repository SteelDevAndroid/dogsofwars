extends GdUnitTestSuite


func _preview(events: Array[PresentationEvent], permitted: bool = true) -> PreviewResult:
	var result := PreviewResult.new()
	result.validation = ValidationResult.ok() if permitted else ValidationResult.refused(Refusal.TARGET_OUT_OF_RANGE)
	result.events = events
	return result


func test_the_preview_reads_the_blow_and_the_retaliation() -> void:
	var events: Array[PresentationEvent] = [AttackResolvedEvent.new(0, 1, 2, 5, 6), UnitHitEvent.new(1, 2, 4, 4, 6), UnitHitEvent.new(0, 1, 2, 6, 5)]

	var preview := CombatPreview.of(_preview(events), 1, 2)

	assert_array([preview.damage, preview.retaliation, preview.lethal, preview.target_hp_after]).is_equal([4, 2, false, 4])
	assert_str(preview.text()).is_equal("Inflige −4 · Riposte −2")


func test_a_lethal_blow_has_no_retaliation() -> void:
	var events: Array[PresentationEvent] = [AttackResolvedEvent.new(0, 1, 2, 5, 6), UnitHitEvent.new(1, 2, 3, 0, 6), UnitDestroyedEvent.new(1, 2, 6, 1)]

	var preview := CombatPreview.of(_preview(events), 1, 2)

	assert_bool(preview.lethal).is_true()
	assert_str(preview.text()).is_equal("Inflige −3 · létal · Pas de riposte")


func test_a_retaliation_that_kills_the_attacker_is_told() -> void:
	var events: Array[PresentationEvent] = [UnitHitEvent.new(1, 2, 1, 5, 6), UnitHitEvent.new(0, 1, 2, 0, 5), UnitDestroyedEvent.new(0, 1, 5, 2)]

	var preview := CombatPreview.of(_preview(events), 1, 2)

	assert_bool(preview.attacker_destroyed).is_true()
	assert_str(preview.text()).contains("votre unité tombe")


func test_a_refused_attack_is_not_permitted() -> void:
	assert_bool(CombatPreview.of(_preview([], false), 1, 2).permitted).is_false()
