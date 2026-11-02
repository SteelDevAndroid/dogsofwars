# The 11 duels of the GDD 8 table, as reference vectors: strike, retaliation, HP left.
# Unit types are labels here: a Guardian type may be fielded by the player's side.
extends GdUnitTestSuite

const ECLAIREUR := 0
const ASSAUT := 1
const REMPART := 2
const OUVRIER := 3
const SENTINELLE := 4
const CHASSEUR := 5
const BASTION := 6

## [attacker type, attacker hp, target type, target hp, target terrain, d1, target hp
## after, retaliation hp lost (0: none), attacker hp after]. The attacker stands on a plain.
const DUELS := [
	[ASSAUT, 8, REMPART, 14, "^", 3, 11, 1, 7],
	[ECLAIREUR, 6, OUVRIER, 7, ".", 2, 5, 1, 5],
	[CHASSEUR, 8, ECLAIREUR, 6, ".", 6, 0, 0, 8],
	[CHASSEUR, 4, ECLAIREUR, 6, ".", 3, 3, 1, 3],
	[CHASSEUR, 8, ECLAIREUR, 6, "f", 4, 2, 1, 7],
	[BASTION, 14, ASSAUT, 8, ".", 3, 5, 2, 12],
	[ASSAUT, 8, CHASSEUR, 8, "f", 4, 4, 2, 6],
	[ASSAUT, 1, CHASSEUR, 8, ".", 1, 7, 1, 0],
	[ASSAUT, 8, SENTINELLE, 10, ".", 4, 6, 0, 8],
	[OUVRIER, 7, BASTION, 14, "^", 1, 13, 3, 4],
	[ASSAUT, 8, ASSAUT, 8, ".", 4, 4, 2, 6],
]


## Attacker on a plain at (0, 0), target at (1, 0) on `terrain`; returns the fixture.
func _duel(attacker_type: int, attacker_hp: int, target_type: int, target_hp: int, terrain: String) -> PipelineFixture:
	var state := MapBuilder.state(PackedStringArray(["." + terrain]))
	MapBuilder.unit(state, attacker_type, Faction.PLAYER, 0, 0, false, attacker_hp)
	MapBuilder.unit(state, target_type, Faction.AI, 1, 0, false, target_hp)
	return PipelineFixture.new(MapBuilder.ready(state))


func test_the_eleven_duels_of_the_gdd_table() -> void:
	for k in DUELS.size():
		var duel: Array = DUELS[k]
		var fx := _duel(duel[0], duel[1], duel[2], duel[3], duel[4])

		assert_bool(fx.attack(0, 1).permitted).override_failure_message("duel %d refused" % (k + 1)).is_true()

		var events := fx.last_events()
		var hit := events[1] as UnitHitEvent
		assert_int(hit.damage).override_failure_message("duel %d strike" % (k + 1)).is_equal(duel[3] - duel[6])
		assert_int(hit.hp_left).override_failure_message("duel %d target hp" % (k + 1)).is_equal(duel[6])
		assert_int(fx.state.view().unit_hp(0)).override_failure_message("duel %d attacker hp" % (k + 1)).is_equal(duel[8])
		# Attack, strike; then destruction, or nothing, or the retaliation (+ destruction).
		var expected_events := 3
		if duel[6] > 0:
			expected_events = 2 if duel[7] == 0 else (3 if duel[8] > 0 else 4)
		assert_int(events.size()).override_failure_message("duel %d events" % (k + 1)).is_equal(expected_events)


