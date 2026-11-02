# The preview of an attack as the HUD shows it (hud.md, "Aperçu de combat"): what the blow does,
# what the retaliation does, whether it is lethal. Read from the events the pipeline would
# publish (`pipeline.preview`), so it is the same computation as the real attack (AC-X1).
class_name CombatPreview
extends RefCounted

var permitted := false
var damage := 0
var retaliation := 0
var lethal := false
var attacker_destroyed := false
var target_hp_after := 0


static func of(preview: PreviewResult, attacker_id: int, target_id: int) -> CombatPreview:
	var result := CombatPreview.new()
	result.permitted = preview.validation.permitted
	for event in preview.events:
		if event is UnitHitEvent:
			var hit := event as UnitHitEvent
			if hit.unit_id == target_id:
				result.damage = hit.damage
				result.target_hp_after = hit.hp_left
			elif hit.unit_id == attacker_id:
				result.retaliation = hit.damage
		elif event is UnitDestroyedEvent:
			var destroyed := event as UnitDestroyedEvent
			result.lethal = result.lethal or destroyed.unit_id == target_id
			result.attacker_destroyed = result.attacker_destroyed or destroyed.unit_id == attacker_id
	return result


func text() -> String:
	var line := "Inflige −%d" % damage
	if lethal:
		line += " · létal"
	if retaliation > 0:
		line += " · Riposte −%d" % retaliation
		if attacker_destroyed:
			line += " · votre unité tombe"
	else:
		line += " · Pas de riposte"
	return line
