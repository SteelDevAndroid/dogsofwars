# A preview of the colours of the sides (settings screen): the pack as a hexagon, the Guardians as
# a diamond, the unclaimed ground as a square, in the colours of the chosen palette. The shape
# says which is which whatever the colour (hud.md 10.1).
class_name PaletteSwatch
extends Control

var colorblind := false:
	set(value):
		colorblind = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(0, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var step := minf(size.x / 3.0, 90.0)
	var r := minf(size.y, 44.0) * 0.4
	var y := size.y / 2.0
	var x := step * 0.5
	var hexagon := PackedVector2Array()
	for k in 6:
		hexagon.append(Vector2(x, y) + Vector2(r, 0).rotated(deg_to_rad(60.0 * k - 30.0)))
	draw_colored_polygon(hexagon, TilePalette.owner(Faction.PLAYER, colorblind))
	x += step
	draw_colored_polygon(PackedVector2Array([Vector2(x, y - r), Vector2(x + r, y), Vector2(x, y + r), Vector2(x - r, y)]), TilePalette.owner(Faction.AI, colorblind))
	x += step
	draw_rect(Rect2(x - r * 0.8, y - r * 0.8, r * 1.6, r * 1.6), TilePalette.owner(Faction.NONE, colorblind))
