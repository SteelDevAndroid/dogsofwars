# The icons of the interface (assets/art/ui, white SVG on a 24 x 24 grid, 4 x supersampled by the
# import): a name gives its texture. White, so a Button tints it with its font colour and a
# TextureRect with its modulate.
class_name UiIcons
extends RefCounted

const DIR := "res://assets/art/ui/ui_icon_%s.svg"
const NAMES := ["attaque", "chronique", "energie", "menace", "montee_niveau", "noeud", "pause", "perte", "recentrer",
		"recherche", "reglages", "retour", "reveil", "ruine", "tour", "vitesse", "zoom_moins", "zoom_plus", "mouvement", "defense", "vue"]
## The icon of each stat pill of the unit card.
const STATS := {"MVT": "mouvement", "ATQ": "attaque", "DÉF": "defense", "VUE": "vue"}
## The icon of each action of the context panel.
const ACTIONS := {&"capture": "noeud", &"wake": "reveil", &"upgrade": "montee_niveau"}
## The shown size of an icon beside a text, in pt (the minimum shown size of the art bible is 20).
const SIZE := 22


static func texture(icon_name: String) -> Texture2D:
	return load(DIR % icon_name)


## The icon of a context action, null for one that has none (the research rows).
static func of_action(id: StringName) -> Texture2D:
	return texture(ACTIONS[id]) if ACTIONS.has(id) else null


## An icon on a button, before its text.
static func put(button: Button, icon_name: String) -> void:
	button.icon = texture(icon_name)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", SIZE)
