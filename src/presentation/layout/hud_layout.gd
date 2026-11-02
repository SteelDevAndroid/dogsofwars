# Where the HUD zones and the map go (design/ux/hud.md section 3), pure. Portrait: a bar on top
# and a context panel at the bottom, the map between them. Landscape: a rail on the left
# (140 pt), the context panel on the right (224 pt), the map in the middle. Everything stays
# inside the safe area; the heights of the portrait bars are the ones the widgets really need,
# so nothing is guessed as a share of the screen.
class_name HudLayout
extends RefCounted

const RAIL_WIDTH := 140.0
const PANEL_WIDTH := 224.0
## The map never gets less than this share of the screen height in portrait.
const MIN_MAP_SHARE := 0.30
const BUTTON := 48.0
const BUTTON_GAP := 8.0

var landscape := false
## The part of the screen in use.
var safe := Rect2()
## Top bar (portrait) or rail (landscape).
var top_zone := Rect2()
## Bottom context panel (portrait) or right panel (landscape).
var panel_zone := Rect2()
var map_area := Rect2()
## The +, − and recentre buttons, floating at the bottom right of the map.
var camera_buttons := Rect2()


## `top_height` and `bottom_height`: what the portrait bars need (their minimum sizes).
static func compute(screen: Vector2, safe_area: Rect2, top_height: float, bottom_height: float) -> HudLayout:
	var layout := HudLayout.new()
	layout.safe = safe_area
	layout.landscape = screen.x > screen.y
	if layout.landscape:
		layout.top_zone = Rect2(safe_area.position, Vector2(RAIL_WIDTH, safe_area.size.y))
		layout.panel_zone = Rect2(Vector2(safe_area.end.x - PANEL_WIDTH, safe_area.position.y), Vector2(PANEL_WIDTH, safe_area.size.y))
		layout.map_area = Rect2(layout.top_zone.end.x, safe_area.position.y, safe_area.size.x - RAIL_WIDTH - PANEL_WIDTH, safe_area.size.y)
	else:
		var floor_height := screen.y * MIN_MAP_SHARE
		var bars := minf(top_height + bottom_height, maxf(safe_area.size.y - floor_height, 0.0))
		var top := minf(top_height, bars * top_height / maxf(top_height + bottom_height, 1.0))
		layout.top_zone = Rect2(safe_area.position, Vector2(safe_area.size.x, top))
		layout.panel_zone = Rect2(Vector2(safe_area.position.x, safe_area.end.y - (bars - top)), Vector2(safe_area.size.x, bars - top))
		layout.map_area = Rect2(safe_area.position.x, layout.top_zone.end.y, safe_area.size.x, layout.panel_zone.position.y - layout.top_zone.end.y)
	var width := BUTTON
	var height := 3.0 * BUTTON + 2.0 * BUTTON_GAP
	layout.camera_buttons = Rect2(layout.map_area.end - Vector2(width, height) - Vector2(BUTTON_GAP, BUTTON_GAP), Vector2(width, height))
	return layout
