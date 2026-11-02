# The audio presenter of the sequencer (ADR-0002 §5): an event the player may see is heard.
# A direct display (a load, a resynchronisation) is silent. No hold: a sound never makes the
# player wait.
class_name SoundHandler
extends PresentationHandler

var _bank: SoundBank


func _init(bank: SoundBank) -> void:
	_bank = bank


func handle(event: PresentationEvent, context: SequenceContext) -> PresentationHold:
	if not context.direct:
		var cue := cue_of(event)
		if cue != &"":
			_bank.play(cue)
	return PresentationHold.new(0)


## The cue of an event, empty for a silent one.
static func cue_of(event: PresentationEvent) -> StringName:
	if event is UnitMovedEvent:
		return &"move"
	if event is AttackResolvedEvent:
		return &"attack"
	if event is UnitDestroyedEvent:
		return &"destroyed"
	if event is IntentionAnnouncedEvent:
		return &"threat"
	if event is NodeCapturedEvent:
		return &"capture"
	if event is DroneWokenEvent:
		return &"wake"
	if event is RuinReadEvent and (event as RuinReadEvent).fragment_id > 0:
		return &"fragment"
	if event is TurnStartedEvent and (event as TurnStartedEvent).turn_faction == Faction.PLAYER and (event as TurnStartedEvent).turn > 1:
		return &"turn"
	return &""
