# Wake-up prices (GDD 7 rule 1), owned by the wake system: the base price of the
# dormant's type, adjusted by the waking faction's protocols (Réveil sobre, floor 1).
class_name WakeRules
extends RefCounted


## prix_réveil(état, faction, type), read through a view (acquired protocols are public).
static func price(view: StateView, faction: int, dormant_type: int, catalog: DataCatalog) -> int:
	var base := catalog.wake.base_price(catalog.units.key(dormant_type))
	assert(base > 0, "a dormant of an unpriced type: the map must only hold pack types")
	return ProtocolEffects.adjusted(base, view, faction, dormant_type, ProtocolEffects.WAKE_PRICE, catalog)


## GDD 7 rule 9, at the match setup: the type of each random dormant zone, drawn with
## the state's draw function, zone after zone in order, with replacement. `zones` holds,
## per zone, the possible type ids (pack types); the caller gives the same type to the
## two camps' mirrored zones. Returns the chosen type ids, or an empty array when a
## zone has no candidate or the draw refuses.
static func draw_zone_types(state: GameState, zones: Array) -> PackedInt32Array:
	var chosen := PackedInt32Array()
	for candidates: PackedInt32Array in zones:
		var pick := state.draw(candidates.size())
		if pick < 0:
			return PackedInt32Array()
		chosen.append(candidates[pick])
	return chosen


## Map-load check (GDD 7 rule 9 and the contracts of 23): every dormant of the map is a
## pack type, the only types that have a wake price (a priced type is a pack type). One message per offending unit.
static func map_errors(state: GameState, catalog: DataCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	for row in state.units.live_rows():
		if not state.units.is_asleep(row):
			continue
		var type := state.units.type_of(row)
		if catalog.wake.base_price(catalog.units.key(type)) <= 0:
			errors.append("dormant unit %d: type %s is not a pack type" % [state.units.id_of(row), catalog.units.key(type)])
	return errors
