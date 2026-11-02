# Pause menu of a match (provisional): resume, abandon (a scoreless defeat that keeps the
# fragments already read, GDD 3 rule 14) or leave to the menu with the match saved.
class_name PauseMenu
extends Control

signal resume_requested
signal abandon_requested
signal menu_requested
signal settings_requested

var resume_button: Button
var abandon_button: Button
var menu_button: Button
var settings_button: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	add_child(box)
	resume_button = _button(box, "Reprendre", func() -> void: resume_requested.emit())
	settings_button = _button(box, "Réglages", func() -> void: settings_requested.emit())
	menu_button = _button(box, "Menu (la partie est gardée)", func() -> void: menu_requested.emit())
	abandon_button = _button(box, "Abandonner", func() -> void: abandon_requested.emit())


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button
