# Protocol effects (GDD 12 rules 10 to 13), owned by the protocol system: computed,
# never stored. A stat of a unit type for a faction is its base plus the deltas of
# the protocols that faction acquired, by ascending id, then bounded. Read through
# a StateView, so validations see what the faction knows (acquired protocols are
# public, GDD 12 rule 10). Effects follow the unit's owner (rule 12).
class_name ProtocolEffects
extends RefCounted

const VISION := 0
const MOVE := 1
const ATTACK := 2
const DEFENSE := 3
const REST_HEAL := 4
const WAKE_PRICE := 5

## Lowest value of each stat after the deltas (the wake price floors at 1, GDD 12).
const FLOOR := [1, 0, 0, 0, 0, 1]
## "Une stat à 0 reste à 0": a Sentinelle (MVT 0, ATQ 0) never moves nor attacks.
const ZERO_STAYS_ZERO := [false, true, true, false, false, false]


## Sum of the deltas on `stat` for `type` from the protocols `faction` acquired.
static func modifier(view: StateView, faction: int, type: int, stat: int, catalog: DataCatalog) -> int:
	var tree := catalog.protocols
	var type_key := catalog.units.key(type)
	var total := 0
	for effect in tree.effect_count():
		if tree.effect_stat(effect) != stat or not view.has_protocol(faction, tree.effect_protocol(effect)):
			continue
		var types := tree.effect_types(effect)
		if types.is_empty() or types.has(type_key):
			total += tree.effect_delta(effect)
	return total


## stat_effective (GDD 12 rule 11) of a unit stat (VISION, MOVE, ATTACK, DEFENSE).
static func unit_stat(view: StateView, faction: int, type: int, stat: int, catalog: DataCatalog) -> int:
	return bounded(_base(type, stat, catalog.units), modifier(view, faction, type, stat, catalog), stat)


## stat_effective of a stat whose base lives in another system (REST_HEAL, WAKE_PRICE).
static func adjusted(base: int, view: StateView, faction: int, type: int, stat: int, catalog: DataCatalog) -> int:
	return bounded(base, modifier(view, faction, type, stat, catalog), stat)


static func bounded(base: int, delta: int, stat: int) -> int:
	if base == 0 and ZERO_STAYS_ZERO[stat]:
		return 0
	return maxi(FLOOR[stat], base + delta)


## Largest vision delta any faction may get, to size the field table.
static func max_vision_bonus(catalog: DataCatalog) -> int:
	var total := 0
	var tree := catalog.protocols
	for effect in tree.effect_count():
		if tree.effect_stat(effect) == VISION and tree.effect_delta(effect) > 0:
			total += tree.effect_delta(effect)
	return total


static func _base(type: int, stat: int, units: UnitTypes) -> int:
	match stat:
		VISION:
			return units.vision(type)
		MOVE:
			return units.move(type)
		ATTACK:
			return units.attack(type)
		DEFENSE:
			return units.defense(type)
	assert(false, "not a unit stat: %d" % stat)
	return 0
