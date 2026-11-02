# The part of the screen the HUD may use (ADR-0010 §4, GDD 4 rule 14): the display's safe area
# (notches, system bars), in screen pixels, brought into viewport units. An empty or zero-sized
# rectangle (what a headless run gives) means the whole screen.
class_name SafeArea
extends RefCounted


## `safe_px`: DisplayServer.get_display_safe_area(); `window_position`: the window on the
## screen; `factor`: the window's content scale. The result is clipped to the viewport.
static func in_viewport(viewport: Vector2, safe_px: Rect2i, window_position: Vector2i, factor: float) -> Rect2:
	var whole := Rect2(Vector2.ZERO, viewport)
	if safe_px.size.x <= 0 or safe_px.size.y <= 0:
		return whole
	var local := Rect2(Vector2(safe_px.position - window_position) / factor, Vector2(safe_px.size) / factor)
	var clipped := local.intersection(whole)
	return whole if clipped.size.x <= 0.0 or clipped.size.y <= 0.0 else clipped


## The safe area of the running display for a window.
static func of_window(window: Window) -> Rect2:
	return in_viewport(Vector2(window.size) / window.content_scale_factor, DisplayServer.get_display_safe_area(),
			window.position, window.content_scale_factor)
