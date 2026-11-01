# Immutable vision context (ADR-0007 §3): field table of the map, view radii from
# the data catalog, and the factions that `apply` recomputes ([PLAYER, AI] for the
# real rules, [] for the simulation variant, ADR-0007 §8).
class_name VisionContext
extends RefCounted

var fields: FieldTable
## View radius by unit type (catalog.units).
var view_radius: PackedInt32Array
## View radius by node level, index = level (GDD 5 rule 7: max(node_view_min, territory)).
var node_radius: PackedInt32Array
var mountain_bonus: int
var factions: PackedInt32Array


func _init(p_fields: FieldTable, p_view_radius: PackedInt32Array, p_node_radius: PackedInt32Array,
		p_mountain_bonus: int, p_factions: PackedInt32Array) -> void:
	fields = p_fields
	view_radius = p_view_radius
	node_radius = p_node_radius
	mountain_bonus = p_mountain_bonus
	factions = p_factions


## Pure: field table over the terrain of `state`, radii from the catalog, every
## faction recomputed.
static func for_map(catalog: DataCatalog, state: GameState) -> VisionContext:
	var units := catalog.units.vision_radii()
	var nodes := PackedInt32Array([0])
	for level in range(1, catalog.nodes.max_level() + 1):
		nodes.append(maxi(catalog.fog.node_view_min(), catalog.nodes.territory_radius(level)))
	var largest := 0
	for r in units:
		largest = maxi(largest, r)
	for r in nodes:
		largest = maxi(largest, r)
	var bonus := catalog.fog.mountain_view_bonus()
	var table := FieldTable.new(state.terrain, state.width(), state.height(), largest + bonus)
	return VisionContext.new(table, units, nodes, bonus, PackedInt32Array(range(state.faction_count())))


## Same fields and radii, no faction recomputed.
func simulation() -> VisionContext:
	return VisionContext.new(fields, view_radius, node_radius, mountain_bonus, PackedInt32Array())


## Every faction recomputed (match setup).
func all_factions(faction_count: int) -> VisionContext:
	return VisionContext.new(fields, view_radius, node_radius, mountain_bonus, PackedInt32Array(range(faction_count)))
