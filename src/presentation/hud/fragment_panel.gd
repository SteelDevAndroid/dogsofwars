# The fragment panel (hud.md rule 15, GDD 13 rule 15): it opens once the colour wave is over,
# blocks the player's commands, cannot be folded, and is closed by "Continuer", ignored until
# `close_delay` after it opened. The fragment texts belong to the content (not written yet):
# the panel shows the fragment's number for now.
class_name FragmentPanel
extends PanelContainer

signal closed

var title_label := Label.new()
var body_label := Label.new()
var continue_button := Button.new()
var is_open := false

var _opened_at := 0.0
var _close_delay := 0.5


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(330, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1E2329")
	style.border_color = Color("C8955A")
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	add_child(box)
	box.add_child(title_label)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(body_label)
	continue_button.text = "Continuer"
	continue_button.custom_minimum_size = Vector2(0, 50)
	continue_button.pressed.connect(close)
	box.add_child(continue_button)


func open(fragment_id: int, now: float, close_delay: float) -> void:
	is_open = true
	_opened_at = now
	_close_delay = close_delay
	title_label.text = "Fragment %d" % fragment_id
	body_label.text = "Un fragment rejoint la chronique."
	continue_button.disabled = true
	visible = true


## The button is dead until the close delay has passed.
func tick(now: float) -> void:
	if is_open:
		continue_button.disabled = now < _opened_at + _close_delay


func close() -> void:
	if not is_open or continue_button.disabled:
		return
	is_open = false
	visible = false
	closed.emit()
