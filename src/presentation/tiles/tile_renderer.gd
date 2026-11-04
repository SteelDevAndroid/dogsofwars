# Draws the map (GDD 2, GDD 5, art bible) from a TileSnapshot: terrain, fog, ownership with
# a pattern, nodes with their level, ruins, units with a shape per type and an outline per
# side, HP bars, the selection and its move range, and the threat markers of announced
# intentions. Process priority 10 (ADR-0002): after the sequencer's time sources.
class_name TileRenderer
extends Node2D

var snapshot: TileSnapshot
var layout := TileLayout.new()
var selected_tile := -1
var highlighted: PackedInt32Array = PackedInt32Array()
## The presentation clock the effects are timed on; null in a still image.
var clock: ClockSource
var effects: Array[TileEffect] = []
## Tiles of the units the selected one may strike, and the one chosen.
## The map shows inside this rectangle only (the engine clip is not relied on: tiles are cut here).
var clip_area := Rect2(-1e6, -1e6, 2e6, 2e6)
var targets := PackedInt32Array()
var chosen_target := -1
var _terrain := {}
var _units := {}
var _nodes: Array[Texture2D] = []
var _ruins: Array[Texture2D] = []
var _glow: Texture2D
var _fx := {}
var _type_keys := PackedStringArray()
var _tinted := {}
var _fog_texture: Texture2D
var _edge_texture: Texture2D
var _corner_out_texture: Texture2D
var _corner_in_texture: Texture2D
## The colour-blind palette of hud.md 10.5 (ownership colours only).
var colorblind := false
## The tile of the unit to touch first (the advice of the first turns): a small arrow bobs above it.
var hint_tile := -1
## No movement of the arrow (reduced motion).
var still := false
## False when the map is shown in 3D (MapView3D, ADR-0014): this node keeps the snapshot, the
## effects, the waves and the selection, and draws nothing.
var draw_enabled := true

var _wave_by_tile := {}  # tile -> [WAVE effect, index of the tile in it]: the latest write wins
var _was_animating := false

const ART := "res://assets/art/terrain/"
const VARIANTS := 3
const UNIT_KEYS := ["eclaireur", "assaut", "rempart", "ouvrier", "sentinelle", "chasseur", "bastion"]
const RUIN_FILES := ["ruin_arche_brisee_01", "ruin_arche_brisee_02", "ruin_dome_brise_01"]
const NODE_LEVELS := 3
## The fill of a tile in the move range (over the terrain, under the units).
const REACH_FILL := 0.22
## How much of the side's colour a grey sprite takes (its shading stays).
const TINT_STRENGTH := 0.55
const TERRAIN_NAMES := {TerrainGrid.PLAIN: "plaine", TerrainGrid.FOREST: "foret", TerrainGrid.MOUNTAIN: "montagne", TerrainGrid.WATER: "eau"}
const CORNER_TL := 1
const CORNER_TR := 2
const CORNER_BR := 4
const CORNER_BL := 8
const SIDE_LEFT := 1
const SIDE_RIGHT := 2
const SIDE_UP := 4
const SIDE_DOWN := 8


func _init() -> void:
	process_priority = 10
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # 256 px sources drawn at 24 to 64 pt
	for code: int in TERRAIN_NAMES:
		var variants: Array[Texture2D] = []
		for k in VARIANTS:
			variants.append(load("%sterrain_%s_%02d.png" % [ART, TERRAIN_NAMES[code], k + 1]))
		_terrain[code] = variants
	_fog_texture = load(ART + "terrain_brouillard_01.png")
	for key in UNIT_KEYS:
		_units[key] = load("res://assets/art/units/unit_%s.png" % key)
	for level in NODE_LEVELS:
		_nodes.append(load("res://assets/art/nodes/node_niveau_%d.png" % (level + 1)))
	for file in RUIN_FILES:
		_ruins.append(load("res://assets/art/ruins/%s.png" % file))
	for fx in ["selection", "cible_crochets", "portee_point", "menace", "debris", "ruine_lueur"]:
		_fx[fx] = load("res://assets/art/fx/fx_%s.png" % fx)
	_edge_texture = load(ART + "fog_lisiere_bord.png")
	_corner_out_texture = load(ART + "fog_lisiere_angle_ext.png")
	_corner_in_texture = load(ART + "fog_lisiere_angle_int.png")


