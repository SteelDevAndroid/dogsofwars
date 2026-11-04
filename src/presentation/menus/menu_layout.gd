# Shared layout of the menu screens: one column of fixed width, centred in the screen (a box
# anchored on the centre grows to the right and down and leaves the screen on a phone), and
# touch-sized buttons (hud.md: 48 pt at least).
class_name MenuLayout
extends RefCounted

const WIDTH := 300.0
const BUTTON_HEIGHT := 56.0
## The dark navy of the art bible: the ground of every menu screen.
const NAVY := Color("0E1422")


## The column of `screen`, centred, `width` wide (and below `top_share` of the height, to leave a logo room) (never wider than the screen allows: the
## labels inside wrap).
static func column(screen: Control, width: float = WIDTH, top_share: float = 0.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_top = top_share  # the column is centred in the part of the screen below this share
	center.offset_top = 0.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(width, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	return box


static func button(parent: Control, text: String, action: Callable, icon_name: String = "") -> Button:
	var button := Button.new()
	button.text = text
	if icon_name != "":
		UiIcons.put(button, icon_name)
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


const ARTWORK_PORTRAIT := "res://assets/ui/splash.png"
const ARTWORK_LANDSCAPE := "res://assets/ui/splash_landscape.png"
## The share of the artwork's height above its title ("DOGS OF GODS" is painted in it, below the
## face). A menu keeps that part only: its buttons would sit on the title.
const ABOVE_TITLE_PORTRAIT := 0.58
const ABOVE_TITLE_LANDSCAPE := 0.50


## The artwork that fits a screen: the portrait picture, or the landscape one when the screen is
## wider than tall; whole (the title screen) or only above its title (the menus).
static func artwork(landscape: bool, above_title_only: bool) -> Texture2D:
	var full: Texture2D = load(ARTWORK_LANDSCAPE if landscape else ARTWORK_PORTRAIT)
	if not above_title_only:
		return full
	var atlas := AtlasTexture.new()
	atlas.atlas = full
	atlas.region = Rect2(0, 0, full.get_width(), full.get_height() * (ABOVE_TITLE_LANDSCAPE if landscape else ABOVE_TITLE_PORTRAIT))
	return atlas


## A picture of the artwork that fills `screen` and changes with its orientation (a phone turned).
static func artwork_picture(screen: Control, above_title_only: bool) -> TextureRect:
	var picture := TextureRect.new()
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture = artwork(false, above_title_only)
	picture.resized.connect(func() -> void:
		var landscape := picture.size.x > picture.size.y
		var wanted := artwork(landscape, above_title_only)
		if picture.texture == null or _source_of(picture.texture) != _source_of(wanted):
			picture.texture = wanted)
	screen.add_child(picture)
	return picture


static func _source_of(texture: Texture2D) -> Texture2D:
	return (texture as AtlasTexture).atlas if texture is AtlasTexture else texture


## The artwork of the title screen behind a menu, dimmed so the buttons read.
static func illustrated_backdrop(screen: Control, dim: float = 0.62) -> void:
	var base := ColorRect.new()
	base.color = Color(0.0863, 0.0863, 0.1098)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(base)
	artwork_picture(screen, true)
	var veil := ColorRect.new()
	veil.color = Color(0.055, 0.078, 0.133, dim)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(veil)


## The main action of a screen: filled with the pack's teal.
static func make_primary(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = {"normal": Color("1FA38F"), "hover": Color("2BB8A2"), "pressed": Color("178272"), "disabled": Color(0.25, 0.28, 0.32, 0.8)}[state]
		style.set_corner_radius_all(4)
		style.set_content_margin_all(10)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("0E1422"))
	button.add_theme_color_override("font_hover_color", Color("0E1422"))
	button.add_theme_color_override("font_pressed_color", Color("0E1422"))
	button.add_theme_color_override("font_disabled_color", Color(0.7, 0.72, 0.75))
	button.add_theme_font_size_override("font_size", 20)


## A secondary action: smaller, the theme's own look.
static func make_secondary(button: Button) -> void:
	button.custom_minimum_size = Vector2(0, 48)


## The panel frame of the interface (ui_panneau.png: corner brackets, nearly transparent centre), a
## nine-patch with 24 px margins, for cards that stand on a dark ground.
static func framed_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/art/ui/ui_panneau.png")
	style.set_texture_margin_all(24)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	return panel


## A label that wraps inside the column.
static func label(parent: Control, text: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label
