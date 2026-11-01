# RÉVEILLER (GDD 7 rules 2 to 8), owned by the wake system. Validation after the
# prefix, first failure returned, all on the faction's view: UNITÉ_INCONNUE (a dormant,
# neutral, is unknown), TYPE_NON_CAPABLE (a Guardian), DÉJÀ_AGI, AUCUN_DRONE_ADJACENT
# (one code, no parameter, for an unknown id, an awake unit, a hidden dormant and a
# dormant at distance 2 or more), ÉNERGIE_INSUFFISANTE (need, available) last.
# Application, atomic: spend, wake (the unique writer of the units), recompute the
# view of both factions (the woken unit now sees), then ÉNERGIE_CHANGÉE,
# DRONE_RÉVEILLÉ, TUILES_RÉVÉLÉES. No creation and no new id.
class_name WakeHandler
extends CommandHandler


func validate(view: StateView, command: Command, rules: RuleTable) -> ValidationResult:
	var wake := command as WakeCommand
	var catalog := rules.catalog
	if view.unit_faction(wake.waker_id) != wake.faction:
		return ValidationResult.refused(Refusal.UNKNOWN_UNIT)
	if catalog.units.side(view.unit_type(wake.waker_id)) != Faction.PLAYER:
		return ValidationResult.refused(Refusal.TYPE_NOT_CAPABLE)
	if view.unit_acted(wake.waker_id):
		return ValidationResult.refused(Refusal.ALREADY_ACTED)
	# On the faction's view a hidden, unknown or destroyed unit is not asleep, and a
	# dormant at distance 1 is always visible (minimum vision 2): no visibility test.
	if not view.unit_asleep(wake.target_id) \
			or CombatRules.distance(view.width(), view.unit_tile(wake.waker_id), view.unit_tile(wake.target_id)) != 1:
		return ValidationResult.refused(Refusal.NO_ADJACENT_DRONE)
	var price := WakeRules.price(view, wake.faction, view.unit_type(wake.target_id), catalog)
	if view.energy(wake.faction) < price:
		return ValidationResult.refused(Refusal.NOT_ENOUGH_ENERGY, PackedInt64Array([price, view.energy(wake.faction)]))
	return ValidationResult.ok()


func apply(state: GameState, command: Command, rules: RuleTable) -> ApplyResult:
	var wake := command as WakeCommand
	var result := ApplyResult.new()
	var view := state.view()
	var tile := view.unit_tile(wake.target_id)
	var price := WakeRules.price(view, wake.faction, view.unit_type(wake.target_id), rules.catalog)
	EnergyRules.spend(state, wake.faction, price, result.events)
	UnitWrites.wake(state, wake.waker_id, wake.target_id)
	result.events.append(DroneWokenEvent.new(wake.faction, wake.target_id, wake.waker_id, tile))
	result.vision = VisionService.recompute(state, rules.vision)
	if not result.vision.discovered_tiles.is_empty():
		result.events.append(TilesRevealedEvent.new(result.vision.discovered_tiles))
	return result
