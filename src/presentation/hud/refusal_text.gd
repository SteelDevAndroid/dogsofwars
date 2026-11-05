# The reason a greyed button gives (hud.md, "bouton désactivé"): a refusal code of the pipeline
# in plain words, never a hidden fact (the pipeline's codes already hide what the fog hides).
class_name RefusalText
extends RefCounted

const TEXTS := {
	Refusal.ALREADY_ACTED: "A déjà agi",
	Refusal.NOT_ON_A_NODE: "Doit se trouver sur un nœud",
	Refusal.NODE_ALREADY_OWNED: "Ce nœud est déjà à vous",
	Refusal.TYPE_NOT_CAPABLE: "Ce drone ne peut pas",
	Refusal.NO_ADJACENT_DRONE: "Aucun drone endormi à côté",
	Refusal.NODE_ACQUIRED_THIS_TURN: "Nœud pris ce tour",
	Refusal.MAX_LEVEL: "Niveau maximal",
	Refusal.ALREADY_UPGRADED: "Déjà monté ce tour",
	Refusal.NODE_NOT_OWNED: "Ce nœud n'est pas à vous",
	Refusal.PROTOCOL_ACQUIRED: "Déjà acquis",
	Refusal.RESEARCH_IN_PROGRESS: "Une recherche est en cours",
	Refusal.PREREQUISITE_MISSING: "Prérequis manquant",
	Refusal.COMMANDS_LOCKED: "Patientez",
	Refusal.NOT_YOUR_TURN: "Pas votre tour",
	Refusal.MATCH_OVER: "Partie terminée",
	Refusal.NO_ABILITY: "Pas de capacité",
	Refusal.ALREADY_MOVED: "A déjà bougé",
	Refusal.MOVE_REVEALED: "Impossible d'annuler : le déplacement a révélé la carte ou lu une ruine",
}


static func of(result: ValidationResult) -> String:
	if result.code == Refusal.NOT_ENOUGH_ENERGY and result.params.size() >= 2:
		return "Énergie insuffisante (%d requis, %d disponibles)" % [result.params[0], result.params[1]]
	if result.code == Refusal.ABILITY_RECHARGING and not result.params.is_empty():
		return "Recharge : %d tour(s)" % result.params[0]
	return TEXTS.get(result.code, String(result.code))
