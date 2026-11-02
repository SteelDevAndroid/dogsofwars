# The camera presenter (ADR-0002 §5, ADR-0010 §8): the camera is not a command and not a state.
# It recentres on a ruin being read (the first step of that sequence, instant in reduced
# motion), keeps the player's own moving unit in view, remembers where it was when the player
# ends their turn and gives that back when the next turn begins. It ignores what the enemy does.
class_name CameraHandler
extends PresentationHandler

var _camera: MapCamera
var _params: PresentationParams


func _init(camera: MapCamera, params: PresentationParams) -> void:
	_camera = camera
	_params = params


func handle(event: PresentationEvent, context: SequenceContext) -> PresentationHold:
	if event is PresentationRecenter:
		var duration := 0 if context.reduced or context.direct else _params.value("recenter_ms")
		_camera.start_recenter((event as PresentationRecenter).tile, context.t0, duration / 1000.0)
		return PresentationHold.new(duration)
	if event is TurnEndedEvent and (event as TurnEndedEvent).turn_faction == Faction.PLAYER:
		_camera.remember()
	elif event is TurnStartedEvent and (event as TurnStartedEvent).turn_faction == Faction.PLAYER:
		_camera.restore()
	elif event is UnitMovedEvent and (event as UnitMovedEvent).faction == Faction.PLAYER:
		_camera.ensure_visible((event as UnitMovedEvent).to_tile)
	return PresentationHold.new(0)
