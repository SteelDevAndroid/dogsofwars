# End-of-match screen (GDD 3 rule 9, provisional wording): the outcome, the two decisive
# scores, and the way back to the menu. The save is deleted when the player leaves it
# (ADR-0006 §10), so a stop on this screen reopens it.
class_name EndScreen
extends Control

signal back_requested

var title_label: Label
var scores_label: Label
var back_button: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := MenuLayout.column(self)
	title_label = MenuLayout.label(box)
	scores_label = MenuLayout.label(box)
	back_button = MenuLayout.button(box, "Retour au menu", func() -> void: back_requested.emit())


func show_result(status: int, player_score: int, ai_score: int) -> void:
	title_label.text = title_for(status)
	scores_label.text = "Meute : %d\nGardiens : %d" % [player_score, ai_score]


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
