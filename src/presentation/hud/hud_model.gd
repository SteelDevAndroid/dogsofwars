# What the HUD shows, computed from the state and the events, with no node (design/ux/hud.md
# section 4). The Hud control only copies these values to its labels, so every rule of the
# HUD (what is hidden, what is counted, which button is enabled) is testable headless.
# Texts are provisional French (the localisation comes with the menus).
class_name HudModel
extends RefCounted

const JOURNAL_LINES := 12

var turn_text := ""
var energy_text := ""
var fragments_text := ""
var score_text := ""
## The two decisive scores, for the gauge under the top bar.
var score_player := 0
var score_ai := 0
var can_end_turn := false
var enemy_turn := false
var threat_chip := ""
var loss_chips: Array[String] = []
var ruin_chip := ""
## Empty when no unit of the player is selected; else {title, lines}.
var unit_panel := {}
## The attack buttons of the context panel (hud.md section 4): "Attaquer" with a unit that can
## strike, then the targeting and its preview, with "Confirmer" and "Annuler".
var can_attack := false
var targeting := false
var confirming := false
var preview_text := ""
## Capture, wake and upgrade for the selection, and the first reason one of them is greyed.
var extra_actions: Array[ContextAction] = []
var reason_text := ""
## The research panel: open or not, and its rows.
var research_open := false
var research_rows: Array[ContextAction] = []
var journal: Array[String] = []


## `locked`: a player lock is up (attack animation, fragment panel). `selected`: unit id or -1.
## `actions`: {"can_attack": bool, "targeting": bool, "preview": CombatPreview or null, "preview_text": String,
## "extras": Array[ContextAction], "panel": Dictionary (a selected node), "research_open": bool,
## "research": Array[ContextAction]}.
static func build(state: GameState, catalog: DataCatalog, locked: bool, selected: int, journal_lines: Array[String],
		actions: Dictionary = {}) -> HudModel:
	var model := HudModel.new()
	var phase := state.header.value(HeaderSlice.PHASE)
	var view := FactionView.new(state, Faction.PLAYER)
	model.turn_text = "Tour %d / %d" % [state.turn(), state.header.value(HeaderSlice.T_MAX)]
	model.energy_text = "%d" % view.energy(Faction.PLAYER)  # the icon says what it is
	model.fragments_text = "%d / %d" % [state.ruin_journal.read_by(Faction.PLAYER), view.ruin_ids().size()]
	var weights := catalog.score
	model.score_player = ScoreRules.decisive(state, Faction.PLAYER, weights)
	model.score_ai = ScoreRules.decisive(state, Faction.AI, weights)
	model.score_text = "%d contre %d" % [model.score_player, model.score_ai]
	model.enemy_turn = phase == HeaderSlice.PHASE_ENEMY_EXECUTION or phase == HeaderSlice.PHASE_END_OF_TURN
	model.can_end_turn = phase == HeaderSlice.PHASE_PLAYER and not locked
	var threats := IntentionMarkers.visible_to_player(state)
	if not threats.is_empty():
		model.threat_chip = "Menace : %d" % threats.size() if threats.size() > 1 else "Menace"
	var lost_units := 0
	for row in state.recalls.unit_count():
		if state.recalls.unit_side_of(row) == Faction.PLAYER:
			lost_units += 1
	if lost_units > 0:
		model.loss_chips.append("Drone perdu" if lost_units == 1 else "Drones perdus")
	if state.recalls.lost_tiles().size() > 0:
		model.loss_chips.append("Territoire perdu")
	for ruin_id in view.ruin_ids():
		if not state.ruins.is_read(state.ruins.find_row(ruin_id)):
			model.ruin_chip = "Ruine repérée"  # no number: the count of ruins is not told
			break
	model.unit_panel = _unit_panel(view, catalog, selected)
	model.journal = journal_lines.duplicate()
	var preview: CombatPreview = actions.get("preview")
	model.targeting = actions.get("targeting", false) and not locked
	model.preview_text = actions.get("preview_text", "") if actions.get("preview_text", "") != "" else (preview.text() if preview != null else "")
	model.confirming = (preview != null or model.preview_text != "") and not locked
	model.can_attack = actions.get("can_attack", false) and not locked and not model.targeting and not model.confirming
	if model.unit_panel.is_empty():
		model.unit_panel = actions.get("panel", {})
	if not locked and not model.targeting and not model.confirming:
		var extras: Array = actions.get("extras", [])
		for extra: ContextAction in extras:
			model.extra_actions.append(extra)
			if not extra.enabled and model.reason_text == "":
				model.reason_text = extra.reason
	model.research_open = actions.get("research_open", false)
	var rows: Array = actions.get("research", [])
	for row: ContextAction in rows:
		model.research_rows.append(row if not locked else ContextAction.new(row.id, row.label, false, "Patientez"))
	return model


static func _unit_panel(view: FactionView, catalog: DataCatalog, selected: int) -> Dictionary:
	if selected < 0 or view.unit_faction(selected) != Faction.PLAYER:
		return {}
	var type := view.unit_type(selected)
	var lines: Array[String] = [
		"PV %d / %d" % [view.unit_hp(selected), catalog.units.hp(type)],
		"MVT %d  ATQ %d  DÉF %d  Vue %d" % [
			ProtocolEffects.unit_stat(view, Faction.PLAYER, type, ProtocolEffects.MOVE, catalog),
			ProtocolEffects.unit_stat(view, Faction.PLAYER, type, ProtocolEffects.ATTACK, catalog),
			ProtocolEffects.unit_stat(view, Faction.PLAYER, type, ProtocolEffects.DEFENSE, catalog),
			ProtocolEffects.unit_stat(view, Faction.PLAYER, type, ProtocolEffects.VISION, catalog)],
	]
	if view.unit_moved(selected):
		lines.append("A bougé")
	if view.unit_acted(selected):
		lines.append("A agi")
	return {"title": DisplayNames.unit(catalog.units.key(type)), "lines": lines}


## One line of the enemy-turn journal for an event the player was allowed to see, or "".
static func journal_line(event: PresentationEvent) -> String:
	if event is IntentionAnnouncedEvent:
		return "L'ennemi annonce une menace"
	if event is IntentionExecutedEvent:
		return "L'ennemi exécute son intention"
	if event is IntentionCancelledEvent:
		return "Une intention ennemie est annulée"
	if event is AttackResolvedEvent:
		return "Un combat a lieu"
	if event is UnitDestroyedEvent:
		return "Un drone est détruit"
	if event is NodeCapturedEvent:
		return "Un nœud change de camp"
	if event is UnitMovedEvent and (event as UnitMovedEvent).faction == Faction.AI:
		return "Un Gardien se déplace"
	return ""
