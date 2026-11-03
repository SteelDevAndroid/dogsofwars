# The source of a colour wave as the player may know it (GDD 15 F7, rules 12 and 18): the
# source tile when the player sees it, else the changed tile the player sees that is nearest
# to it (Chebyshev, then lowest tile index), else none. The event carries only this tile, so
# the presentation can place the rings without learning where a hidden node stands.
class_name WaveSource
extends RefCounted


## `source` for the player's view after the command, -1 when no changed tile is visible.
static func effective(state: GameState, tiles: PackedInt32Array, source: int) -> int:
	var cache := state.view_cache
	if VisionService.can_see(cache, Faction.PLAYER, source):
		return source
	var width := state.view().width()
	var best := -1
	var best_distance := 0
	for tile in tiles:
		if not VisionService.can_see(cache, Faction.PLAYER, tile):
			continue
		var distance := CombatRules.distance(width, source, tile)
		if best < 0 or distance < best_distance or (distance == best_distance and tile < best):
			best = tile
			best_distance = distance
	return best


## Sets the effective source of every tile owner event of a command; call it once the view
## of the command is recomputed.
static func stamp(events: Array[PresentationEvent], source: int, state: GameState) -> void:
	for event in events:
		if event is TileOwnersChangedEvent:
			var changed := event as TileOwnersChangedEvent
			changed.source_tile = effective(state, changed.changed_tiles, source)