func show_state(state: GameState, catalog: DataCatalog) -> void:
	snapshot = TileSnapshot.take(state, catalog)
	_drop_waves()  # the new snapshot shows what the waves led to
	if _type_keys.size() != catalog.units.count():
		_type_keys = PackedStringArray()
		for type in catalog.units.count():
			_type_keys.append(catalog.units.key(type))
	queue_redraw()


func add_effect(effect: TileEffect) -> void:
	effects.append(effect)
	if effect.kind == TileEffect.Kind.WAVE:
		for index in effect.tiles.size():
			_wave_by_tile[effect.tiles[index]] = [effect, index]
	queue_redraw()


## The map shows inside this rectangle only: scrolled tiles never cover the HUD bars. The cut is
## made here, in the drawing, not by the engine's canvas clip (which left stray tiles outside).
func set_clip_rect(rect: Rect2) -> void:
	clip_area = rect
	queue_redraw()


func set_targets(tiles: PackedInt32Array, chosen: int) -> void:
	targets = tiles
	chosen_target = chosen
	queue_redraw()


func clear_effects() -> void:
	effects.clear()
	_wave_by_tile.clear()
	queue_redraw()


func _process(_delta: float) -> void:
	if hint_tile >= 0 and not still:
		queue_redraw()  # the arrow bobs
	if effects.is_empty() or clock == null:
		return
	var now := clock.current()
	var kept: Array[TileEffect] = []
	var animating := false
	for effect in effects:
		if not effect.is_over(now):
			animating = true
			kept.append(effect)
		elif effect.kind == TileEffect.Kind.WAVE:
			kept.append(effect)  # a finished wave holds its tint until the next snapshot replaces it
	var dropped := kept.size() != effects.size()
	effects = kept
	if animating or dropped or _was_animating:
		queue_redraw()  # the last frame of a fade draws its end
	_was_animating = animating


## (tint, saturation 0..1000) the tile shows at presentation time `now`: its colour wave's fade
## while a wave covers it, its owner in the snapshot otherwise (GDD 15 F5, rule 15).
func shown_state(tile: int, now: float) -> Vector2i:
	if _wave_by_tile.has(tile):
		var written: Array = _wave_by_tile[tile]
		return (written[0] as TileEffect).wave_state(written[1], now)
	if snapshot == null:
		return Vector2i(Faction.NONE, 0)
	var owner: int = snapshot.owners[tile]
	return Vector2i(owner, 0 if owner == Faction.NONE else 1000)


## The tiles a colour wave covers now (their tint is shown_state's, not the snapshot's).
func wave_tiles() -> Array:
	return _wave_by_tile.keys()


func _drop_waves() -> void:
	_wave_by_tile.clear()
	effects = effects.filter(func(effect: TileEffect) -> bool: return effect.kind != TileEffect.Kind.WAVE)


func set_selection(tile: int, reachable: PackedInt32Array) -> void:
	selected_tile = tile
	highlighted = reachable
	queue_redraw()


func fit(area: Rect2) -> void:
	if snapshot != null:
		layout = TileLayout.fitting(snapshot.columns, snapshot.rows, area)
		queue_redraw()


