# PacingGate that never holds the AI runner back (ADR-0005 §3).
class_name AlwaysReadyPacingGate
extends PacingGate


func is_ready() -> bool:
	return true
