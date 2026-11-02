# The tile presenter (ADR-0002 §5, adapter of the TileRenderer): turns the events of a batch
# into transient effects on the map and the length of their wait. The map itself shows the
# new state once the batch is over (`MatchScreen` redraws on `batch_finished`), so these are
# the transitions: a unit slides, a blow draws a line, the hit shows its number, a destroyed
# unit sags and fades, a recolouring spreads.
class_name TileRendererHandler
extends PresentationHandler

var _renderer: TileRenderer
var _params: PresentationParams


func _init(renderer: TileRenderer, params: PresentationParams) -> void:
	_renderer = renderer
	_params = params


func handle(event: PresentationEvent, context: SequenceContext) -> PresentationHold:
	if event is UnitMovedEvent:
		var moved := event as UnitMovedEvent
		var steps := CombatRules.distance(_renderer.layout.columns, moved.from_tile, moved.to_tile)
		var effect := _effect(TileEffect.Kind.MOVE, context, steps * _ms("move_step_ms", context))
		effect.unit_id = moved.unit_id
		effect.tile = moved.from_tile
		effect.tile2 = moved.to_tile
		_renderer.add_effect(effect)
		return PresentationHold.new(steps * _ms("move_step_ms", context))
	if event is AttackResolvedEvent:
		var attack := event as AttackResolvedEvent
		var line := _effect(TileEffect.Kind.LINE, context, _params.value("attack_line_ms"))  # fixed, even reduced
		line.tile = attack.attacker_tile
		line.tile2 = attack.target_tile
		_renderer.add_effect(line)
		return PresentationHold.new(_params.value("attack_line_ms"))
	if event is UnitHitEvent:
		var hit := event as UnitHitEvent
		_float(hit.tile, "−%d" % hit.damage, TilePalette.THREAT, context)
		return PresentationHold.new(_params.value("hit_ms"))
	if event is UnitHealedEvent:
		var healed := event as UnitHealedEvent
		_float(healed.tile, "+%d" % (healed.hp_after - healed.hp_before), TilePalette.PLAYER, context)
		return PresentationHold.new(0)
	if event is UnitDestroyedEvent:
		var destroyed := event as UnitDestroyedEvent
		var ghost := _effect(TileEffect.Kind.GHOST, context, _params.value("destroy_ms"))
		ghost.tile = destroyed.tile
		ghost.unit_id = destroyed.unit_id
		ghost.unit_type = _type_of(destroyed.unit_id)
		_renderer.add_effect(ghost)
		return PresentationHold.new(_params.value("destroy_ms"))
	if event is TileOwnersChangedEvent:
		var changed := event as TileOwnersChangedEvent
		var wave := _effect(TileEffect.Kind.WAVE, context, _ms("recolor_ms", context))
		wave.tiles = changed.changed_tiles
		wave.color = TilePalette.owner(changed.new_owner)
		_renderer.add_effect(wave)
		return PresentationHold.new(_ms("recolor_ms", context))
	return PresentationHold.new(0)


func rebuild_from_state(_state: GameState) -> void:
	_renderer.clear_effects()


## Reduced animations and direct display shorten the waves and slides, never the attack steps.
func _ms(key: String, context: SequenceContext) -> int:
	return 0 if context.reduced or context.direct else _params.value(key)


func _effect(kind: int, context: SequenceContext, duration_ms: int) -> TileEffect:
	return TileEffect.new(kind, context.t0, duration_ms / 1000.0)


func _float(tile: int, text: String, color: Color, context: SequenceContext) -> void:
	var effect := _effect(TileEffect.Kind.FLOAT_TEXT, context, _params.value("damage_number_ms"))  # fixed 800 ms
	effect.tile = tile
	effect.text = text
	effect.color = color
	_renderer.add_effect(effect)


## The type of a unit still in the snapshot being shown (the state already moved on).
func _type_of(unit_id: int) -> int:
	if _renderer.snapshot != null:
		for unit: Array in _renderer.snapshot.units:
			if unit[0] == unit_id:
				return unit[3]
	return 0
