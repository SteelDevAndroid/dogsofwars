# RECHERCHER (GDD 12 rules 5, 6 and 8), owned by the protocol system. Validation
# order, first failure returned: PROTOCOLE_INCONNU, PROTOCOLE_ACQUIS,
# RECHERCHE_EN_COURS, PRÉREQUIS_MANQUANT (a prerequisite still in research does not
# count), ÉNERGIE_INSUFFISANTE (need, available) last (GDD 10 rule 7). Neutral
# about the faction; the AI never submits it at the MVP (rule 9). The price is
# paid at the application, never refunded.
class_name ResearchHandler
extends CommandHandler


func validate(view: StateView, command: Command, rules: RuleTable) -> ValidationResult:
	var research := command as ResearchCommand
	var tree := rules.catalog.protocols
	var f := research.faction
	if research.protocol < 0 or research.protocol >= tree.count():
		return ValidationResult.refused(Refusal.UNKNOWN_PROTOCOL)
	if view.has_protocol(f, research.protocol):
		return ValidationResult.refused(Refusal.PROTOCOL_ACQUIRED)
	if view.research(f) != ResearchRules.NONE:
		return ValidationResult.refused(Refusal.RESEARCH_IN_PROGRESS, PackedInt64Array([view.research(f)]))
	var prerequisite := tree.prerequisite(research.protocol)
	if prerequisite >= 0 and not view.has_protocol(f, prerequisite):
		return ValidationResult.refused(Refusal.PREREQUISITE_MISSING, PackedInt64Array([prerequisite]))
	var price := tree.price(research.protocol)
	if view.energy(f) < price:
		return ValidationResult.refused(Refusal.NOT_ENOUGH_ENERGY, PackedInt64Array([price, view.energy(f)]))
	return ValidationResult.ok()


func apply(state: GameState, command: Command, rules: RuleTable) -> ApplyResult:
	var research := command as ResearchCommand
	var result := ApplyResult.new()
	var tree := rules.catalog.protocols
	ResearchRules.start(state, research.faction, research.protocol, tree.duration(research.protocol))
	result.events.append(ResearchStartedEvent.new(research.faction, research.protocol))
	EnergyRules.spend(state, research.faction, tree.price(research.protocol), result.events)
	return result
