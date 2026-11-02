# ABANDONNER (GDD 3 rules 9 and 14), owned by the turn system: permitted in any
# phase of a running match, the enemy phase included (refusal prefix, ADR-0004 §4);
# the only refusal is PARTIE_TERMINÉE, from the prefix. The match ends with the
# abandon status and submits no score.
class_name AbandonHandler
extends CommandHandler


func validate(_view: StateView, command: Command, _rules: RuleTable) -> ValidationResult:
	if command.faction != Faction.PLAYER:
		return ValidationResult.refused(Refusal.NOT_YOUR_TURN)
	return ValidationResult.ok()


func apply(state: GameState, _command: Command, _rules: RuleTable) -> ApplyResult:
	var result := ApplyResult.new()
	TurnWrites.finish(state, HeaderSlice.END_ABANDONED)
	result.events.append(MatchEndedEvent.new(HeaderSlice.END_ABANDONED))
	return result
