# Rules of one command type, owned by its system (ADR-0004 §2). Stateless: the
# RuleTable passes itself for the catalog and the vision context. validate is pure
# and reads the faction's view only; apply cannot fail for a game case, writes
# through the owners' functions and returns its effects. Explicit returns (4.7).
class_name CommandHandler
extends RefCounted


func validate(_view: StateView, _command: Command, _rules: RuleTable) -> ValidationResult:
	assert(false, "CommandHandler.validate is not implemented")
	return ValidationResult.refused(Refusal.UNKNOWN_COMMAND)


func apply(_state: GameState, _command: Command, _rules: RuleTable) -> ApplyResult:
	assert(false, "CommandHandler.apply is not implemented")
	return ApplyResult.new()
