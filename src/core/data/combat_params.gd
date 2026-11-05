# Combat tuning (GDD 8 constants, domain `combat`) [PROP].
class_name CombatParams
extends RefCounted

const SCHEMA_VERSION := 1

const SCHEMA := {
	"schema_version": {"kind": &"int", "min": SCHEMA_VERSION, "max": SCHEMA_VERSION},
	"dmg_scale": {"kind": &"int", "min": 1, "max": 4},
	"def_base": {"kind": &"int", "min": 3, "max": 6},
	"dmg_min": {"kind": &"int", "min": 1, "max": 2},
	"def_per_tile_class": {"kind": &"int", "min": 0, "max": 2},
	# Embuscade (GDD 8 rule 12): +ATQ of a pack unit that began its turn out of the enemy's sight.
	"ambush_attack_bonus": {"kind": &"int", "min": 0, "max": 2},
}

var _dmg_scale: int
var _def_base: int
var _dmg_min: int
var _def_per_tile_class: int
var _ambush_attack_bonus: int


static func build(data: Dictionary, _file: String, _errors: Array[DataError]) -> CombatParams:
	var params := CombatParams.new()
	params._dmg_scale = data["dmg_scale"]
	params._def_base = data["def_base"]
	params._dmg_min = data["dmg_min"]
	params._def_per_tile_class = data["def_per_tile_class"]
	params._ambush_attack_bonus = data["ambush_attack_bonus"]
	return params


func dmg_scale() -> int:
	return _dmg_scale


func def_base() -> int:
	return _def_base


func dmg_min() -> int:
	return _dmg_min


## DEF_PER_TILE_CLASS: defense bonus per class of the defender's tile.
func def_per_tile_class() -> int:
	return _def_per_tile_class


## Attack bonus of an ambush (a pack unit unseen by the enemy when its turn began).
func ambush_attack_bonus() -> int:
	return _ambush_attack_bonus
