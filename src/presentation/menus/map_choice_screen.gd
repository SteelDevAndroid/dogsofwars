# The choice of the map of a new game (GDD 2, decision D3 of 2026-11-04): one card per map with
# its relief in miniature, its name, its size and one sentence, and a button to play it; "Au
# hasard" keeps the draw by seed for those who do not care. The screen only emits signals; the
# app starts the match. It shows no node, no ruin and no start: only what the map file calls its
# presentation (MapDefinition.title and summary) and its relief.
class_name MapChoiceScreen
extends Control

signal map_chosen(index: int)
signal random_requested
signal back_requested

const THUMBNAIL := Vector2(96, 96)

var cards_box: VBoxContainer
var random_button: Button
var back_button: Button
## One per map, in the order of Bootstrap.MAP_FILES.
var play_buttons: Array[Button] = []
var thumbnails: Array[MapThumbnail] = []
var titles: Array[Label] = []


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
	var title := MenuLayout.label(column, "Choisir une carte")
	title.add_theme_font_size_override("font_size", 24)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	cards_box = VBoxContainer.new()
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_box.add_theme_constant_override("separation", 12)
	scroll.add_child(cards_box)
	random_button = MenuLayout.button(column, "Au hasard", func() -> void: random_requested.emit())
	MenuLayout.make_secondary(random_button)
	back_button = MenuLayout.button(column, "Retour", func() -> void: back_requested.emit(), "retour")
	MenuLayout.make_secondary(back_button)


## Fills the cards, one per map, in the order of the list the app plays from.
func configure(maps: Array[MapDefinition]) -> void:
	for child in cards_box.get_children():
		cards_box.remove_child(child)
		child.queue_free()
	play_buttons.clear()
	thumbnails.clear()
	titles.clear()
	for index in maps.size():
		cards_box.add_child(_card(maps[index], index))


func _card(map: MapDefinition, index: int) -> PanelContainer:
	var panel := MenuLayout.framed_panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var thumbnail := MapThumbnail.new()
	thumbnail.custom_minimum_size = THUMBNAIL
	thumbnail.size = THUMBNAIL
	thumbnail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	thumbnail.show_map(map, MapArt.colors_for(map.cells))
	row.add_child(thumbnail)
	thumbnails.append(thumbnail)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	row.add_child(text)
	var head := MenuLayout.label(text, map.title)
	head.add_theme_font_size_override("font_size", 18)
	titles.append(head)
	var size_label := MenuLayout.label(text, "%d × %d" % [map.width, map.height])
	size_label.modulate = Color(1, 1, 1, 0.7)
	MenuLayout.label(text, map.summary)
	var play := MenuLayout.button(text, "Jouer", func() -> void: map_chosen.emit(index))
	MenuLayout.make_primary(play)
	play_buttons.append(play)
	return panel
