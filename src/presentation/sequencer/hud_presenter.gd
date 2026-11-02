# The HUD presenter (ADR-0002 §5): the journal of the enemy turn, the notice of a ruin read
# without a fragment, and the fragment panel with its lock. The numbers of the HUD (turn,
# energy, score, chips) are redrawn from the state when a batch is over, not here.
class_name HudPresenter
extends PresentationHandler

## Lines of the enemy-turn journal, oldest first; emptied when the player's turn begins.
var journal: Array[String] = []
## "Ruine lue · +n tuiles" when a ruin gave no fragment; emptied with the journal.
var notice := ""

var _hud: Hud
var _gate: CommandGate
var _sequencer: PresentationSequencer
var _params: PresentationParams
var _wave_tiles := 0


func _init(hud: Hud, gate: CommandGate, sequencer: PresentationSequencer, params: PresentationParams) -> void:
	_hud = hud
	_gate = gate
	_sequencer = sequencer
	_params = params


func handle(event: PresentationEvent, context: SequenceContext) -> PresentationHold:
	if event is TurnStartedEvent and (event as TurnStartedEvent).turn_faction == Faction.PLAYER:
		journal.clear()
		notice = ""
		return PresentationHold.new(0)
	if event is TileOwnersChangedEvent:
		_wave_tiles += (event as TileOwnersChangedEvent).changed_tiles.size()
		return PresentationHold.new(0)
	if event is RuinReadEvent:
		var read := event as RuinReadEvent
		if read.fragment_id > 0:
			_hud.fragment_panel.open(read.fragment_id, context.t0, _params.value("close_delay_ms") / 1000.0)
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


func rebuild_from_state(_state: GameState) -> void:
	_wave_tiles = 0
