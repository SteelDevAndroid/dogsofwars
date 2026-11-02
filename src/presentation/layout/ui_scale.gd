# The unit of the interface (ADR-0010 §4): the project does not stretch, so one viewport unit
# is made to be one dp by setting `Window.content_scale_factor` from the screen's DPI.
class_name UiScale
extends RefCounted

const REFERENCE_DPI := 160.0
const MIN_FACTOR := 1.0
const MAX_FACTOR := 4.0


## dpi / 160 times the text scale (1.0 to 1.5), bounded; the DPI counts as 160 when it is
## unknown (headless gives 0 or a desktop value).
static func factor(dpi: int, text_scale: float = 1.0) -> float:
	var density := dpi / REFERENCE_DPI if dpi > 0 else 1.0
	return clampf(density * text_scale, MIN_FACTOR, MAX_FACTOR)


## Sets the scale of a window from the screen it is on.
static func apply(window: Window, dpi: int, text_scale: float = 1.0) -> void:
	window.content_scale_factor = factor(dpi, text_scale)
