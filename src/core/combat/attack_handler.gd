# ATTAQUER (GDD 8 rules 10 and 11, GDD 23). Validation on the faction's view, in the
# fixed order, first refusal returned: AUCUNE_INTENTION (an AI attack only comes from
# a stored intention, ADR-0004 §9), UNITÉ_INCONNUE, UNITÉ_ENDORMIE, DÉJÀ_AGI,
# ATTAQUANT_SANS_ATTAQUE, CIBLE_NON_VISIBLE (hidden, unknown, destroyed or stale ids
# all give the same code, no parameter), CIBLE_NON_HOSTILE (same faction or dormant),
# CIBLE_HORS_DE_PORTÉE. An attack comes from any tile; a diagonal is allowed.
class_name AttackHandler
extends CommandHandler


func validate(view: StateView, command: Command, rules: RuleTable) -> ValidationResult:
	var attack := command as AttackCommand
	var catalog := rules.catalog
	if attack.emitter == Command.EMITTER_AI:
		return ValidationResult.refused(Refusal.NO_INTENTION)
	if view.unit_faction(attack.attacker_id) != attack.faction:
		return ValidationResult.refused(Refusal.UNKNOWN_UNIT)
	if view.unit_asleep(attack.attacker_id):
		return ValidationResult.refused(Refusal.UNIT_ASLEEP)
	if view.unit_acted(attack.attacker_id):
		return ValidationResult.refused(Refusal.ALREADY_ACTED)
	var attacker_type := view.unit_type(attack.attacker_id)
	if ProtocolEffects.unit_stat(view, attack.faction, attacker_type, ProtocolEffects.ATTACK, catalog) == 0:
		return ValidationResult.refused(Refusal.ATTACKER_WITHOUT_ATTACK)
	var target_tile := view.unit_tile(attack.target_id)
	if target_tile < 0:
		return ValidationResult.refused(Refusal.TARGET_NOT_VISIBLE)
	if view.unit_asleep(attack.target_id) or view.unit_faction(attack.target_id) == attack.faction:
		return ValidationResult.refused(Refusal.TARGET_NOT_HOSTILE)
	var reach := catalog.units.attack_range(attacker_type)
	if CombatRules.distance(view.width(), view.unit_tile(attack.attacker_id), target_tile) > reach:
		return ValidationResult.refused(Refusal.TARGET_OUT_OF_RANGE)
	return ValidationResult.ok()


func apply(state: GameState, command: Command, rules: RuleTable) -> ApplyResult:
	var attack := command as AttackCommand
	return CombatRules.resolve(state, attack.attacker_id, attack.target_id, rules)
