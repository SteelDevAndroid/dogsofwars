# The order of the steps of a batch (ADR-0002: the order is code, one function per kind of
# sequence). A ruin reading plays: the colour wave first, then the delay, then the panel
# (hud.md rule 15), whatever order the Core published the events in, the camera going to the
# ruin before everything.
class_name SequenceOrder
extends RefCounted


## The steps to play for a batch: events and pauses.
static func steps(batch: EventBatch, params: PresentationParams) -> Array[PresentationEvent]:
	var ordinary: Array[PresentationEvent] = []
	var readings: Array[PresentationEvent] = []
	for event in batch.events:
		if event is RuinReadEvent:
			readings.append(event)
		else:
			ordinary.append(event)
	if not readings.is_empty():
		ordinary.push_front(PresentationRecenter.new((readings[0] as RuinReadEvent).tile))  # the camera first
	for reading in readings:
		ordinary.append(PresentationPause.new(params.value("panel_delay_ms")))
		ordinary.append(reading)
	return ordinary
