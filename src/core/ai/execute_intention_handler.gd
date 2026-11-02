# EXÉCUTER_UNE_INTENTION (GDD 9 rule 4, ADR-0004 §9), owned by the AI system. Validation:
# PHASE_INCORRECTE (not the enemy phase), then AUCUNE_INTENTION (one code: unknown id,
# already settled, not due this turn, or a lower id still due). Application, under one
# revision and with no nested submit: the cancellation conditions are tested on the real
# state, in the order of the GDD — attack: AUTEUR_DÉTRUIT, CIBLE_DÉTRUITE, CIBLE_DÉPLACÉE
# (the target is not on the tile recorded at the announcement, even if still in range,
# never redirected), HORS_DE_PORTÉE; capture: UNITÉ_DÉTRUITE, UNITÉ_ABSENTE (not on the
# node any more), NŒUD_DÉJÀ_À_L'IA. A cancellation publishes INTENTION_ANNULÉE and nothing
# else; otherwise the attack resolution or the capture application is called directly
# (the author acts), preceded by INTENTION_EXÉCUTÉE. The command is never refused for
# a cancellation condition.
class_name ExecuteIntentionHandler
extends CommandHandler


func validate(view: StateView, command: Command, _rules: RuleTable) -> ValidationResult:
	if view.phase() != HeaderSlice.PHASE_ENEMY_EXECUTION or command.faction != Faction.AI:
		return ValidationResult.refused(Refusal.WRONG_PHASE, PackedInt64Array([view.phase()]))
	if not view.intention_executable((command as ExecuteIntentionCommand).intention_id):
		return ValidationResult.refused(Refusal.NO_INTENTION)
	return ValidationResult.ok()


func apply(state: GameState, command: Command, rules: RuleTable) -> ApplyResult:
	var intention_id := (command as ExecuteIntentionCommand).intention_id
	var slice := state.intentions
	var row := slice.find_row(intention_id)
	var author := slice.author_of(row)
	var kind := slice.target_kind_of(row)
	var target := slice.target_id_of(row)
	var target_tile := slice.target_tile_of(row)
	var reason := _cancel_reason(state, row, rules)
	var result := ApplyResult.new()
	if reason != IntentionsSlice.REASON_NONE:
		AiWrites.settle_intention(state, intention_id, IntentionsSlice.STATUS_CANCELLED, reason)
		result.events.append(IntentionCancelledEvent.new(intention_id, author, reason, kind, target_tile))
		return result
	AiWrites.settle_intention(state, intention_id, IntentionsSlice.STATUS_EXECUTED, IntentionsSlice.REASON_NONE)
	var done: ApplyResult
	if slice.action_of(row) == IntentionsSlice.ACTION_ATTACK:
		done = CombatRules.resolve(state, author, target, rules)
	else:
		done = CaptureHandler.new().apply(state, CaptureCommand.new(Faction.AI, Command.EMITTER_SYS, author), rules)
	result.events.append(IntentionExecutedEvent.new(intention_id, author, kind, target_tile))
	result.events.append_array(done.events)
	result.profile_effects.append_array(done.profile_effects)
	return result


## REASON_NONE when every condition holds.
static func _cancel_reason(state: GameState, row: int, rules: RuleTable) -> int:
	var slice := state.intentions
	var view := state.view()
	var author := slice.author_of(row)
	var author_tile := view.unit_tile(author)
	if slice.action_of(row) == IntentionsSlice.ACTION_CAPTURE:
		if author_tile < 0:
			return IntentionsSlice.REASON_UNIT_DESTROYED
		if author_tile != slice.target_tile_of(row):
			return IntentionsSlice.REASON_UNIT_ABSENT
		if view.node_owner(slice.target_id_of(row)) == Faction.AI:
			return IntentionsSlice.REASON_NODE_ALREADY_AI
		return IntentionsSlice.REASON_NONE
	if author_tile < 0:
		return IntentionsSlice.REASON_AUTHOR_DESTROYED
	var target_tile := view.unit_tile(slice.target_id_of(row))
	if target_tile < 0:
		return IntentionsSlice.REASON_TARGET_DESTROYED
	if target_tile != slice.target_tile_of(row):
		return IntentionsSlice.REASON_TARGET_MOVED
	if CombatRules.distance(view.width(), author_tile, target_tile) > rules.catalog.units.attack_range(view.unit_type(author)):
		return IntentionsSlice.REASON_OUT_OF_RANGE
	return IntentionsSlice.REASON_NONE
