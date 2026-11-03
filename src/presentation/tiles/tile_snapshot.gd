# What the renderer draws, taken from the player's knowledge only (GDD 5, ADR-0007): the
# player's view of the state (FactionView) and the fog level of each tile. An undiscovered
# tile carries nothing, an explored one carries what the player remembers (terrain, last
# owner seen, discovered nodes and ruins, no unit), a visible one everything in view. The
# renderer reads this snapshot and never the real state, so it cannot leak.
class_name TileSnapshot
extends RefCounted

var columns := 0
var rows := 0
## Per tile: VisionService.FOG_*.
var fog := PackedByteArray()
var terrain := PackedByteArray()
## Per tile: last owner seen (Faction.*), Faction.NONE for nobody.
var owners := PackedByteArray()
## Rows [tile, owner, level, visible].
var nodes: Array = []
## Rows [tile, read].
var ruins: Array = []
## Rows [id, tile, faction, type, hp, hp_max, asleep, moved, acted].
var units: Array = []
## Rows [intention id, target kind, target tile, author tile or -1, motive].
var threats: Array = []
## The player's phase: the units that have not played carry a marker.
var player_turn := false


static func take(state: GameState, catalog: DataCatalog) -> TileSnapshot:
	var snapshot := TileSnapshot.new()
	var view := FactionView.new(state, Faction.PLAYER)
	snapshot.columns = view.width()
	snapshot.rows = view.height()
	for tile in view.tile_count():
		var level := VisionService.fog_level(state, Faction.PLAYER, tile)
		snapshot.fog.append(level)
		# The player's view already reads an undiscovered tile as plain and nobody's.
		snapshot.terrain.append(view.terrain_at(tile))
		snapshot.owners.append(view.tile_owner(tile))
	for node_id in view.node_ids():
		var tile := view.node_tile(node_id)
		snapshot.nodes.append([tile, view.node_owner(node_id), view.node_level(node_id), snapshot.fog[tile] == VisionService.FOG_VISIBLE])
	for ruin_id in view.ruin_ids():
		snapshot.ruins.append([view.ruin_tile(ruin_id), state.ruins.is_read(state.ruins.find_row(ruin_id))])
	for unit_id in view.unit_ids():
		var type := view.unit_type(unit_id)
		snapshot.units.append([unit_id, view.unit_tile(unit_id), view.unit_faction(unit_id), type, view.unit_hp(unit_id),
				catalog.units.hp(type), view.unit_asleep(unit_id), view.unit_moved(unit_id), view.unit_acted(unit_id)])
	snapshot.threats = IntentionMarkers.visible_to_player(state)
	snapshot.player_turn = state.header.value(HeaderSlice.PHASE) == HeaderSlice.PHASE_PLAYER
	return snapshot


func fog_at(tile: int) -> int:
	return fog[tile]


## The unit standing on a tile, as its row, or an empty array.
func unit_on(tile: int) -> Array:
	for unit: Array in units:
		if unit[1] == tile:
			return unit
	return []
