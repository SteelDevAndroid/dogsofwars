# The colours an illustration gives a map (tools/maps/from_illustration.py): `art_index.json` says
# which colour image goes with which terrain (SHA-256 of the terrain codes, row by row), so a match
# resumed from a save finds its art from the terrain alone. The image has one pixel per tile, the
# mean colour of that tile in the picture. The 3D map multiplies the grey of a tile by how far its
# colour is from the average colour of its terrain (`ground`), so the sand, the rock, the salt and
# the canyon read as in the picture while the relief and the recoloration stay the game's own.
class_name MapArt
extends RefCounted

const INDEX := "res://assets/art/maps/art_index.json"
const DIR := "res://assets/art/maps"
## How far a tile may leave the average of its terrain, and how much of that gap is shown.
const RATIO_MIN := 0.6
const RATIO_MAX := 1.5
const STRENGTH := 0.7


## The colour image of the map whose terrain is `cells` (row-major terrain codes), or null.
static func colors_for(cells: PackedByteArray, index_path: String = INDEX, dir: String = DIR) -> Image:
	if not FileAccess.file_exists(index_path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("maps")) != TYPE_DICTIONARY:
		return null
	var hash := signature(cells)
	for entry: Variant in (parsed["maps"] as Dictionary).values():
		if typeof(entry) == TYPE_DICTIONARY and entry.get("sha256") == hash:
			return _load("%s/%s" % [dir, entry.get("colors", "")])
	return null


static func signature(cells: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(cells)
	return context.finish().hex_encode()


## One colour per tile: its multiplier on the grey of the terrain (1, 1, 1 is "unchanged").
static func ground(colors: Image, cells: PackedByteArray) -> PackedColorArray:
	var count := cells.size()
	var multipliers := PackedColorArray()
	if colors == null or colors.get_width() * colors.get_height() != count:
		return multipliers
	var width := colors.get_width()
	var sums := {}
	var counts := {}
	for tile in count:
		var color := colors.get_pixel(tile % width, tile / width)
		var kind := cells[tile]
		sums[kind] = sums.get(kind, Color(0, 0, 0)) + color
		counts[kind] = counts.get(kind, 0) + 1
	for tile in count:
		var color := colors.get_pixel(tile % width, tile / width)
		var mean: Color = sums[cells[tile]] / float(counts[cells[tile]])
		multipliers.append(Color(_ratio(color.r, mean.r), _ratio(color.g, mean.g), _ratio(color.b, mean.b)))
	return multipliers


static func _ratio(value: float, mean: float) -> float:
	return lerpf(1.0, clampf(value / maxf(mean, 0.02), RATIO_MIN, RATIO_MAX), STRENGTH)


static func _load(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	return texture.get_image() if texture != null else null
