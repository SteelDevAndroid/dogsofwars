# The rings of one colour wave (GDD 15 F3, F4), computed by `WaveSchedule`: pure data.
class_name WavePlan
extends RefCounted

## Rows [start in ms after the event, tiles that start together, ascending tile index],
## ascending by start. Empty when the colours change at once.
var steps: Array = []
## The wave's length: `min(K_MAX, k_max) x T_ANNEAU_eff + T_FONDU`, 0 without steps.
var duration_ms := 0