func _draw() -> void:
	if snapshot == null or not draw_enabled:
		return
	for tile in visible_tiles():
		_draw_tile(tile)
	for node: Array in snapshot.nodes:
		_draw_node(node)
	for ruin: Array in snapshot.ruins:
		_draw_ruin(ruin)
	for unit: Array in snapshot.units:
		if snapshot.fog_at(unit[1]) == VisionService.FOG_VISIBLE or unit[2] == Faction.PLAYER:
			_draw_unit(unit)
	for threat: Array in snapshot.threats:
		_draw_threat(threat)
	_draw_hint_arrow()
	for effect in effects:
		_draw_effect(effect)
	for tile in targets:
		_draw_clipped(_fx["cible_crochets"], layout.rect_of(tile), Color(TilePalette.THREAT, 1.0 if tile == chosen_target else 0.8))
	for tile in highlighted:
		_draw_reach(tile)
	if selected_tile >= 0:
		_draw_clipped(_fx["selection"], layout.rect_of(selected_tile), TilePalette.SELECTION)


## A tile of the move range: a light fill and a frame, so it reads on any terrain (the dot alone
## was lost on dark tiles), then the dot. The frame is drawn only when the whole tile shows: cut,
## it would draw a line along the edge of the map.
func _draw_reach(tile: int) -> void:
	var full := layout.rect_of(tile)
	var rect := full.intersection(clip_area)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	draw_rect(rect, Color(TilePalette.SELECTION, REACH_FILL))
	if clip_area.encloses(full):
		var inset := maxf(1.0, layout.tile_size / 32.0)
		draw_rect(full.grow(-inset), Color(TilePalette.SELECTION, 0.85), false, inset)
	_draw_clipped(_fx["portee_point"], full, Color(TilePalette.SELECTION, 0.9))


## The tiles that show, at least in part, inside the map area.
func visible_tiles() -> PackedInt32Array:
	var shown := PackedInt32Array()
	if snapshot == null:
		return shown
	for tile in snapshot.columns * snapshot.rows:
		if layout.rect_of(tile).intersects(clip_area):
			shown.append(tile)
	return shown


func _draw_tile(tile: int) -> void:
	var full := layout.rect_of(tile)
	var rect := full.intersection(clip_area)
	var level := snapshot.fog_at(tile)
	if level == VisionService.FOG_UNDISCOVERED:
		_draw_clipped(_fog_texture, full, Color.WHITE)
		return
	var textures: Array = _terrain[snapshot.terrain[tile]]
	var dim := TilePalette.MEMORY_DIM if level == VisionService.FOG_EXPLORED else 1.0
	_draw_clipped(textures[variant_of(tile)], full, Color(dim, dim, dim))
	_draw_fog_edges(tile)
	var shown := shown_state(tile, clock.current() if clock != null else INF)
	if shown.y > 0:
		var tint := TilePalette.owner(shown.x, colorblind)
		var strength := shown.y / 1000.0  # never two tints at once: one tint, more or less saturated
		draw_rect(rect, Color(tint, 0.30 * strength))
		# A pattern besides the colour (accessibility): a chevron for the pack, a bar for the enemy.
		var c := rect.get_center()
		var s := layout.tile_size * 0.12
		if shown.x == Faction.PLAYER:
			draw_polyline(PackedVector2Array([c + Vector2(-s, s), c + Vector2(0, -s), c + Vector2(s, s)]), Color(tint, strength), 1.0)
		else:
			draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), Color(tint, strength), 1.0)


## Which of the three variants of a terrain a tile shows: fixed for the tile whatever the zoom
## (the edges of the variants are identical, so any neighbour may differ).
static func variant_of(tile: int) -> int:
	return int(((tile * 2654435761) & 0xFFFFFFFF) >> 8) % VARIANTS


## The part of `texture` that falls inside the map area, drawn over the part of `full` that does.
func _draw_clipped(texture: Texture2D, full: Rect2, modulate_color: Color) -> void:
	var shown := full.intersection(clip_area)
	if shown.size.x <= 0.0 or shown.size.y <= 0.0:
		return
	var scale := texture.get_size() / full.size
	draw_texture_rect_region(texture, shown, Rect2((shown.position - full.position) * scale, shown.size * scale), modulate_color)


