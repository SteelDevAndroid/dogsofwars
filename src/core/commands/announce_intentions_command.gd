# ANNONCER_LES_INTENTIONS (GDD 9 step 6, ADR-0005 §2 and §5, GDD 23): internal command
# of the AI system, emitted by SYS at the end of the enemy phase. Pure data: the
# intentions to store and the new role, siege and counter values (the command log
# alone rebuilds them, the planner is never replayed). Tiles are not carried; the
# application reads them from the state.
# Flat layout: [siege_node, siege_count, n, n x (author, target_kind, target_id, action,
# motive), m, m x (unit, role, idle_turns, post_tile, motive)].
class_name AnnounceIntentionsCommand
extends Command

const INTENTION_WIDTH := 5
const AGENT_WIDTH := 5

var siege_node: int
var siege_count: int
## Flat, INTENTION_WIDTH integers per intention.
var intentions: PackedInt64Array
## Flat, AGENT_WIDTH integers per agent.
var agents: PackedInt64Array


func _init(p_siege_node: int = -1, p_siege_count: int = 0, p_intentions: PackedInt64Array = PackedInt64Array(),
		p_agents: PackedInt64Array = PackedInt64Array()) -> void:
	faction = Faction.AI
	emitter = EMITTER_SYS
	siege_node = p_siege_node
	siege_count = p_siege_count
	intentions = p_intentions
	agents = p_agents


func type() -> int:
	return CommandType.ANNOUNCE_INTENTIONS


func params() -> PackedInt64Array:
	var values := PackedInt64Array([siege_node, siege_count, intentions.size() / INTENTION_WIDTH])
	values.append_array(intentions)
	values.append(agents.size() / AGENT_WIDTH)
	values.append_array(agents)
	return values


static func from_params(p_faction: int, p_emitter: int, values: PackedInt64Array) -> AnnounceIntentionsCommand:
	if values.size() < 4 or values[2] < 0:
		return null
	var n := values[2]
	var after := 3 + n * INTENTION_WIDTH
	if values.size() <= after or values[after] < 0 or values.size() != after + 1 + values[after] * AGENT_WIDTH:
		return null
	var command := AnnounceIntentionsCommand.new(values[0], values[1], values.slice(3, after), values.slice(after + 1))
	command.faction = p_faction
	command.emitter = p_emitter
	return command
