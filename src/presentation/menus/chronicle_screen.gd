# The chronicle (GDD 14, GDD 13 rule 18): the fragments of a faction in the order of their ids,
# the ones found with their title, source and text, the others as an empty slot. A bar of N
# segments (N = the size of the pool) shows how far along it is; filled and empty differ by
# glyph as well as by colour. A fragment id the pool no longer knows is ignored (GDD 22 rule 12).
class_name ChronicleScreen
extends Control

signal back_requested

var bar_label: Label
var entries_box: VBoxContainer
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
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	MenuLayout.label(column, "Chronique de la meute")
	bar_label = MenuLayout.label(column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	entries_box = VBoxContainer.new()
	entries_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_box.add_theme_constant_override("separation", 12)
	scroll.add_child(entries_box)
	back_button = MenuLayout.button(column, "Retour", func() -> void: back_requested.emit())


## `found`: the profile's chronicle rows [faction, fragment id].
func show_chronicle(pool: FragmentPool, found: Array, faction: int = Faction.PLAYER) -> void:
	for child in entries_box.get_children():
		entries_box.remove_child(child)
		child.queue_free()
	var ids := pool.ids_of(faction)
	var known := 0
	var bar := ""
	for id in ids:
		var has := found.has([faction, id])
		known += 1 if has else 0
		bar += "●" if has else "○"
		if has:
			MenuLayout.label(entries_box, "%s\n%s\n« %s »" % [pool.title_of(id), pool.source_of(id), pool.text_of(id)])
		else:
			MenuLayout.label(entries_box, "○  Fragment non trouvé")
	bar_label.text = "%s   %d / %d" % [bar, known, ids.size()]