## `texture` (drawn for the left or the top-left of a tile) turned by quarter turns clockwise
## about the centre of `full`.
func _draw_turned(texture: Texture2D, full: Rect2, quarter_turns: int) -> void:
	draw_set_transform(full.get_center(), quarter_turns * PI / 2.0)
	draw_texture_rect(texture, Rect2(-full.size / 2.0, full.size), false)
	draw_set_transform(Vector2.ZERO)


## Where a discovered tile meets the fog its edge is softened with the delivered strips: a side
## touching the fog gets the edge strip, two sides in a corner the inner corner, a fog only on the
## diagonal the outer corner. A tile cut by the edge of the map area keeps its hard edge.
func _draw_fog_edges(tile: int) -> void:
	var full := layout.rect_of(tile)
	if not clip_area.encloses(full):
		return
	var sides := fog_sides(tile)
	var rest := sides
	# (the two sides of a corner, the quarter turns from top-left)
	for corner in [[SIDE_LEFT | SIDE_UP, 0], [SIDE_UP | SIDE_RIGHT, 1], [SIDE_RIGHT | SIDE_DOWN, 2], [SIDE_DOWN | SIDE_LEFT, 3]]:
		if rest & corner[0] == corner[0]:
			_draw_turned(_corner_in_texture, full, corner[1])
			rest &= ~corner[0]
	for side in [[SIDE_LEFT, 0], [SIDE_UP, 1], [SIDE_RIGHT, 2], [SIDE_DOWN, 3]]:
		if rest & side[0]:
			_draw_turned(_edge_texture, full, side[1])
	var corners := fog_corners(tile)
	for k in 4:
		if corners & (1 << k):
			_draw_turned(_corner_out_texture, full, k)


## The corners of a tile where only the diagonal neighbour is fog (CORNER_* bits).
func fog_corners(tile: int) -> int:
	if snapshot == null or snapshot.fog_at(tile) == VisionService.FOG_UNDISCOVERED:
		return 0
	var sides := fog_sides(tile)
	var x := tile % snapshot.columns
	var y := tile / snapshot.columns
	var corners := 0
	for entry in [[-1, -1, SIDE_LEFT | SIDE_UP, CORNER_TL], [1, -1, SIDE_UP | SIDE_RIGHT, CORNER_TR],
			[1, 1, SIDE_RIGHT | SIDE_DOWN, CORNER_BR], [-1, 1, SIDE_DOWN | SIDE_LEFT, CORNER_BL]]:
		var nx: int = x + entry[0]
		var ny: int = y + entry[1]
		if nx < 0 or ny < 0 or nx >= snapshot.columns or ny >= snapshot.rows or sides & entry[2] != 0:
			continue
		if snapshot.fog_at(ny * snapshot.columns + nx) == VisionService.FOG_UNDISCOVERED:
			corners |= entry[3]
	return corners


## The sides of a tile that touch undiscovered ground (SIDE_* bits); 0 for an undiscovered tile.
func fog_sides(tile: int) -> int:
	if snapshot == null or snapshot.fog_at(tile) == VisionService.FOG_UNDISCOVERED:
		return 0
	var x := tile % snapshot.columns
	var y := tile / snapshot.columns
	var sides := 0
	if x > 0 and snapshot.fog_at(tile - 1) == VisionService.FOG_UNDISCOVERED:
		sides |= SIDE_LEFT
	if x < snapshot.columns - 1 and snapshot.fog_at(tile + 1) == VisionService.FOG_UNDISCOVERED:
		sides |= SIDE_RIGHT
	if y > 0 and snapshot.fog_at(tile - snapshot.columns) == VisionService.FOG_UNDISCOVERED:
		sides |= SIDE_UP
	if y < snapshot.rows - 1 and snapshot.fog_at(tile + snapshot.columns) == VisionService.FOG_UNDISCOVERED:
		sides |= SIDE_DOWN
	return sides


