# Wake-up prices (GDD 7 rule 1), owned by the wake system: the base price of the
# dormant's type, adjusted by the waking faction's protocols (Réveil sobre, floor 1).
class_name WakeRules
extends RefCounted


## prix_réveil(état, faction, type), read through a view (acquired protocols are public).
static func price(view: StateView, faction: int, dormant_type: int, catalog: DataCatalog) -> int:
	var base := catalog.wake.base_price(catalog.units.key(dormant_type))
	assert(base > 0, "a dormant of an unpriced type: the map must only hold pack types")
	return ProtocolEffects.adjusted(base, view, faction, dormant_type, ProtocolEffects.WAKE_PRICE, catalog)
