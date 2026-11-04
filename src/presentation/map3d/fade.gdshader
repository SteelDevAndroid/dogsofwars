// The edge of the fog: a flat colour whose opacity comes from the vertices (opaque at the edge
// of the unknown, clear half a tile in), unlit like the fog slabs it meets.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 color : source_color = vec3(0.196, 0.227, 0.267);

void fragment() {
	ALBEDO = color;
	ALPHA = COLOR.a;
}
