# COMMENCER_LE_TOUR (GDD 3 rules 1 to 3), owned by the turn system. Sequence of the
# stored phases: CRÉÉE or EXÉCUTION_ENNEMIE -> player n + 1; FIN_DE_TOUR -> enemy n.
# Then the faction's units get their move and action back. The vision does not
# change (GDD 5 rule 9). Energy income (10) and research (12) join with their systems.
class_name BeginTurnHandler
extends CommandHandler


func validate(view: StateView, command: Command, _rules: RuleTable) -> ValidationResult:
	var phase := view.phase()
	if command.faction == Faction.PLAYER:
		if phase != HeaderSlice.PHASE_CREATED and phase != HeaderSlice.PHASE_ENEMY_EXECUTION:
			return ValidationResult.refused(Refusal.WRONG_PHASE, PackedInt64Array([phase]))
		if view.turn() >= view.max_turn():
			return ValidationResult.refused(Refusal.TURN_LIMIT, PackedInt64Array([view.max_turn()]))
		return ValidationResult.ok()
	if command.faction == Faction.AI and phase == HeaderSlice.PHASE_END_OF_TURN:
		return ValidationResult.ok()
	return ValidationResult.refused(Refusal.WRONG_PHASE, PackedInt64Array([phase]))


func apply(state: GameState, command: Command, _rules: RuleTable) -> ApplyResult:
	var result := ApplyResult.new()
	var player := command.faction == Faction.PLAYER
	var phase := HeaderSlice.PHASE_PLAYER if player else HeaderSlice.PHASE_ENEMY_EXECUTION
	TurnWrites.begin_phase(state, command.faction, phase, player)
	UnitWrites.start_turn(state, command.faction)
	result.events.append(TurnStartedEvent.new(state.turn(), command.faction, phase))
	return result
