# Colours of the map (art bible, section 4). The ownership colour is never the only signal:
# the renderer adds a shape or a pattern for each state.
class_name TilePalette
extends RefCounted

const FOG := Color("1E2329")
const PLAIN := Color("4E5862")
const FOREST := Color("66717C")
const MOUNTAIN := Color("808B96")
const WATER := Color("2B323A")
const PLAYER := Color("1FA38F")
const ENEMY := Color("C49BEA")
const ENEMY_OUTLINE := Color("B07CE0")
const THREAT := Color("FF6A3D")
const RUIN := Color("C8955A")
const NEUTRAL := Color("A3ACB5")
const OUTLINE := Color("1E2329")
const SELECTION := Color("EADFC8")
## An explored tile that is not in view is dimmed.
const MEMORY_DIM := 0.55


static func terrain(code: int) -> Color:
	match code:
		TerrainGrid.FOREST:
			return FOREST
		TerrainGrid.MOUNTAIN:
			return MOUNTAIN
		TerrainGrid.WATER:
			return WATER
	return PLAIN


static func owner(faction: int) -> Color:
	match faction:
		Faction.PLAYER:
			return PLAYER
		Faction.AI:
			return ENEMY
	return NEUTRAL
