# Settings screen (GDD 22 rule 14, hud.md 10.5), opened over the main menu or the pause menu.
# It only shows the values it is given and emits `changed(key, value)`; the app stores and
# applies them. Text scale in steps (100, 125, 150 %), flags as check buttons, the enemy-turn
# speed as three choices.
class_name SettingsScreen
extends Control

signal changed(key: StringName, value: int)
signal back_requested

const SCALES := [100, 125, 150]
const SPEEDS := ["Normale", "Rapide", "Instantanée"]

var scale_option := OptionButton.new()
var speed_option := OptionButton.new()
var reduced_motion_check := CheckButton.new()
var show_range_check := CheckButton.new()
var colorblind_check := CheckButton.new()
var left_panel_check := CheckButton.new()
var hints_check := CheckButton.new()
var back_button := Button.new()

var _loading := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()  # opaque, and it stops the taps meant for the screen below
	backdrop.color = Color("1E2329")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Réglages"
	box.add_child(title)
	_row(box, "Taille du texte", scale_option)
	for percent in SCALES:
		scale_option.add_item("%d %%" % percent)
	scale_option.item_selected.connect(func(index: int) -> void: _emit(GameSettings.TEXT_SCALE, SCALES[index]))
	_row(box, "Vitesse du tour ennemi", speed_option)
	for speed in SPEEDS:
		speed_option.add_item(speed)
	speed_option.item_selected.connect(func(index: int) -> void: _emit(GameSettings.ENEMY_SPEED, index))
	_flag(box, reduced_motion_check, "Réduire les animations", GameSettings.REDUCED_MOTION)
	_flag(box, show_range_check, "Afficher la portée de déplacement", GameSettings.SHOW_RANGE)
	_flag(box, colorblind_check, "Palette daltonienne", GameSettings.COLORBLIND)
	_flag(box, left_panel_check, "Panneau à gauche (paysage)", GameSettings.LEFT_PANEL)
	_flag(box, hints_check, "Conseils des premiers tours", GameSettings.HINTS)
	back_button.text = "Retour"
	back_button.custom_minimum_size = Vector2(0, 50)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	box.add_child(back_button)


## Shows the given settings (a full table, GameSettings.TABLE keys) without emitting changes.
func configure(settings: Dictionary) -> void:
	_loading = true
	scale_option.select(maxi(SCALES.find(settings[GameSettings.TEXT_SCALE]), 0))
	speed_option.select(settings[GameSettings.ENEMY_SPEED])
	reduced_motion_check.button_pressed = settings[GameSettings.REDUCED_MOTION] == 1
	show_range_check.button_pressed = settings[GameSettings.SHOW_RANGE] == 1
	colorblind_check.button_pressed = settings[GameSettings.COLORBLIND] == 1
	left_panel_check.button_pressed = settings[GameSettings.LEFT_PANEL] == 1
	hints_check.button_pressed = settings[GameSettings.HINTS] == 1
	_loading = false


func _emit(key: StringName, value: int) -> void:
	if not _loading:
		changed.emit(key, value)


func _flag(parent: Control, check: CheckButton, text: String, key: StringName) -> void:
	check.text = text
	check.custom_minimum_size = Vector2(0, 50)
	check.toggled.connect(func(on: bool) -> void: _emit(key, 1 if on else 0))
	parent.add_child(check)


func _row(parent: Control, text: String, control: Control) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	control.custom_minimum_size = Vector2(0, 50)
	parent.add_child(control)
