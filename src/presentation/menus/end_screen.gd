# End-of-match screen (GDD 3 rule 9, provisional wording): the outcome, the two decisive
# scores, and the way back to the menu. The save is deleted when the player leaves it
# (ADR-0006 §10), so a stop on this screen reopens it.
class_name EndScreen
extends Control

signal back_requested

var title_label: Label
var scores_label: Label
var gauge: ProgressBar
var fragments_label: Label
var quote_label: Label
var back_button: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuLayout.illustrated_backdrop(self, 0.78)
	var box := MenuLayout.column(self, MenuLayout.WIDTH, 0.12)
	title_label = MenuLayout.label(box)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scores_label = MenuLayout.label(box)
	scores_label.add_theme_font_size_override("font_size", 22)
	scores_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gauge = ProgressBar.new()  # the pack's share of the two decisive scores; the numbers say it too
	gauge.show_percentage = false
	gauge.custom_minimum_size = Vector2(0, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("1FA38F")
	var back := StyleBoxFlat.new()
	back.bg_color = Color("C49BEA")
	gauge.add_theme_stylebox_override("fill", fill)
	gauge.add_theme_stylebox_override("background", back)
	box.add_child(gauge)
	fragments_label = MenuLayout.label(box)
	fragments_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote_label = MenuLayout.label(box)
	quote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote_label.modulate = Color("EADFC8")
	back_button = MenuLayout.button(box, "Retour au menu", func() -> void: back_requested.emit())
	MenuLayout.make_primary(back_button)


## `fragments_read`: fragments read in this match; `quote`: the text of the last one (with its source), "" for none.
func show_result(status: int, player_score: int, ai_score: int, fragments_read: int = 0, quote: String = "") -> void:
	title_label.text = title_for(status)
	scores_label.text = "Meute %d  ·  Gardiens %d" % [player_score, ai_score]
	var total := player_score + ai_score
	gauge.value = 50.0 if total <= 0 else 100.0 * player_score / total
	fragments_label.text = "Fragments lus : %d" % fragments_read
	quote_label.text = quote
	quote_label.visible = quote != ""


static func title_for(status: int) -> String:
	match status:
		HeaderSlice.END_DOMINATION:
			return "Domination : la meute a pris tous les nœuds"
		HeaderSlice.END_ELIMINATED:
			return "Défaite : la meute n'a plus de nœud"
		HeaderSlice.END_TURNS_WON:
			return "Victoire au tour %d" % GameState.MAX_TURN
		HeaderSlice.END_TURNS_LOST:
			return "Défaite au tour %d" % GameState.MAX_TURN
		HeaderSlice.END_TURNS_DRAW:
			return "Égalité au tour %d" % GameState.MAX_TURN
		HeaderSlice.END_ABANDONED:
			return "Partie abandonnée"
	return "Partie terminée"
