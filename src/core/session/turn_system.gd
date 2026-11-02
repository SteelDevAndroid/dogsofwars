# The turn system's driver (GDD 3, ADR-0005 §3, ADR-0008 §6): it emits the internal turn
# commands and hands the enemy phase to the AI runner. The stored phase says what comes
# next, so the same entry serves a new game and a loaded one:
#   CRÉÉE -> COMMENCER_LE_TOUR(joueur); PHASE_JOUEUR -> wait for the player;
#   FIN_DE_TOUR -> COMMENCER_LE_TOUR(IA) then the runner; EXÉCUTION_ENNEMIE -> the runner
#   resumes at the next command; TERMINÉE -> nothing.
# When the runner reports the end of the phase, COMMENCER_LE_TOUR(joueur) opens the next turn.
class_name TurnSystem
extends RefCounted

var _state: GameState
var _pipeline: CommandPipeline
var _ai: AiRunnerPort
var _pacing: PacingGate
var _catalog: DataCatalog


func _init(state: GameState, pipeline: CommandPipeline, ai: AiRunnerPort, pacing: PacingGate, catalog: DataCatalog) -> void:
	_state = state
	_pipeline = pipeline
	_ai = ai
	_pacing = pacing
	_catalog = catalog
	_ai.on_turn_finished = _on_ai_finished


## After a new game or a load (and `pipeline.on_state_loaded()`): do what the phase asks.
func start() -> void:
	match _state.header.value(HeaderSlice.PHASE):
		HeaderSlice.PHASE_CREATED:
			_pipeline.submit(BeginTurnCommand.new(Faction.PLAYER))
		HeaderSlice.PHASE_END_OF_TURN:
			_begin_enemy_phase()
		HeaderSlice.PHASE_ENEMY_EXECUTION:
			_ai.resume(_state, _pipeline, _pacing, _catalog)


## The player ends their turn (FINIR_LE_TOUR), then the enemy phase begins.
func end_player_turn() -> ValidationResult:
	var result := _pipeline.submit(EndTurnCommand.new())
	if result.permitted:
		_begin_enemy_phase()  # without a permitted FINIR_LE_TOUR the phase is wrong and the next command is refused anyway
	return result


## Breaks the references that would keep the session alive (ADR-0008 §6 step 3).
func shutdown() -> void:
	_ai.cancel()
	_ai.on_turn_finished = Callable()
	_ai = null
	_pipeline = null
	_state = null


func _begin_enemy_phase() -> void:
	if _pipeline.submit(BeginTurnCommand.new(Faction.AI)).permitted:
		_ai.start_turn(_state, _pipeline, _pacing, _catalog)


func _on_ai_finished() -> void:
	if _state != null and _state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_ENEMY_EXECUTION:
		_pipeline.submit(BeginTurnCommand.new(Faction.PLAYER))
