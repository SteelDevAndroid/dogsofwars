# The unit of the interface (ADR-0010 §4): the project does not stretch, so one viewport unit
# is made to be one dp by setting `Window.content_scale_factor` from the screen's DPI.
class_name UiScale
extends RefCounted

const REFERENCE_DPI := 160.0
const MIN_FACTOR := 1.0
const MAX_FACTOR := 4.0


## dpi / 160, bounded; 1 when the DPI is unknown (headless gives 0 or a desktop value).
static func factor(dpi: int, text_scale: float = 1.0) -> float:
	if dpi <= 0:
		return MIN_FACTOR
	return clampf(dpi / REFERENCE_DPI * text_scale, MIN_FACTOR, MAX_FACTOR)


## Sets the scale of a window from the screen it is on.
static func apply(window: Window, dpi: int, text_scale: float = 1.0) -> void:
	window.content_scale_factor = factor(dpi, text_scale)
