# ANNONCER_LES_INTENTIONS (GDD 9 step 6 and rules 13, 15, 18, 22, 25; ADR-0005 §2, §5),
# owned by the AI system. Emitted by SYS at the end of the enemy phase. Validation on
# the AI's view, first failure returned: PHASE_INCORRECTE (not the enemy phase),
# LIMITE_DE_TOURS (no announcement at turn T_MAX), IA_PASSIVE, then ANNONCE_INVALIDE
# (param: index of the intention, of the agent, or -1 for the siege) for a malformed
# content: authors and agents in strictly ascending id order, an author that is an
# awake AI unit with no intention yet this turn, a motive of the list, an attack on a
# visible hostile unit within range (Chebyshev) by a unit with ATQ, a capture only by
# the unit standing on a node not yet the AI's, CAPTURE motive iff capture; a siege of
# a known node not the AI's, announced as 1 then 2 (the second only right after the
# first on the same node), carried by a capture intention of that node, and never at
# turn T_MAX - 1 for a first announcement (it could not end); agents owned by the AI.
# Application: older intentions are pruned (GDD 1 formula 4), the intentions stored
# with their positions, the agents and the siege written, one INTENTION_ANNONCÉE each.
class_name AnnounceIntentionsHandler
extends CommandHandler

const SIEGE_STEPS := 2


func validate(view: StateView, command: Command, rules: RuleTable) -> ValidationResult:
	var announce := command as AnnounceIntentionsCommand
	if view.phase() != HeaderSlice.PHASE_ENEMY_EXECUTION or announce.faction != Faction.AI:
		return ValidationResult.refused(Refusal.WRONG_PHASE, PackedInt64Array([view.phase()]))
	if view.turn() >= view.max_turn():
		return ValidationResult.refused(Refusal.TURN_LIMIT, PackedInt64Array([view.max_turn()]))
	if view.ai_passive():
		return ValidationResult.refused(Refusal.AI_PASSIVE)
	var count := announce.intentions.size() / AnnounceIntentionsCommand.INTENTION_WIDTH
	var previous_author := -1
	var siege_carried := announce.siege_node < 0
	for index in count:
		var at := index * AnnounceIntentionsCommand.INTENTION_WIDTH
		var author := announce.intentions[at]
		if author <= previous_author or not _intention_ok(view, announce.intentions.slice(at, at + AnnounceIntentionsCommand.INTENTION_WIDTH), rules):
			return _invalid(index)
		previous_author = author
		if announce.intentions[at + 1] == IntentionsSlice.TARGET_NODE and announce.intentions[at + 2] == announce.siege_node:
			siege_carried = true
	if not siege_carried or not _siege_ok(view, announce):
		return _invalid(-1)
	var previous_unit := -1
	for index in announce.agents.size() / AnnounceIntentionsCommand.AGENT_WIDTH:
		var agent := announce.agents.slice(index * AnnounceIntentionsCommand.AGENT_WIDTH, (index + 1) * AnnounceIntentionsCommand.AGENT_WIDTH)
		if agent[0] <= previous_unit or not _agent_ok(view, agent):
			return _invalid(index)
		previous_unit = agent[0]
	return ValidationResult.ok()


func apply(state: GameState, command: Command, rules: RuleTable) -> ApplyResult:
	var announce := command as AnnounceIntentionsCommand
	var result := ApplyResult.new()
	AiWrites.prune_intentions(state)
	for index in announce.intentions.size() / AnnounceIntentionsCommand.INTENTION_WIDTH:
		var at := index * AnnounceIntentionsCommand.INTENTION_WIDTH
		var author := announce.intentions[at]
		var kind := announce.intentions[at + 1]
		var target := announce.intentions[at + 2]
		var view := state.view()
		var target_tile := view.unit_tile(target) if kind == IntentionsSlice.TARGET_UNIT else view.node_tile(target)
		assert(target_tile >= 0, "validation let through an unknown target")
		var id := AiWrites.announce_intention(state, author, view.unit_tile(author), kind, target, target_tile,
				announce.intentions[at + 3], announce.intentions[at + 4])
		var siege := announce.siege_count if kind == IntentionsSlice.TARGET_NODE and target == announce.siege_node else 0
		result.events.append(IntentionAnnouncedEvent.new(id, author, kind, target, target_tile, announce.intentions[at + 4], siege))
	for index in announce.agents.size() / AnnounceIntentionsCommand.AGENT_WIDTH:
		var at := index * AnnounceIntentionsCommand.AGENT_WIDTH
		AiWrites.set_agent(state, announce.agents[at], announce.agents[at + 1], announce.agents[at + 2],
				announce.agents[at + 3], announce.agents[at + 4])
	AiWrites.set_siege(state, announce.siege_node, announce.siege_count)
	AiWrites.mark_announced(state)
	return result


static func _invalid(index: int) -> ValidationResult:
	return ValidationResult.refused(Refusal.INVALID_ANNOUNCEMENT, PackedInt64Array([index]))


## [author, target_kind, target_id, action, motive].
func _intention_ok(view: StateView, values: PackedInt64Array, rules: RuleTable) -> bool:
	var author := values[0]
	var catalog := rules.catalog
	if view.unit_faction(author) != Faction.AI or view.unit_asleep(author) or view.announced_this_turn(author):
		return false
	if values[4] < 0 or values[4] >= IntentionsSlice.MOTIVE_COUNT:
		return false
	var author_tile := view.unit_tile(author)
	var target := values[2]
	if values[3] == IntentionsSlice.ACTION_ATTACK:
		if values[1] != IntentionsSlice.TARGET_UNIT or values[4] == IntentionsSlice.MOTIVE_CAPTURE:
			return false
		var type := view.unit_type(author)
		if ProtocolEffects.unit_stat(view, Faction.AI, type, ProtocolEffects.ATTACK, catalog) == 0:
			return false
		var target_tile := view.unit_tile(target)
		if target_tile < 0 or view.unit_asleep(target) or view.unit_faction(target) != Faction.PLAYER:
			return false
		return CombatRules.distance(view.width(), author_tile, target_tile) <= catalog.units.attack_range(type)
	if values[3] == IntentionsSlice.ACTION_CAPTURE:
		return values[1] == IntentionsSlice.TARGET_NODE and values[4] == IntentionsSlice.MOTIVE_CAPTURE \
				and catalog.units.can_capture(view.unit_type(author)) and view.node_at(author_tile) == target \
				and target >= 0 and view.node_owner(target) != Faction.AI
	return false


func _siege_ok(view: StateView, announce: AnnounceIntentionsCommand) -> bool:
	if announce.siege_node < 0:
		return announce.siege_count == 0
	# The node is known and not the AI's: the capture intention that carries it was checked.
	if announce.siege_count == 1:
		return view.turn() < view.max_turn() - 1
	return announce.siege_count == SIEGE_STEPS and view.siege_node() == announce.siege_node and view.siege_count() == 1


## [unit, role, idle_turns, post_tile, motive].
func _agent_ok(view: StateView, values: PackedInt64Array) -> bool:
	return view.unit_faction(values[0]) == Faction.AI \
			and values[1] >= 0 and values[1] < AiAgentsSlice.ROLE_COUNT and values[2] >= 0 \
			and values[3] >= AiAgentsSlice.NO_POST and values[3] < view.tile_count() \
			and (values[4] == AiAgentsSlice.NO_MOTIVE or (values[4] >= 0 and values[4] < IntentionsSlice.MOTIVE_COUNT))
