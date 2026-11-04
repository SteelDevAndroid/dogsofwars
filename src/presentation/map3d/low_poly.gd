# The low-poly meshes of the 3D map (art bible 1 "Production hybride", 5 and 6), built in code:
# flat faces, colours per vertex, no texture. A tile is 1 x 1 world unit, its top at y = 0.
# Colours are given in sRGB and stored linear (the shaders take them as albedo).
class_name LowPoly
extends RefCounted

## Tops of the terrains: the order of values of the delivered textures (TilePalette), lifted a
## step because the light and the shade now darken them; sides darker.
const PLAIN := Color("7A848E")
const FOREST := Color("68737E")
const FOREST_PRISM := Color("5A6772")
const MOUNTAIN := Color("98A2AC")
const WATER := Color("34495C")
const SIDE_SHADE := 0.72
const SLAB_DEPTH := 0.22
const WATER_TOP := -0.10
## Décor at most 30 % of a tile (art bible 6); a crest stays low enough for what stands behind it.
const DECOR_MAX := 0.30
const PEAK_MAX := 0.42
const BODY := Color("B4BBC3")
const DARK := Color("1E2329")
const ASLEEP := Color("4E5862")
const RUIN := Color("C8955A")


static func terrain(kind: int, variant: int) -> ArrayMesh:
	var st := _begin()
	match kind:
		TerrainGrid.FOREST:
			_slab(st, 0.0, FOREST)
			var spots := [[Vector2(-0.22, -0.2), 0.26], [Vector2(0.2, -0.18), 0.22], [Vector2(-0.16, 0.2), 0.2],
					[Vector2(0.22, 0.22), 0.28], [Vector2(0.0, 0.02), 0.18]]
			for i in 3 + variant:  # 3 to 5 prisms (art bible 6)
				var spot: Array = spots[(i + variant) % spots.size()]
				var p: Vector2 = spot[0]
				_frustum(st, Vector3(p.x, 0.0, p.y), 0.15, 0.0, 3 + (i % 2) * 3, 0.0, spot[1] * DECOR_MAX / 0.28,
						FOREST_PRISM.lightened(0.1), FOREST_PRISM.darkened(0.12), float(i) * 0.5)
		TerrainGrid.MOUNTAIN:
			_slab(st, 0.0, MOUNTAIN.darkened(0.2))
			var peaks := [[Vector2(-0.08, 0.04), 0.42, PEAK_MAX], [Vector2(0.22, -0.18), 0.26, PEAK_MAX * 0.7],
					[Vector2(0.2, 0.24), 0.22, PEAK_MAX * 0.5]]
			for i in peaks.size():
				var peak: Array = peaks[(i + variant) % peaks.size()] if i > 0 else peaks[0]
				var at: Vector2 = peak[0]
				_frustum(st, Vector3(at.x, 0.0, at.y), peak[1], 0.0, 4 + variant % 2, 0.0, peak[2],
						MOUNTAIN.lightened(0.1), MOUNTAIN.darkened(0.15), 0.4 + variant)
		TerrainGrid.WATER:
			_slab(st, WATER_TOP, WATER)
			_box(st, Vector3(0.0, WATER_TOP + 0.004, 0.08 * (variant - 1)), Vector3(0.6, 0.008, 0.035), WATER.lightened(0.18))  # one ripple, still
		_:
			var lift := plain_lift(variant)
			_slab(st, lift, PLAIN)
			if variant == 1:  # a furrow cut straight by the drones (art bible 6)
				_box(st, Vector3(0.0, lift + 0.004, 0.1), Vector3(0.7, 0.008, 0.05), PLAIN.darkened(0.25))
	return _end(st)


## The plains are gently terraced, a step per variant: their sides catch the light and the map
## reads as a relief, not a board.
static func plain_lift(variant: int) -> float:
	return [0.0, 0.05, 0.025][variant % 3]


## The fog: a dark flat slab, the same for every terrain (it tells nothing of what is under).
static func fog() -> ArrayMesh:
	var st := _begin()
	_slab(st, 0.0, DARK, 0.96)  # a gap between the slabs: the unknown still reads as tiles
	return _end(st)


## A node: low concentric hexagonal platforms, one step per level (art bible 6), in `color`.
static func node(level: int, color: Color) -> ArrayMesh:
	var st := _begin()
	for step in clampi(level, 1, 3):
		var radius := 0.42 - step * 0.11
		_frustum(st, Vector3.ZERO, radius, radius, 6, step * 0.05, (step + 1) * 0.05, color.lightened(0.1 * step), color.darkened(0.3), 0.0)
	_frustum(st, Vector3.ZERO, 0.06, 0.06, 6, 0.0, (clampi(level, 1, 3) + 1) * 0.05 + 0.03, color.lightened(0.4), color, 0.0)
	return _end(st)


