# Immutable vision context (ADR-0007 §3): field table of the map, view radii, and
# the factions that `apply` recomputes ([PLAYER, AI] for the real rules, [] for
# the simulation variant, ADR-0007 §8).
class_name VisionContext
extends RefCounted

var fields: FieldTable
## View radius by unit type (UnitTypes, ADR-0009).
var view_radius: PackedInt32Array
## View radius by node level, index = level (GDD 5 rule 7: max(2, RAYON_NIVEAU)).
var node_radius: PackedInt32Array
var factions: PackedInt32Array


func _init(p_fields: FieldTable, p_view_radius: PackedInt32Array, p_node_radius: PackedInt32Array,
		p_factions: PackedInt32Array) -> void:
	fields = p_fields
	view_radius = p_view_radius
	node_radius = p_node_radius
	factions = p_factions


## Pure: field table over the terrain of `state`, every faction recomputed. Takes
## the radii until DataCatalog exists; then reads them from catalog.units (ADR-0009).
static func for_map(state: GameState, unit_view_radius: PackedInt32Array,
		node_view_radius: PackedInt32Array) -> VisionContext:
	var largest := 0
	for r in unit_view_radius:
		largest = maxi(largest, r)
	for r in node_view_radius:
		largest = maxi(largest, r)
	var table := FieldTable.new(state.terrain, state.width(), state.height(), largest + 1)
	var all := PackedInt32Array(range(state.faction_count()))
	return VisionContext.new(table, unit_view_radius, node_view_radius, all)


## Same fields and radii, no faction recomputed.
func simulation() -> VisionContext:
	return VisionContext.new(fields, view_radius, node_radius, PackedInt32Array())
