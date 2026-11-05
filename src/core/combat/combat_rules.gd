# Combat (GDD 8), owned by system 8: pure and deterministic, no draw. Reads effective
# stats through ProtocolEffects (GDD 12 rule 11); writes only through modify_hp
# (system 6) and the destroyed-units counter.
class_name CombatRules
extends RefCounted


## Chebyshev distance between two tiles (GDD 2 formula 1).
static func distance(width: int, tile_a: int, tile_b: int) -> int:
	return maxi(absi(tile_a % width - tile_b % width), absi(tile_a / width - tile_b / width))


## GDD 8 F1: the defender's DÉF (protocols of its owner included) plus the defense
## class of the tile it stands on.
static func defense_effective(view: StateView, unit_id: int, catalog: DataCatalog) -> int:
	var type := view.unit_type(unit_id)
	var defense := defense_on(view, view.unit_faction(unit_id), type, view.unit_tile(unit_id), catalog)
	if view.unit_ability_on(unit_id) and catalog.units.ability(type) == UnitTypes.ABILITY_HOLD:
		defense += catalog.units.hold_bonus()
	return defense


## The striker's ATQ for this strike (GDD 8 rule 12): the effective stat, plus the ambush bonus
## and a running CHARGE. A unit without attack stays without.
static func attack_effective(view: StateView, unit_id: int, catalog: DataCatalog) -> int:
	var type := view.unit_type(unit_id)
	var attack := ProtocolEffects.unit_stat(view, view.unit_faction(unit_id), type, ProtocolEffects.ATTACK, catalog)
	if attack == 0:
		return 0
	if view.unit_ambush(unit_id):
		attack += catalog.combat.ambush_attack_bonus()
	if view.unit_ability_on(unit_id) and catalog.units.ability(type) == UnitTypes.ABILITY_CHARGE:
		attack += catalog.units.charge_bonus()
	return attack


## The same defense for a unit of `faction` and `type` standing on `tile` (the AI planner
## tries tiles the unit is not on yet).
static func defense_on(view: StateView, faction: int, type: int, tile: int, catalog: DataCatalog) -> int:
	var defense := ProtocolEffects.unit_stat(view, faction, type, ProtocolEffects.DEFENSE, catalog)
	return defense + catalog.combat.def_per_tile_class() * catalog.terrain.defense_class(view.terrain_at(tile))


## GDD 8 F2: damage of one strike, 0 without attack, else at least DMG_MIN. All
## operands are positive, so the integer division truncates like a floor.
@warning_ignore("integer_division")
static func damage(view: StateView, striker_id: int, defender_id: int, catalog: DataCatalog) -> int:
	var type := view.unit_type(striker_id)
	return damage_of(attack_effective(view, striker_id, catalog), view.unit_hp(striker_id), catalog.units.hp(type),
			defense_effective(view, defender_id, catalog), catalog.combat)


## F2 on plain numbers: `attack` and `defense` already effective.
@warning_ignore("integer_division")
static func damage_of(attack: int, hp: int, max_hp: int, defense: int, combat: CombatParams) -> int:
	if attack == 0:
		return 0
	return maxi(combat.dmg_min(), combat.dmg_scale() * combat.def_base() * attack * hp / (max_hp * (combat.def_base() + defense)))


## résoudre_attaque (GDD 8 rules 1 and 6): the strike, the attacker's action, then
## the retaliation if the target survived, can hit back (ATQ > 0) and reaches the
## attacker. A destruction removes the unit only after its own strike is computed;
## one attack destroys at most one unit. Events in the order of rule 7.
static func resolve(state: GameState, attacker_id: int, target_id: int, rules: RuleTable) -> ApplyResult:
	var result := ApplyResult.new()
	var catalog := rules.catalog
	var view := state.view()
	var attacker_faction := view.unit_faction(attacker_id)
	var target_faction := view.unit_faction(target_id)
	var attacker_tile := view.unit_tile(attacker_id)
	var target_tile := view.unit_tile(target_id)
	result.events.append(AttackResolvedEvent.new(attacker_faction, attacker_id, target_id, attacker_tile, target_tile))

	var hit := UnitWrites.modify_hp(state, target_id, -damage(view, attacker_id, target_id, catalog), catalog.units)
	UnitWrites.set_acted(state, attacker_id)
	result.events.append(UnitHitEvent.new(target_faction, target_id, hit.lost(), hit.after, target_tile))
	if hit.destroyed:
		CombatWrites.count_destroyed(state, attacker_faction)
		result.events.append(UnitDestroyedEvent.new(target_faction, target_id, target_tile, attacker_id))
	else:
		_retaliate(state, view, attacker_id, target_id, attacker_tile, rules, result)

	# GDD 5 rule 9: a destroyed unit that saw something takes its vision with it.
	result.vision = VisionService.recompute(state, rules.vision)
	if not result.vision.discovered_tiles.is_empty():
		result.events.append(TilesRevealedEvent.new(result.vision.discovered_tiles))
	return result


## GDD 8 rule 6, steps 5 and 6: d2 is computed on the state after the first strike
## (the target's current HP, the attacker's defense on its own tile).
static func _retaliate(state: GameState, view: StateView, attacker_id: int, target_id: int,
		attacker_tile: int, rules: RuleTable, result: ApplyResult) -> void:
	var catalog := rules.catalog
	var reach := catalog.units.attack_range(view.unit_type(target_id))
	if distance(view.width(), view.unit_tile(target_id), attacker_tile) > reach:
		return
	var second := damage(view, target_id, attacker_id, catalog)
	if second == 0:
		return
	var attacker_faction := view.unit_faction(attacker_id)
	var target_faction := view.unit_faction(target_id)
	var back := UnitWrites.modify_hp(state, attacker_id, -second, catalog.units)
	result.events.append(UnitHitEvent.new(attacker_faction, attacker_id, back.lost(), back.after, attacker_tile))
	if back.destroyed:
		CombatWrites.count_destroyed(state, target_faction)
		result.events.append(UnitDestroyedEvent.new(attacker_faction, attacker_id, attacker_tile, target_id))
