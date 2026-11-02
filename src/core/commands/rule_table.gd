# The command rules (ADR-0004 §2): handlers indexed by CommandType, built once,
# immutable, with the data catalog and the vision context. The real variant
# serves `submit` on the real state; simulation() serves everything applied on a
# copy (preview, apply_on, AI planning), with no vision recompute (ADR-0007 §8).
class_name RuleTable
extends RefCounted

var catalog: DataCatalog
var vision: VisionContext
var _handlers: Array[CommandHandler] = []


func _init(p_catalog: DataCatalog, p_vision: VisionContext, p_handlers: Array[CommandHandler]) -> void:
	catalog = p_catalog
	vision = p_vision
	_handlers = p_handlers


## The rules of the game. UNDO_MOVE belongs to the pipeline (it owns the UndoSlot).
static func standard(p_catalog: DataCatalog, p_vision: VisionContext) -> RuleTable:
	var handlers: Array[CommandHandler] = []
	handlers.resize(CommandType.COUNT)
	handlers[CommandType.MOVE] = MoveHandler.new()
	handlers[CommandType.ATTACK] = AttackHandler.new()
	handlers[CommandType.CAPTURE] = CaptureHandler.new()
	handlers[CommandType.WAKE] = WakeHandler.new()
	handlers[CommandType.UPGRADE_NODE] = UpgradeNodeHandler.new()
	handlers[CommandType.ANNOUNCE_INTENTIONS] = AnnounceIntentionsHandler.new()
	handlers[CommandType.BEGIN_TURN] = BeginTurnHandler.new()
	handlers[CommandType.END_TURN] = EndTurnHandler.new()
	handlers[CommandType.RESEARCH] = ResearchHandler.new()
	handlers[CommandType.ABANDON] = AbandonHandler.new()
	return RuleTable.new(p_catalog, p_vision, handlers)


func simulation() -> RuleTable:
	return RuleTable.new(catalog, vision.simulation(), _handlers)


func has_handler(type: int) -> bool:
	return type >= 0 and type < _handlers.size() and _handlers[type] != null


func registered_types() -> PackedInt32Array:
	var types := PackedInt32Array()
	for type in _handlers.size():
		if _handlers[type] != null:
			types.append(type)
	return types


func validate(view: StateView, command: Command) -> ValidationResult:
	if not has_handler(command.type()):
		return ValidationResult.refused(Refusal.UNKNOWN_COMMAND)
	return _handlers[command.type()].validate(view, command, self)


## Only after a permitted validation of the same command on the same state.
func apply(state: GameState, command: Command) -> ApplyResult:
	return _handlers[command.type()].apply(state, command, self)


## Tiles where DÉPLACER of the unit is permitted by `validate` (no refusal prefix,
## ADR-0010 §7); empty when the unit itself cannot move.
func check_move_range(view: StateView, faction: int, unit_id: int) -> PackedInt32Array:
	if MoveHandler.unit_error(view, faction, unit_id, catalog) != &"":
		return PackedInt32Array()
	return MovementRules.move_range(view, unit_id, catalog)
