# "Comment jouer": three cards, no tutorial to sit through. Reached from the main menu.
class_name HowToPlayScreen
extends Control

signal back_requested

const CARDS := [
	["Déplacer", "Touchez une de vos unités, puis une case en surbrillance. Chaque unité bouge une fois par tour."],
	["Attaquer et prendre", "Attaquez une unité ennemie à portée, capturez un nœud avec un ouvrier. Les Gardiens annoncent leurs menaces avant d'agir : vous les voyez venir."],
	["Ruines et fragments", "Arrêtez une unité sur une ruine : vous lisez un fragment de la chronique et reprenez la zone autour. Touchez « Fin du tour » quand vous avez fini."],
]

var cards_box: VBoxContainer
var back_button: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = MenuLayout.NAVY
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := MenuLayout.label(column, "Comment jouer")
	title.add_theme_font_size_override("font_size", 24)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	cards_box = VBoxContainer.new()
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_box.add_theme_constant_override("separation", 12)
	scroll.add_child(cards_box)
	for card: Array in CARDS:
		cards_box.add_child(_card(card[0], card[1]))
	back_button = MenuLayout.button(column, "Retour", func() -> void: back_requested.emit(), "retour")
	MenuLayout.make_primary(back_button)


static func _card(title: String, text: String) -> PanelContainer:
	var panel := MenuLayout.framed_panel()
	var box := VBoxContainer.new()
	panel.add_child(box)
	var head := MenuLayout.label(box, title)
	head.add_theme_font_size_override("font_size", 18)
	MenuLayout.label(box, text)
	return panel
