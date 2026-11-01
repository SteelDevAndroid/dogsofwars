# Research (GDD 12 rules 6, 7 and 15), owned by system 12: one research at a time
# per faction, advanced at the start of the faction's turn after the income; at 0
# turns left the protocol is acquired and usable at once. The AI researches nothing:
# it receives the protocols of its fixed calendar at the start of its phase.
class_name ResearchRules
extends RefCounted

const NONE := -1


static func advance(state: GameState, faction: int, events: Array[PresentationEvent]) -> void:
	var factions := state.factions
	if factions.is_eliminated(faction) or factions.research_of(faction) == NONE:
		return
	var left := factions.research_turns_of(faction) - 1
	if left > 0:
		factions._fac_research_turns[faction] = left
		return
	var protocol := factions.research_of(faction)
	factions._fac_research_id[faction] = NONE
	factions._fac_research_turns[faction] = 0
	acquire(state, faction, protocol)
	events.append(ResearchCompletedEvent.new(faction, protocol))


## GDD 12 rule 5: research begins with turns left = duration.
static func start(state: GameState, faction: int, protocol: int, duration: int) -> void:
	state.factions._fac_research_id[faction] = protocol
	state.factions._fac_research_turns[faction] = duration


## GDD 12 rule 15: the calendar protocols of `turn` for the AI, without energy or
## prerequisite; an already acquired one is skipped.
static func receive_calendar(state: GameState, turn: int, ai: AiParams, events: Array[PresentationEvent]) -> void:
	if state.factions.is_eliminated(Faction.AI):
		return
	for protocol in ai.calendar_protocols(turn):
		if not state.protocols.has(Faction.AI, protocol):
			acquire(state, Faction.AI, protocol)
			events.append(ResearchCompletedEvent.new(Faction.AI, protocol))


## Inserts (faction, protocol) in the sorted set of acquired protocols.
static func acquire(state: GameState, faction: int, protocol: int) -> void:
	var slice := state.protocols
	var at := 0
	while at < slice.row_count() and (slice.faction_of(at) < faction
			or (slice.faction_of(at) == faction and slice.protocol_of(at) < protocol)):
		at += 1
	slice._proto_faction.insert(at, faction)
	slice._proto_id.insert(at, protocol)