func _draw_hint_arrow() -> void:
	if hint_tile < 0 or not _inside(hint_tile):
		return
	var t := layout.tile_size
	var bob := 0.0 if still or clock == null else sin(clock.current() * 5.0) * 0.07 * t
	var c := layout.center_of(hint_tile) + Vector2(0.0, -0.78 * t + bob)
	var arrow := PackedVector2Array([c + Vector2(-0.2 * t, -0.13 * t), c + Vector2(0.2 * t, -0.13 * t), c + Vector2(0.0, 0.14 * t)])
	draw_colored_polygon(arrow, TilePalette.SELECTION)
	draw_polyline(arrow + PackedVector2Array([arrow[0]]), TilePalette.OUTLINE, 1.5)


func _draw_node(node: Array) -> void:
	if snapshot.fog_at(node[0]) == VisionService.FOG_UNDISCOVERED:
		return
	var level: int = clampi(node[2], 1, NODE_LEVELS) - 1
	var texture := _nodes[level]
	if node[1] != Faction.NONE:  # grey while nobody holds it
		texture = _tint("node%d" % level, texture, TilePalette.owner(node[1], colorblind))
	_draw_clipped(texture, layout.rect_of(node[0]), Color.WHITE)


## A ruin stands on its tile and rises half a tile above it; unread ones glow, read ones go dark.
func _draw_ruin(ruin: Array) -> void:
	var tile := layout.rect_of(ruin[0])
	var rect := Rect2(tile.position.x, tile.end.y - 1.5 * tile.size.y, tile.size.x, 1.5 * tile.size.y)
	if not ruin[1]:
		_draw_clipped(_fx["ruine_lueur"], rect, Color(TilePalette.RUIN, 0.9))
	_draw_clipped(_ruins[variant_of(ruin[0])], rect, Color(0.5, 0.5, 0.5) if ruin[1] else Color.WHITE)


func _draw_unit(unit: Array) -> void:
	var rect := layout.rect_of(unit[1])
	var c := rect.get_center()
	var moving := _moving_center(unit[0])
	if moving.x >= 0.0:
		rect.position += moving - c
		c = moving
	var sprite := _unit_sprite(unit[3], unit[2], unit[6])
	var outline := TilePalette.ENEMY_OUTLINE if unit[2] == Faction.AI else TilePalette.OUTLINE
	var thickness := maxf(1.0, layout.tile_size / 48.0)
	for offset in [Vector2(thickness, 0), Vector2(-thickness, 0), Vector2(0, thickness), Vector2(0, -thickness)]:
		_draw_clipped(sprite, Rect2(rect.position + offset, rect.size), outline)  # the dark or violet edge, 1 pt
	_draw_clipped(sprite, rect, Color.WHITE)
	if unit[6]:  # asleep: a bar across the body
		draw_line(c + Vector2(-layout.tile_size * 0.3, 0), c + Vector2(layout.tile_size * 0.3, 0), TilePalette.OUTLINE, 2.0)
	if snapshot.player_turn and unit[2] == Faction.PLAYER and not unit[7] and not unit[8]:
		_draw_idle_mark(rect)
	if unit[4] < unit[5]:
		var bar := Rect2(rect.position + Vector2(layout.tile_size * 0.1, layout.tile_size * 0.86), Vector2(layout.tile_size * 0.8, 3.0))
		draw_rect(bar, TilePalette.OUTLINE)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(unit[4]) / unit[5], bar.size.y)), TilePalette.owner(Faction.PLAYER, colorblind))


## A unit of the player that has neither moved nor acted this turn: a dot at the top right
## (a shape, not only a colour: a light disc with a dark ring).
func _draw_idle_mark(rect: Rect2) -> void:
	var center := rect.position + Vector2(rect.size.x * 0.84, rect.size.y * 0.16)
	var radius := maxf(3.0, layout.tile_size * 0.08)
	if not clip_area.has_point(center):
		return
	draw_circle(center, radius + 1.0, TilePalette.OUTLINE)
	draw_circle(center, radius, TilePalette.SELECTION)


