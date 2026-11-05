# CAPACITÉ (GDD 6 rule 12), owned by the units system. Validation on the faction's view, first
# failure returned: UNITÉ_INCONNUE, UNITÉ_ENDORMIE, AUCUNE_CAPACITÉ, CAPACITÉ_EN_RECHARGE (turns
# left), DÉJÀ_AGI, then, for SPRINT only, DÉJÀ_DÉPLACÉE (the extra points are for a move to come).
# Application: the cooldown starts; SPRINT, CHARGE and HOLD switch their effect on (HOLD and
# REPAIR also cost the action); REPAIR heals the unit and its allied neighbours at once.
class_name AbilityHandler
extends CommandHandler


func validate(view: StateView, command: Command, rules: RuleTable) -> ValidationResult:
	var use := command as AbilityCommand
	var units := rules.catalog.units
	if view.unit_faction(use.unit_id) != use.faction:
		return ValidationResult.refused(Refusal.UNKNOWN_UNIT)
	if view.unit_asleep(use.unit_id):
		return ValidationResult.refused(Refusal.UNIT_ASLEEP)
	var ability := units.ability(view.unit_type(use.unit_id))
	if ability == UnitTypes.ABILITY_NONE:
		return ValidationResult.refused(Refusal.NO_ABILITY)
	var left := view.unit_cooldown(use.unit_id)
	if left > 0:
		return ValidationResult.refused(Refusal.ABILITY_RECHARGING, PackedInt64Array([left]))
	if view.unit_acted(use.unit_id):
		return ValidationResult.refused(Refusal.ALREADY_ACTED)
	if ability == UnitTypes.ABILITY_SPRINT and view.unit_moved(use.unit_id):
		return ValidationResult.refused(Refusal.ALREADY_MOVED)
	return ValidationResult.ok()


func apply(state: GameState, command: Command, rules: RuleTable) -> ApplyResult:
	var use := command as AbilityCommand
	var result := ApplyResult.new()
	var units := rules.catalog.units
	var view := state.view()
	var type := view.unit_type(use.unit_id)
	var ability := units.ability(type)
	var tile := view.unit_tile(use.unit_id)
	var lasting := ability != UnitTypes.ABILITY_REPAIR
	UnitWrites.use_ability(state, use.unit_id, units.ability_cooldown(type), lasting)
	result.events.append(AbilityUsedEvent.new(use.faction, use.unit_id, ability, tile))
	if ability == UnitTypes.ABILITY_HOLD or ability == UnitTypes.ABILITY_REPAIR:
		UnitWrites.set_acted(state, use.unit_id)
	if ability == UnitTypes.ABILITY_REPAIR:
		for other in view.unit_ids():
			if view.unit_faction(other) != use.faction or view.unit_asleep(other):
				continue
			if CombatRules.distance(view.width(), tile, view.unit_tile(other)) > 1:
				continue
			var change := UnitWrites.modify_hp(state, other, units.repair_amount(), units)
			if change.after != change.before:
				result.events.append(UnitHealedEvent.new(use.faction, other, change.before, change.after, view.unit_tile(other)))
	return result