func test_strike_values_before_the_destruction_clamp() -> void:
	# Duel 3: the raw strike (6) is clamped to the 6 HP the Éclaireur had; duel 8:
	# the retaliation (4) is clamped to the attacker's last HP.
	var kill := _duel(CHASSEUR, 8, ECLAIREUR, 6, ".")
	var last_stand := _duel(ASSAUT, 1, CHASSEUR, 8, ".")

	kill.attack(0, 1)
	last_stand.attack(0, 1)

	assert_int((kill.last_events()[1] as UnitHitEvent).damage).is_equal(6)
	assert_int((last_stand.last_events()[2] as UnitHitEvent).damage).is_equal(1)
	# The raw retaliation of duel 8 (Chasseur at 7 HP after the first strike) is 4.
	var raw := _duel(ASSAUT, 1, CHASSEUR, 7, ".")
	assert_int(CombatRules.damage(raw.state.view(), 1, 0, CatalogFactory.standard())).is_equal(4)


func test_the_attackers_tile_protects_it_from_the_retaliation_only() -> void:
	# An Éclaireur 6/6 hits a Chasseur 8/8 for 2 whatever its tile, then takes 4 on
	# a plain, 3 on a forest or a mountain (DÉF_eff 1, 2): 144 // (8 * (4 + DÉF_eff)).
	for case: Array in [[".", 4], ["f", 3], ["^", 3]]:
		var state := MapBuilder.state(PackedStringArray([case[0] + "."]))
		MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 0, 0)
		MapBuilder.unit(state, CHASSEUR, Faction.AI, 1, 0)
		var fx := PipelineFixture.new(MapBuilder.ready(state))

		fx.attack(0, 1)

		assert_int((fx.last_events()[1] as UnitHitEvent).damage).is_equal(2)
		assert_int(6 - fx.state.view().unit_hp(0)).override_failure_message("tile %s" % case[0]).is_equal(case[1])


func test_protocols_change_the_attack_and_the_defense_of_their_owner() -> void:
	var armed := _duel(REMPART, 14, OUVRIER, 7, ".")
	ResearchRules.acquire(armed.state, Faction.PLAYER, 5)
	var plain := _duel(REMPART, 14, OUVRIER, 7, ".")
	var shielded := _duel(ASSAUT, 8, CHASSEUR, 8, ".")
	ResearchRules.acquire(shielded.state, Faction.AI, 4)
	var unshielded := _duel(ASSAUT, 8, CHASSEUR, 8, ".")

	armed.attack(0, 1)
	plain.attack(0, 1)
	shielded.attack(0, 1)
	unshielded.attack(0, 1)

	# Rempart: 8*1*14 // (14*4) = 2, with Rempart armé (ATQ 2): 4.
	assert_int((plain.last_events()[1] as UnitHitEvent).damage).is_equal(2)
	assert_int((armed.last_events()[1] as UnitHitEvent).damage).is_equal(4)
	# Chasseur DÉF 0: 8*3*8 // (8*4) = 6; with Blindage d'appoint (DÉF 1): 192 // 40 = 4.
	assert_int((unshielded.last_events()[1] as UnitHitEvent).damage).is_equal(6)
	assert_int((shielded.last_events()[1] as UnitHitEvent).damage).is_equal(4)


func test_a_sentinel_never_strikes_even_with_an_attack_protocol() -> void:
	var state := StateFactory.minimal()
	ResearchRules.acquire(state, Faction.PLAYER, 5)

	assert_int(ProtocolEffects.unit_stat(state.view(), Faction.PLAYER, SENTINELLE, ProtocolEffects.ATTACK,
			CatalogFactory.standard())).is_equal(0)


func test_defense_effective_ranges_from_zero_to_four() -> void:
	var state := MapBuilder.state(PackedStringArray([".f^"]))
	MapBuilder.unit(state, ECLAIREUR, Faction.PLAYER, 0, 0)
	MapBuilder.unit(state, REMPART, Faction.PLAYER, 2, 0)
	MapBuilder.unit(state, BASTION, Faction.AI, 1, 0)
	MapBuilder.ready(state)
	var catalog := CatalogFactory.standard()

	assert_int(CombatRules.defense_effective(state.view(), 0, catalog)).is_equal(0)
	assert_int(CombatRules.defense_effective(state.view(), 2, catalog)).is_equal(3)
	assert_int(CombatRules.defense_effective(state.view(), 1, catalog)).is_equal(4)
