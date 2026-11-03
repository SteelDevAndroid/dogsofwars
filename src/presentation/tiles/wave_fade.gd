# The binary fade of a recolouring tile (GDD 15 rules 14 and 15, F5): the tile is never a mix of
# two tints. It is one tint at a saturation s from 0 (grey) to 1000. From a tint `from_owner` at
# `from_s` it goes to `to_owner` at 1000: the old tint fades to grey, then the new one rises from
# grey. A rewrite during a fade starts from the saturation currently shown, so it never jumps.
# Pure integer arithmetic of milliseconds, the same on every run.
class_name WaveFade
extends RefCounted


## [tint shown (a Faction), saturation 0..1000] `u_ms` into a fade of `fade_ms` (T_FONDU) that
## starts at (from_owner, from_s) and ends at (to_owner, 1000); to_owner NONE is the grey.
## A grey tile (from_owner NONE) has no saturation.
static func shown(from_owner: int, from_s: int, to_owner: int, u_ms: int, fade_ms: int) -> Vector2i:
	var start := 0 if from_owner == Faction.NONE else clampi(from_s, 0, 1000)
	if start == 0:
		from_owner = Faction.NONE  # a tile faded to nothing is grey whatever tint it came from
	var u := clampi(u_ms, 0, fade_ms)
	if to_owner == Faction.NONE:  # to grey: descent in D x s div 1000 ms
		var descent := fade_ms * start / 1000
		return Vector2i(from_owner, 0 if descent == 0 or u >= descent else start - start * u / descent)
	if to_owner == from_owner or from_owner == Faction.NONE:  # same tint, or from grey: rise
		var rise := fade_ms * (1000 - start) / 1000
		return Vector2i(to_owner, 1000 if rise == 0 or u >= rise else start + (1000 - start) * u / rise)
	var half_down := fade_ms / 2  # another tint: down in H1 x s div 1000 ms, then up in H2
	var half_up := fade_ms - half_down
	var down := half_down * start / 1000
	if u <= down and down > 0:
		return Vector2i(from_owner, start - start * u / down)
	var v := u - down
	return Vector2i(to_owner, 1000 if half_up == 0 or v >= half_up else 1000 * v / half_up)
