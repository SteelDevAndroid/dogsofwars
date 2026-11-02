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
var can_end_turn := false
var enemy_turn := false
var threat_chip := ""
var loss_chips: Array[String] = []
var ruin_chip := ""
## Empty when no unit of the player is selected; else {title, lines}.
var unit_panel := {}
var journal: Array[String] = []


## `locked`: a player lock is up (attack animation, fragment panel). `selected`: unit id or -1.
static func build(state: GameState, catalog: DataCatalog, locked: bool, selected: int, journal_lines: Array[String]) -> HudModel:
	var model := HudModel.new()
	var phase := state.header.value(HeaderSlice.PHASE)
	var view := FactionView.new(state, Faction.PLAYER)
	model.turn_text = "Tour %d / %d" % [state.turn(), state.header.value(HeaderSlice.T_MAX)]
	model.energy_text = "Énergie %d" % view.energy(Faction.PLAYER)
	model.fragments_text = "Ruines lues %d" % state.ruin_journal.read_by(Faction.PLAYER)
	var weights := catalog.score
	model.score_text = "Victoire : %d contre %d" % [ScoreRules.decisive(state, Faction.PLAYER, weights), ScoreRules.decisive(state, Faction.AI, weights)]
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
	return {"title": String(catalog.units.key(type)).capitalize(), "lines": lines}


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


## The part of the screen left to the map (portrait): the top bar and the alert row above,
## the context panel below (design/ux/hud.md section 3.1).
static func map_area(screen: Vector2) -> Rect2:
	var top := screen.y * 0.14
	var bottom := screen.y * 0.24
	return Rect2(0.0, top, screen.x, screen.y - top - bottom)
