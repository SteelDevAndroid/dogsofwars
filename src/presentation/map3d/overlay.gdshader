// Flat light marks laid on the tiles: move range, selection, threat. Unlit, so they read the same
// on every terrain and in shadow.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
