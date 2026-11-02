# The PacingGate of the match (ADR-0005 §3): the AI sends its next command only when the
# sequencer is idle and its queue empty, so the player watches one action at a time. The
# time spent presenting never changes which command is chosen, only when it is sent.
class_name SequencerPacingGate
extends PacingGate

var _sequencer: PresentationSequencer


func _init(sequencer: PresentationSequencer) -> void:
	_sequencer = sequencer


func is_ready() -> bool:
	return _sequencer.is_idle()
