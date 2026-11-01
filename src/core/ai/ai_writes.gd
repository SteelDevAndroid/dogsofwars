# Write functions of the AI system (system 9) on its slices.
class_name AiWrites
extends RefCounted


## curseur_ia (ADR-0005 §5): id of the last AI unit that emitted an ordinary
## command; called by the command layer after the application, never by a handler.
static func set_cursor(state: GameState, unit_id: int) -> void:
	state.ai_cursor._ai_cursor[0] = unit_id