## A ruin: a broken arch of the humans, curved and cut (art bible 6), taller than the mountains.
static func ruin(read: bool, variant: int) -> ArrayMesh:
	var st := _begin()
	var color := RUIN.darkened(0.45) if read else RUIN
	var side := color.darkened(0.12)
	_box(st, Vector3(-0.26, 0.24, 0.0), Vector3(0.1, 0.48, 0.14), color, side)
	_box(st, Vector3(0.26, 0.16 + 0.06 * variant, 0.0), Vector3(0.1, 0.32 + 0.12 * variant, 0.14), color, side)
	var segments := 7
	for i in segments:
		if i == 4 + variant % 2:  # the broken stone
			continue
		var a0 := PI * i / segments
		var a1 := PI * (i + 1) / segments
		var p0 := Vector3(-cos(a0) * 0.26, 0.48 + sin(a0) * 0.22, 0.0)
		var p1 := Vector3(-cos(a1) * 0.26, 0.48 + sin(a1) * 0.22, 0.0)
		_box(st, (p0 + p1) / 2.0, Vector3(p0.distance_to(p1) + 0.02, 0.08, 0.14), color, side, atan2(p1.y - p0.y, p1.x - p0.x))
	_box(st, Vector3(0.05, 0.02, 0.18), Vector3(0.16, 0.04, 0.1), side, side.darkened(0.2))  # a fallen piece
	return _end(st)


## A unit: base, body, the trait of its type, one eye in the side's colour (art bible 5). The
## pack has a hexagonal base and an empty command niche at the back; the Guardians a diamond
## base, a body 10 % taller and narrower, sharp traits. Asleep: grey-blue, sunk, eye off.
static func unit(key: String, side_color: Color, guardian: bool, asleep: bool) -> ArrayMesh:
	var st := _begin()
	_unit_parts(st, key, side_color, guardian, asleep)
	var mesh := _end(st)
	return mesh


static func _unit_parts(st: SurfaceTool, key: String, side_color: Color, guardian: bool, asleep: bool) -> void:
	var body := ASLEEP if asleep else BODY
	var shade := body.darkened(0.3)
	var eye := ASLEEP.darkened(0.3) if asleep else side_color
	var sink := -0.03 if asleep else 0.0
	if guardian:
		_frustum(st, Vector3(0, sink, 0), 0.3, 0.26, 4, 0.0, 0.06, side_color if not asleep else ASLEEP, shade, 0.0)
		_box(st, Vector3(0, sink + 0.2, 0), Vector3(0.24, 0.28, 0.22), body, shade)
	else:
		_frustum(st, Vector3(0, sink, 0), 0.3, 0.27, 6, 0.0, 0.06, side_color if not asleep else ASLEEP, shade, PI / 6.0)
		_box(st, Vector3(0, sink + 0.17, 0), Vector3(0.3, 0.22, 0.26), body, shade)
		_box(st, Vector3(0, sink + 0.17, -0.135), Vector3(0.1, 0.1, 0.02), DARK)  # the empty command niche
	var top := sink + (0.34 if guardian else 0.28)
	var fold := 0.5 if asleep else 1.0
	_box(st, Vector3(0, top - 0.07, 0.135 if not guardian else 0.115), Vector3(0.07, 0.05, 0.02), eye)  # the eye, forward
	match key:
		"eclaireur":  # mast
			_box(st, Vector3(0.06, top + 0.14 * fold, 0), Vector3(0.03, 0.28 * fold, 0.03), body, shade)
			_box(st, Vector3(0.06, top + 0.28 * fold, 0), Vector3(0.06, 0.04, 0.06), eye)
		"assaut":  # blade, pointing forward
			_box(st, Vector3(0, top + 0.03, 0.12 * fold), Vector3(0.05, 0.04, 0.36 * fold), body, shade)
		"rempart":  # flat shell overhanging the body
			_box(st, Vector3(0, top + 0.02, 0), Vector3(0.44, 0.04, 0.36), body.lightened(0.1), shade)
		"ouvrier":  # fork: two parallel prongs
			for x in [-0.07, 0.07]:
				_box(st, Vector3(x, top + 0.02, 0.1 * fold), Vector3(0.035, 0.035, 0.3 * fold), body, shade)
		"sentinelle":  # a tall spike
			_frustum(st, Vector3(0, top, 0), 0.08, 0.0, 4, 0.0, 0.3 * fold, body, shade, PI / 4.0)
		"chasseur":  # two horns swept forward
			for x in [-0.08, 0.08]:
				_frustum(st, Vector3(x, top, 0.04), 0.05, 0.0, 3, 0.0, 0.2 * fold, body, shade, 0.0)
		"bastion":  # a crenellated wedge
			for x in [-0.08, 0.0, 0.08]:
				_box(st, Vector3(x, top + 0.05, 0), Vector3(0.05, 0.1 + absf(x) * 0.6, 0.18), body, shade)



## The mark of a unit that has not played: a small light disc.
static func idle_mark() -> ArrayMesh:
	var st := _begin()
	_frustum(st, Vector3.ZERO, 0.07, 0.07, 8, 0.0, 0.03, Color.WHITE, Color.WHITE, 0.0)
	return _end(st)


## The arrow of the first turns: a point down.
static func arrow() -> ArrayMesh:
	var st := _begin()
	_frustum(st, Vector3.ZERO, 0.0, 0.16, 4, -0.22, 0.0, Color.WHITE, Color.WHITE, PI / 4.0)
	return _end(st)


