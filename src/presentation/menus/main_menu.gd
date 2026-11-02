# Main menu (GDD 18, provisional: the menus have no GDD yet). Continue is offered only when
# a save exists; a new game over an existing save asks first, because it erases it
# (ADR-0006 §10). The screen only emits signals; the app decides.
class_name MainMenu
extends Control

signal continue_requested
signal new_game_requested
signal settings_requested
signal chronicle_requested
signal quit_requested

var continue_button: Button
var new_game_button: Button
var settings_button: Button
var chronicle_button: Button
var quit_button: Button
var confirm_button: Button
var cancel_button: Button
var best_label: Label
var notice_label: Label
var _save_available := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuLayout.illustrated_backdrop(self)
	var box := MenuLayout.column(self, MenuLayout.WIDTH, 0.42)  # the logo of the artwork sits above
	continue_button = _button(box, "Continuer", func() -> void: continue_requested.emit())
	new_game_button = _button(box, "Nouvelle partie", _on_new_game)
	confirm_button = _button(box, "Effacer la partie en cours et recommencer", func() -> void: new_game_requested.emit())
	cancel_button = _button(box, "Annuler", _reset_confirmation)
	chronicle_button = _button(box, "Chronique", func() -> void: chronicle_requested.emit())
	settings_button = _button(box, "Réglages", func() -> void: settings_requested.emit())
	quit_button = _button(box, "Quitter", func() -> void: quit_requested.emit())
	for primary in [continue_button, new_game_button, confirm_button]:
		MenuLayout.make_primary(primary)
	for secondary in [cancel_button, chronicle_button, settings_button]:
		MenuLayout.make_secondary(secondary)
	MenuLayout.make_secondary(quit_button)
	quit_button.flat = true  # the least used action stays discreet
	best_label = MenuLayout.label(box)
	notice_label = MenuLayout.label(box)
	_reset_confirmation()


## Whether a save exists; and the best score of the profile, -1 when there is none yet.
func configure(save_available: bool, best_score: int = -1, notice: String = "") -> void:
	notice_label.text = notice
	_save_available = save_available
	continue_button.disabled = not save_available
	best_label.text = "" if best_score < 0 else "Meilleur score : %d" % best_score
	_reset_confirmation()


func _on_new_game() -> void:
	if _save_available:
		new_game_button.visible = false
		continue_button.disabled = true
		confirm_button.visible = true
		cancel_button.visible = true
	else:
		new_game_requested.emit()


func _reset_confirmation() -> void:
	new_game_button.visible = true
	continue_button.disabled = not _save_available
	confirm_button.visible = false
	cancel_button.visible = false


func _button(parent: Control, text: String, action: Callable) -> Button:
	return MenuLayout.button(parent, text, action)