## The sprite of a unit type for a side: grey with the colour of the side in it; a dormant
## drone stays grey (it belongs to nobody).
func _unit_sprite(type: int, faction: int, asleep: bool) -> Texture2D:
	var key: String = _type_keys[type] if type < _type_keys.size() else UNIT_KEYS[type % UNIT_KEYS.size()]
	var grey: Texture2D = _units[key]
	if asleep or faction == Faction.NONE:
		return grey
	return _tint(key, grey, TilePalette.owner(faction, colorblind))


## `texture` with `tint` blended into the silhouette (the sprite is its own mask; the delivered
## masks cover exactly the silhouette), made once per texture and colour.
func _tint(key: String, texture: Texture2D, tint: Color) -> Texture2D:
	var id := "%s|%s" % [key, tint.to_html(false)]
	if _tinted.has(id):
		return _tinted[id]
	var image := Image.new()
	image.copy_from(texture.get_image())  # a copy: the texture's own image is shared, never written
	image.convert(Image.FORMAT_RGBA8)
	var overlay := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	overlay.fill(Color(tint, TINT_STRENGTH))
	image.blend_rect_mask(overlay, image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	image.generate_mipmaps()
	_tinted[id] = ImageTexture.create_from_image(image)
	return _tinted[id]


## Where an animated unit is drawn: along its MOVE effect, (-1, -1) when it is not moving.
func _moving_center(unit_id: int) -> Vector2:
	if clock == null:
		return Vector2(-1, -1)
	for effect in effects:
		if effect.kind == TileEffect.Kind.MOVE and effect.unit_id == unit_id:
			return layout.center_of(effect.tile).lerp(layout.center_of(effect.tile2), effect.progress(clock.current()))
	return Vector2(-1, -1)


func _draw_effect(effect: TileEffect) -> void:
	var now := clock.current() if clock != null else effect.start + effect.duration
	var p := effect.progress(now)
	match effect.kind:
		TileEffect.Kind.LINE:
			draw_line(layout.center_of(effect.tile), layout.center_of(effect.tile2), Color(TilePalette.SELECTION, 1.0 - 0.5 * p), 3.0)
		TileEffect.Kind.FLOAT_TEXT:
			var at := layout.center_of(effect.tile) + Vector2(-layout.tile_size * 0.2, -layout.tile_size * 0.3 - layout.tile_size * 0.4 * p)
			draw_string(ThemeDB.fallback_font, at, effect.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(effect.color, 1.0 - p * p))
		TileEffect.Kind.GHOST:
			var tile := layout.rect_of(effect.tile)
			var sag := Rect2(tile.position.x, tile.end.y - tile.size.y * (1.0 - 0.5 * p), tile.size.x, tile.size.y * (1.0 - 0.5 * p))
			_draw_clipped(_unit_sprite(effect.unit_type, Faction.NONE, true), sag, Color(1, 1, 1, 0.8 * (1.0 - p)))  # it sags
			_draw_clipped(_fx["debris"], tile, Color(TilePalette.owner(Faction.NONE, colorblind), p))  # and leaves its debris
		TileEffect.Kind.PULSE:  # a ring leaves the selected tile and fades
			var ring := layout.rect_of(effect.tile).grow(layout.tile_size * 0.3 * p)
			draw_rect(ring, Color(TilePalette.SELECTION, 0.9 * (1.0 - p)), false, 2.0)
		TileEffect.Kind.MOVE:  # the path the unit has taken, fading
			var here := layout.center_of(effect.tile).lerp(layout.center_of(effect.tile2), p)
			draw_line(layout.center_of(effect.tile), here, Color(TilePalette.SELECTION, 0.55 * (1.0 - p * p)), 3.0)
		TileEffect.Kind.WAVE:
			pass  # drawn with the tiles themselves (_draw_tile): a wave changes the tint of a tile


func _draw_threat(threat: Array) -> void:
	_draw_clipped(_fx["menace"], layout.rect_of(threat[2]), Color(TilePalette.THREAT, 0.85))


## True when the whole tile is inside the shown part of the map.
func _inside(tile: int) -> bool:
	return clip_area.encloses(layout.rect_of(tile))
