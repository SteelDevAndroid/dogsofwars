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
	var dim := ColorRect.new()  # the match below is dimmed and gets no tap
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := MenuLayout.column(self)
	resume_button = _button(box, "Reprendre", func() -> void: resume_requested.emit())
	settings_button = _button(box, "Réglages", func() -> void: settings_requested.emit())
	menu_button = _button(box, "Menu (la partie est gardée)", func() -> void: menu_requested.emit())
	abandon_button = _button(box, "Abandonner", func() -> void: abandon_requested.emit())


func _button(parent: Control, text: String, action: Callable) -> Button:
	return MenuLayout.button(parent, text, action)
