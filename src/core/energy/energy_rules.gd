# Energy (GDD 10), owned by system 10: one stock per faction in [0, max], income
# computed from the owned nodes and never stored, paid at the start of the
# faction's turn, capped (the surplus is lost).
class_name EnergyRules
extends RefCounted


## GDD 10 formula D.1: sum of REVENU_NIVEAU over the nodes the faction owns, by id.
static func income(state: GameState, faction: int, energy: EnergyParams) -> int:
	var total := 0
	for row in state.nodes.row_count():
		if state.nodes.owner_of(row) == faction:
			total += energy.income(state.nodes.level_of(row))
	return total


static func stock(state: GameState, faction: int) -> int:
	return state.factions.energy_of(faction)


## GDD 10 rule 10: the starting stock, at the match setup only.
static func initialize(state: GameState, energy: EnergyParams) -> void:
	for faction in state.faction_count():
		state.factions._fac_energy[faction] = energy.start_stock()


## GDD 10 rules 4, 5 and 11: income paid, capped; ÉNERGIE_CHANGÉE only if the stock
## changed. An eliminated faction is not paid.
static func pay_income(state: GameState, faction: int, energy: EnergyParams, events: Array[PresentationEvent]) -> void:
	if state.factions.is_eliminated(faction):
		return
	var before := stock(state, faction)
	var after := mini(before + income(state, faction, energy), energy.max_stock())
	if after != before:
		state.factions._fac_energy[faction] = after
		events.append(EnergyChangedEvent.new(faction, before, after))


## GDD 10 rule 6 (dépenser): debits `amount` (>= 1, at most the stock, checked by
## the validation) and returns ÉNERGIE_CHANGÉE in `events`.
static func spend(state: GameState, faction: int, amount: int, events: Array[PresentationEvent]) -> void:
	var before := stock(state, faction)
	assert(amount >= 1 and amount <= before, "spend outside 1..stock")
	state.factions._fac_energy[faction] = before - amount
	events.append(EnergyChangedEvent.new(faction, before, before - amount))


## GDD 10 rule 9: 0 <= stock <= max (tests and every load).
static func consistency_errors(state: GameState, energy: EnergyParams) -> PackedStringArray:
	var errors := PackedStringArray()
	for faction in state.faction_count():
		var value := stock(state, faction)
		if value < 0 or value > energy.max_stock():
			errors.append("faction %d: energy %d outside 0..%d" % [faction, value, energy.max_stock()])
	return errors
