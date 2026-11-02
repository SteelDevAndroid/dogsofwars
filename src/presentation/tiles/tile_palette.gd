# Colours of the map (art bible, section 4); the terrain itself is the delivered textures
# (assets/art/terrain, whose palette is #4E5862 plain, #66717C forest, #808B96 mountain, #2B323A water). The ownership colour is never the only signal:
# the renderer adds a shape or a pattern for each state.
class_name TilePalette
extends RefCounted

const FOG := Color("1E2329")
const PLAYER := Color("1FA38F")
const ENEMY := Color("C49BEA")
const ENEMY_OUTLINE := Color("B07CE0")
const THREAT := Color("FF6A3D")
const RUIN := Color("C8955A")
const NEUTRAL := Color("A3ACB5")
## The colour-blind palette (art bible 4, hud.md 10.5): the sides and the unclaimed grey change,
## threat and ruins do not.
const PLAYER_ALT := Color("3A8EE6")
const ENEMY_ALT := Color("F0DC6E")
const NEUTRAL_ALT := Color("5F6266")
const OUTLINE := Color("1E2329")
const SELECTION := Color("EADFC8")
## An explored tile that is not in view is dimmed.
const MEMORY_DIM := 0.55


static func owner(faction: int, colorblind: bool = false) -> Color:
	match faction:
		Faction.PLAYER:
			return PLAYER_ALT if colorblind else PLAYER
		Faction.AI:
			return ENEMY_ALT if colorblind else ENEMY
	return NEUTRAL_ALT if colorblind else NEUTRAL
