# The HUD presenter (ADR-0002 §5): the journal of the enemy turn, the notice of a ruin read
# without a fragment, and the fragment panel with its lock. The numbers of the HUD (turn,
# energy, score, chips) are redrawn from the state when a batch is over, not here.
class_name HudPresenter
extends PresentationHandler

## Lines of the enemy-turn journal, oldest first; emptied when the player's turn begins.
var journal: Array[String] = []
## "Ruine lue · +n tuiles" when a ruin gave no fragment; emptied with the journal.
var notice := ""

const SUMMARY_SECONDS := 4.0

var _hud: Hud
var _gate: CommandGate
var _sequencer: PresentationSequencer
var _params: PresentationParams
var _fragments: FragmentPool
var _wave_tiles := 0
## What the player saw of the enemy phase, told as a line when their turn begins.
var summary := ""
## Where the summary points, -1 for nowhere: the first drone lost, else the first node taken,
## else the first threat announced (tiles of events the fog let through).
var summary_tile := -1
var _enemy_played := false
var _lost := 0
var _kills := 0
var _nodes_taken := 0
var _threats := 0
var _lost_tile := -1
var _taken_tile := -1
var _threat_tile := -1


func _init(hud: Hud, gate: CommandGate, sequencer: PresentationSequencer, params: PresentationParams, fragments: FragmentPool = null) -> void:
	_fragments = fragments
	_hud = hud
	_gate = gate
	_sequencer = sequencer
	_params = params


func handle(event: PresentationEvent, context: SequenceContext) -> PresentationHold:
	if event is TurnStartedEvent and (event as TurnStartedEvent).turn_faction == Faction.AI:
		_enemy_played = true
		_lost = 0
		_kills = 0
		_nodes_taken = 0
		_threats = 0
		_lost_tile = -1
		_taken_tile = -1
		_threat_tile = -1
	if event is UnitDestroyedEvent:
		if event.faction == Faction.PLAYER:
			_lost += 1
			if _lost_tile < 0:
				_lost_tile = (event as UnitDestroyedEvent).tile
		else:
			_kills += 1
	elif event is NodeCapturedEvent and event.faction == Faction.AI:
		_nodes_taken += 1
		if _taken_tile < 0:
			_taken_tile = (event as NodeCapturedEvent).tile
	elif event is IntentionAnnouncedEvent:
		_threats += 1
		if _threat_tile < 0:
			_threat_tile = (event as IntentionAnnouncedEvent).target_tile
	if event is TurnStartedEvent and (event as TurnStartedEvent).turn_faction == Faction.PLAYER:
		journal.clear()
		notice = ""
		summary = enemy_phase_line(_lost, _kills, _nodes_taken, _threats) if _enemy_played else ""
		summary_tile = -1
		if summary != "":
			summary_tile = _lost_tile if _lost_tile >= 0 else (_taken_tile if _taken_tile >= 0 else _threat_tile)
		_enemy_played = false
		if summary != "":
			_hud.show_toast(summary, context.t0, SUMMARY_SECONDS, summary_tile)
		return PresentationHold.new(0)
	if event is TileOwnersChangedEvent:
		_wave_tiles += (event as TileOwnersChangedEvent).changed_tiles.size()
		return PresentationHold.new(0)
	if event is RuinReadEvent:
		var read := event as RuinReadEvent
		if read.fragment_id > 0:
			var delay: float = _params.value("close_delay_ms") / 1000.0
			if _fragments != null:
				_hud.fragment_panel.open(read.fragment_id, context.t0, delay, _fragments.title_of(read.fragment_id),
						_fragments.text_of(read.fragment_id), _fragments.source_of(read.fragment_id))
			else:
				_hud.fragment_panel.open(read.fragment_id, context.t0, delay)
			_gate.lock(PresentationSequencer.FRAGMENT_PANEL)
			_sequencer.panel_open = true
		else:
			notice = "Ruine lue · +%d tuiles" % _wave_tiles if _wave_tiles > 0 else "Ruine lue"
		_wave_tiles = 0
		return PresentationHold.new(0)
	var line := HudModel.journal_line(event)
	if line != "":
		journal.append(line)
		if journal.size() > HudModel.JOURNAL_LINES:
			journal.pop_front()
	# the enemy's actions are told one at a time
	var holds := event is IntentionExecutedEvent and not context.direct
	return PresentationHold.new(_params.value("enemy_action_ms") if holds else 0)


## "Tour ennemi : 1 drone perdu · 2 menaces annoncées", or that nothing happened.
static func enemy_phase_line(lost: int, kills: int, nodes_taken: int, threats: int) -> String:
	var parts: Array[String] = []
	if lost > 0:
		parts.append("%d drone%s perdu%s" % [lost, "s" if lost > 1 else "", "s" if lost > 1 else ""])
	if kills > 0:
		parts.append("%d Gardien%s détruit%s" % [kills, "s" if kills > 1 else "", "s" if kills > 1 else ""])
	if nodes_taken > 0:
		parts.append("%d nœud%s pris par l'ennemi" % [nodes_taken, "s" if nodes_taken > 1 else ""])
	if threats > 0:
		parts.append("%d menace%s annoncée%s" % [threats, "s" if threats > 1 else "", "s" if threats > 1 else ""])
	return "Tour ennemi : " + (" · ".join(parts) if not parts.is_empty() else "rien à signaler")


func rebuild_from_state(_state: GameState) -> void:
	_wave_tiles = 0
