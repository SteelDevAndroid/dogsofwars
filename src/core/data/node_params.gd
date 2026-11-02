# Node tuning (GDD 11, domain `noeuds`): territory radius by level (RAYON_NIVEAU) and
# the price of each upgrade (PRIX_MONTÉE, level 1 to 2, 2 to 3).
class_name NodeParams
extends RefCounted

const SCHEMA_VERSION := 1
const MAX_LEVELS := 5

const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"territory_radius": {"kind": &"array", "min": 1, "max": MAX_LEVELS,
		"item": {"kind": &"int", "min": 1, "max": 4}},
	"upgrade_price": {"kind": &"array", "min": 1, "max": MAX_LEVELS - 1,
		"item": {"kind": &"int", "min": 1, "max": 99}},
}

## Index level - 1.
var _territory_radius := PackedInt32Array()
## Index level - 1: the price to go from `level` to `level + 1`.
var _upgrade_price := PackedInt32Array()


static func build(data: Dictionary, file: String, errors: Array[DataError]) -> NodeParams:
	var params := NodeParams.new()
	var radii: Array = data["territory_radius"]
	for k in radii.size():
		if k > 0 and radii[k] < radii[k - 1]:
			errors.append(DataError.new(file, "territory_radius[%d]" % k, "radius decreases with the level"))
		params._territory_radius.append(radii[k])
	var prices: Array = data["upgrade_price"]
	if prices.size() != radii.size() - 1:
		errors.append(DataError.new(file, "upgrade_price", "%d prices, expected one per upgrade (%d)" % [prices.size(), radii.size() - 1]))
	for price: int in prices:
		params._upgrade_price.append(price)
	return params


func max_level() -> int:
	return _territory_radius.size()


## Price of the upgrade from `level` (1..max_level() - 1) to the next one.
func upgrade_price(level: int) -> int:
	return _upgrade_price[level - 1]


## Territory radius of a level 1..max_level().
func territory_radius(level: int) -> int:
	return _territory_radius[level - 1]
