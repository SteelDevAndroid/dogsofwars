# FINIR_LE_TOUR (GDD 3 rule 3), owned by the turn system: only the player ends a
# phase this way (the AI ends with its announcement). Stored phase FIN_DE_TOUR, so a
# reload never gives the player their turn back; the turn system then submits
# COMMENCER_LE_TOUR(IA).
class_name EndTurnHandler
extends CommandHandler


func validate(_view: StateView, command: Command, _rules: RuleTable) -> ValidationResult:
	if command.faction != Faction.PLAYER:
		return ValidationResult.refused(Refusal.NOT_YOUR_TURN)
	return ValidationResult.ok()


func apply(state: GameState, command: Command, _rules: RuleTable) -> ApplyResult:
	var result := ApplyResult.new()
	TurnWrites.end_phase(state)
	RecallWrites.clear(state)
	result.events.append(TurnEndedEvent.new(state.turn(), command.faction))
	return result
