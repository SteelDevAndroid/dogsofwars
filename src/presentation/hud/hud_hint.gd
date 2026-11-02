# The short advice of the first turns (no tutorial: one line that says what to touch next). It
# shows during the player's turns 1 and 2 when the setting is on, and says something different
# before and after a unit is selected. Pure.
class_name HudHint
extends RefCounted

const LAST_TURN := 2


static func text(state: GameState, enabled: bool, player_phase: bool, selected_unit: int, targeting: bool) -> String:
	if not enabled or not player_phase or state.turn() > LAST_TURN or targeting:
		return ""
	if selected_unit < 0:
		return "Touchez une de vos unités, puis une case en surbrillance pour la déplacer."
	return "Touchez une case en surbrillance pour déplacer l'unité, ou « Fin du tour » pour passer la main."
