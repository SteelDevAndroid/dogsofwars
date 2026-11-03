# The rings of a colour wave (GDD 15 rules 12 and 13, F3, F4), a pure function of the
# effective source, the changed tiles and the durations: same input, same plan, whatever the
# frame rate. The source comes from the event (`WaveSource`, F7): the presentation never
# reads the state to place a ring.
class_name WaveSchedule
extends RefCounted


## T_ANNEAU_eff = min(T_ANNEAU, (T_TOTAL_MAX - T_FONDU) div K_MAX): no wave outlasts T_TOTAL_MAX.
static func ring_ms(params: PresentationParams) -> int:
	var room: int = maxi(0, params.value("wave_total_max_ms") - params.value("recolor_ms"))
	return mini(params.value("wave_ring_ms"), room / params.value("wave_rings_max"))


## Ring k of a tile: its Chebyshev distance to the source (F3).
static func ring_of(columns: int, source: int, tile: int) -> int:
	return CombatRules.distance(columns, source, tile)


## The plan of a wave spreading from `source` over `tiles` (any order). A tile of ring k starts
## at `min(k, K_MAX) x T_ANNEAU_eff` (F4); rings past K_MAX start together with ring K_MAX.
## No source (-1) or no tile: no step, the colours change at once.
static func plan(columns: int, tiles: PackedInt32Array, source: int, params: PresentationParams) -> WavePlan:
	var result := WavePlan.new()
	if source < 0 or tiles.is_empty():
		return result
	var cap: int = params.value("wave_rings_max")
	var delay := ring_ms(params)
	var groups: Array[PackedInt32Array] = []
	for k in cap + 1:
		groups.append(PackedInt32Array())
	var sorted := tiles.duplicate()
	sorted.sort()  # ascending tile index inside a ring: the rendering order, no time offset
	var k_max := 0
	for tile in sorted:
		var ring := ring_of(columns, source, tile)
		k_max = maxi(k_max, ring)
		groups[mini(ring, cap)].append(tile)
	for k in groups.size():
		if not groups[k].is_empty():
			result.steps.append([k * delay, groups[k]])
	result.duration_ms = mini(cap, k_max) * delay + params.value("recolor_ms")
	return result
