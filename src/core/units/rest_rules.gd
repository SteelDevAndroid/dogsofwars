# Rest heal (GDD 6 rule 6 and formula 3), owned by the units system. At the start of a
# faction's turn, before the flags are reset: an awake unit whose "moved" and "acted"
# flags were both false last turn heals REST_HEAL (protocols of its owner included)
# plus NODE_REST_BONUS on a node its faction owns, capped at PV_max, through
# modify_hp. A unit carrying an announced attack intention does not heal (rule 6), a
# sleeping or just-woken unit neither (its flags are set). A unit that did not rest but
# stands on a node its faction owns still heals NODE_PASSIVE_HEAL (a held node is a
# field repair post). No event for a zero heal.
class_name RestRules
extends RefCounted


static func heal_faction(state: GameState, faction: int, catalog: DataCatalog, events: Array[PresentationEvent]) -> void:
	var view := state.view()
	for unit_id in view.unit_ids():
		if view.unit_faction(unit_id) != faction or view.unit_asleep(unit_id) or _carries_attack_intention(state, unit_id):
			continue
		var type := view.unit_type(unit_id)
		var tile := view.unit_tile(unit_id)
		var node_id := view.node_at(tile)
		var on_own_node := node_id >= 0 and view.node_owner(node_id) == faction
		var amount := 0
		if view.unit_moved(unit_id) or view.unit_acted(unit_id):
			if on_own_node:
				amount = catalog.units.node_passive_heal()
		else:
			amount = ProtocolEffects.adjusted(catalog.units.rest_heal(), view, faction, type, ProtocolEffects.REST_HEAL, catalog)
			if on_own_node:
				amount += catalog.units.node_rest_bonus()
		if amount == 0:
			continue
		var change := UnitWrites.modify_hp(state, unit_id, amount, catalog.units)
		if change.after != change.before:
			events.append(UnitHealedEvent.new(faction, unit_id, change.before, change.after, tile))


static func _carries_attack_intention(state: GameState, unit_id: int) -> bool:
	var slice := state.intentions
	for row in slice.row_count():
		if slice.author_of(row) == unit_id and slice.action_of(row) == IntentionsSlice.ACTION_ATTACK \
				and slice.status_of(row) == IntentionsSlice.STATUS_ANNOUNCED:
			return true
	return false
