# PacingGate that is always ready: the AI runner sends one command per call without waiting
# for an animation. Used until the presentation sequencer provides its own gate.
class_name ImmediatePacingGate
extends PacingGate


func is_ready() -> bool:
	return true