## A flat square of `size` x `size`, `y` above the tile top: the move range and the selection.
static func quad(size: float, y: float) -> ArrayMesh:
	var st := _begin()
	var h := size / 2.0
	_tri(st, Vector3(-h, y, -h), Vector3(h, y, -h), Vector3(h, y, h), Color.WHITE)
	_tri(st, Vector3(-h, y, -h), Vector3(h, y, h), Vector3(-h, y, h), Color.WHITE)
	return _end(st)


## A square frame of four thin bars.
static func frame(size: float, width: float, y: float) -> ArrayMesh:
	var st := _begin()
	var h := size / 2.0 - width / 2.0
	for bar in [[Vector3(0, y, -h), Vector3(size, 0.01, width)], [Vector3(0, y, h), Vector3(size, 0.01, width)],
			[Vector3(-h, y, 0), Vector3(width, 0.01, size)], [Vector3(h, y, 0), Vector3(width, 0.01, size)]]:
		_box(st, bar[0], bar[1], Color.WHITE)
	return _end(st)


## The mark of a side on an owned tile, besides its colour: a chevron for the pack, a bar for the enemy.
static func owner_mark(player: bool, color: Color) -> ArrayMesh:
	var st := _begin()
	if player:
		_box(st, Vector3(-0.07, 0.006, 0.0), Vector3(0.2, 0.012, 0.04), color, color, PI / 4.0, true)
		_box(st, Vector3(0.07, 0.006, 0.0), Vector3(0.2, 0.012, 0.04), color, color, -PI / 4.0, true)
	else:
		_box(st, Vector3(0, 0.006, 0), Vector3(0.28, 0.012, 0.05), color)
	return _end(st)


## The threat marker of an announced intention: an orange-red "!" standing on the target tile.
static func threat(color: Color) -> ArrayMesh:
	var st := _begin()
	_box(st, Vector3(0, 0.52, 0), Vector3(0.08, 0.22, 0.08), color)
	_box(st, Vector3(0, 0.36, 0), Vector3(0.08, 0.06, 0.08), color)
	return _end(st)


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)  # flat faces
	return st


static func _end(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()


## The tile body: a square slab from `top` down to the slab depth, its sides shaded.
static func _slab(st: SurfaceTool, top: float, color: Color, size: float = 0.98) -> void:
	_box(st, Vector3(0, top - SLAB_DEPTH / 2.0, 0), Vector3(size, SLAB_DEPTH, size), color, color.darkened(1.0 - SIDE_SHADE))


## A box centred on `center`, turned by `angle` around Z (in its upright plane), or around Y with `flat_yaw`.
static func _box(st: SurfaceTool, center: Vector3, size: Vector3, top: Color, side: Color = Color(-1, 0, 0), angle: float = 0.0, flat_yaw: bool = false) -> void:
	var side_color := top.darkened(1.0 - SIDE_SHADE) if side.r < 0.0 else side
	var h := size / 2.0
	var corners: Array[Vector3] = []
	for c in [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
			Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]:
		var p: Vector3 = c
		if angle != 0.0:
			p = p.rotated(Vector3.UP, angle) if flat_yaw else p.rotated(Vector3.BACK, angle)
		corners.append(center + p)
	_quad(st, corners[4], corners[5], corners[6], corners[7], top)  # top
	_quad(st, corners[3], corners[2], corners[1], corners[0], side_color.darkened(0.3))  # bottom
	_quad(st, corners[7], corners[6], corners[2], corners[3], side_color)  # front (+z)
	_quad(st, corners[5], corners[4], corners[0], corners[1], side_color)  # back (-z)
	_quad(st, corners[6], corners[5], corners[1], corners[2], side_color)  # right (+x)
	_quad(st, corners[4], corners[7], corners[3], corners[0], side_color)  # left (-x)


## A prism, frustum or pyramid with `sides` faces around `base`, from `y0` to `y1` above it.
static func _frustum(st: SurfaceTool, base: Vector3, r0: float, r1: float, sides: int, y0: float, y1: float, top: Color, side: Color, turn: float) -> void:
	var low: Array[Vector3] = []
	var high: Array[Vector3] = []
	for i in sides:
		var a := turn + TAU * i / sides
		low.append(base + Vector3(cos(a) * r0, y0, sin(a) * r0))
		high.append(base + Vector3(cos(a) * r1, y1, sin(a) * r1))
	var apex := base + Vector3(0, y1, 0)
	for i in sides:
		var j := (i + 1) % sides
		if r1 <= 0.0:
			_tri(st, low[i], low[j], apex, side if i % 2 == 0 else side.lightened(0.12))
		else:
			_quad(st, high[i], high[j], low[j], low[i], side if i % 2 == 0 else side.lightened(0.12))
			_tri(st, apex, high[i], high[j], top)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_tri(st, a, b, c, color)
	_tri(st, a, c, d, color)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var linear := color.srgb_to_linear()
	for p in [a, b, c]:
		st.set_color(linear)
		st.add_vertex(p)
