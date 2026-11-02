# VALIDER_LA_LECTURE, owned by the ruins system: the journal entry of the ruin must be
# pending (LECTURE_NON_EN_ATTENTE otherwise, one code); application: validated.
class_name ValidateRuinReadHandler
extends CommandHandler


func validate(view: StateView, command: Command, _rules: RuleTable) -> ValidationResult:
	if not view.ruin_read_pending((command as ValidateRuinReadCommand).ruin_id):
		return ValidationResult.refused(Refusal.NO_PENDING_READ)
	return ValidationResult.ok()


func apply(state: GameState, command: Command, _rules: RuleTable) -> ApplyResult:
	RuinWrites.journal_validate(state, state.ruin_journal.pending_row((command as ValidateRuinReadCommand).ruin_id))
	return ApplyResult.new()
