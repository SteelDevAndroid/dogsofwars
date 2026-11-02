# The balance harness (tests/balance) must keep working: the scripted player against the AI over
# a few seeds ends every match with no refused command, deterministically, and does act.
extends GdUnitTestSuite

const Run := preload("res://tests/balance/run_matches.gd")


func test_scripted_matches_end_without_a_refusal_and_are_reproducible() -> void:
	var catalog := Run._catalog({})
	for seed_value in [1, 2, 3]:
		var first := Run.play(seed_value, catalog)
		var second := Run.play(seed_value, catalog)

		assert_dict(first).is_equal(second)
		assert_int(first["refusals"]).is_equal(0)
		assert_int(first["commands"]).is_greater(10)
		assert_bool(first["status"] >= HeaderSlice.END_DOMINATION and first["status"] <= HeaderSlice.END_TURNS_DRAW).is_true()


func test_an_override_changes_the_data_it_names_only() -> void:
	var plain := Run._catalog({})
	var changed := Run._catalog({"ai.json.w_danger": 3, "energie.json.start": 9})

	assert_int(changed.ai.planner("w_danger")).is_equal(3)
	assert_int(plain.ai.planner("w_danger")).is_equal(6)
	assert_int(changed.ai.planner("w_damage")).is_equal(plain.ai.planner("w_damage"))
	assert_int(changed.energy.start_stock()).is_equal(9)


func test_the_summary_counts_the_outcomes() -> void:
	var summary := Run.summarize([{"status": 3, "turn": 30, "refusals": 0}, {"status": 3, "turn": 20, "refusals": 0}, {"status": 2, "turn": 10, "refusals": 1}])

	assert_dict(summary["by_status"]).is_equal({3: 2, 2: 1})
	assert_float(summary["mean_turn"]).is_equal(20.0)
	assert_int(summary["refusals"]).is_equal(1)
