# Replay of a CommandLog (ADR-0004 §10): the same pipeline without CommandGate,
# with an UndoSlot, null post-commit and profile ports; the AI planner is not run.
# A refusal during the replay is a divergence.
class_name CommandReplay
extends RefCounted

const FORMAT_INCOMPATIBLE := &"FORMAT_INCOMPATIBLE"
const UNREADABLE_COMMAND := &"COMMANDE_ILLISIBLE"


class Outcome:
	var state: GameState
	## Index of the first refused command, -1 when every command applied.
	var divergence := -1
	var code: StringName = &""
	var other_data := false


static func replay(initial: GameState, log: CommandLog, catalog: DataCatalog) -> Outcome:
	var outcome := Outcome.new()
	outcome.state = initial.duplicate_state()
	outcome.other_data = log.content_hash != catalog.content_hash
	if log.format_version != CommandLog.FORMAT_VERSION:
		outcome.code = FORMAT_INCOMPATIBLE
		return outcome
	var rules := RuleTable.standard(catalog, VisionContext.for_map(catalog, outcome.state))
	var pipeline := CommandPipeline.new(outcome.state, rules, null, UndoSlot.new(),
			CommandLog.new(log.content_hash), NullPostCommitPort.new(), NullProfilePort.new(), NullSink.new())
	for k in log.commands.size():
		var command := CommandCodec.decode(log.commands[k])
		var result := pipeline.submit(command) if command != null else ValidationResult.refused(UNREADABLE_COMMAND)
		if not result.permitted:
			outcome.divergence = k
			outcome.code = result.code
			return outcome
	return outcome
