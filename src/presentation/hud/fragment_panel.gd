# The fragment panel (hud.md rule 15, GDD 13 rule 15): it opens once the colour wave is over,
# blocks the player's commands, and is closed by "Continuer", ignored until `close_delay` after
# it opened. "Voir la carte" folds it to a tab at the top of the screen so the map can be looked
# at (scrolled, zoomed); the commands stay blocked until "Continuer", and the tab unfolds it. It shows the title, the in-world source and the text of the
# fragment (the content of the pool); without a text it falls back to the fragment's number.
# The text scrolls inside the panel rather than being cut (hud.md 10.2).
class_name FragmentPanel
extends PanelContainer

signal closed

var title_label := Label.new()
var source_label := Label.new()
var body_label := Label.new()
var scroll := ScrollContainer.new()
var continue_button := Button.new()
var fold_button := Button.new()
## The folded panel: one button that unfolds it.
var tab_button := Button.new()
var is_open := false
var folded := false

var _box := VBoxContainer.new()

var _opened_at := 0.0
var _close_delay := 0.5


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(340, 0)
	var style := StyleBoxFlat.new()
	# the register of memory: a sheet of paper (the only textured-looking thing of the interface), dark ink
	style.bg_color = Color("EADFC8")
	style.border_color = Color("C8955A")
	style.set_border_width_all(3)
	style.set_content_margin_all(18)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	add_theme_stylebox_override("panel", style)
	var box := _box
	add_child(box)
	var ink := Color("1E2329")
	title_label.add_theme_color_override("font_color", ink)
	title_label.add_theme_font_size_override("font_size", 22)
	source_label.add_theme_color_override("font_color", Color("6B5A3E"))
	source_label.add_theme_font_size_override("font_size", 14)
	body_label.add_theme_color_override("font_color", ink)
	body_label.add_theme_font_size_override("font_size", 17)
	box.add_child(title_label)
	box.add_child(source_label)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.add_child(body_label)
	box.add_child(scroll)
	continue_button.text = "Continuer"
	continue_button.custom_minimum_size = Vector2(0, 52)
	MenuLayout.make_primary(continue_button)
	continue_button.pressed.connect(close)
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fold_button.text = "Voir la carte"
	fold_button.custom_minimum_size = Vector2(0, 52)
	fold_button.pressed.connect(fold)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.add_child(fold_button)
	buttons.add_child(continue_button)
	box.add_child(buttons)
	tab_button.text = "Fragment : reprendre la lecture"
	tab_button.custom_minimum_size = Vector2(0, 48)
	tab_button.add_theme_color_override("font_color", ink)
	tab_button.flat = true
	tab_button.visible = false
	tab_button.pressed.connect(unfold)
	add_child(tab_button)


func open(fragment_id: int, now: float, close_delay: float, title: String = "", text: String = "", source: String = "") -> void:
	is_open = true
	_opened_at = now
	_close_delay = close_delay
	title_label.text = title if title != "" else "Fragment %d" % fragment_id
	source_label.text = source
	source_label.visible = source != ""
	body_label.text = text if text != "" else "Un fragment rejoint la chronique."
	scroll.scroll_vertical = 0
	continue_button.disabled = true
	visible = true
	_set_folded(false)


## Folds the panel to its tab at the top of the screen: the map shows, the commands stay blocked.
func fold() -> void:
	if is_open:
		_set_folded(true)


func unfold() -> void:
	if is_open:
		_set_folded(false)


func _set_folded(on: bool) -> void:
	folded = on
	_box.visible = not on
	tab_button.visible = on
	custom_minimum_size = Vector2(0, 0) if on else Vector2(340, 0)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP if on else Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_END if on else Control.GROW_DIRECTION_BOTH
	reset_size()


## The button is dead until the close delay has passed.
func tick(now: float) -> void:
	if is_open:
		continue_button.disabled = now < _opened_at + _close_delay


func close() -> void:
	if not is_open or continue_button.disabled:
		return
	is_open = false
	_set_folded(false)
	visible = false
	closed.emit()
