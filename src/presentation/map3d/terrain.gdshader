// The map in flat colours (art bible 6): the vertex colour is the grey of the world; an owned
// tile takes its side's tint by `strength` (0 grey, 1 owned: the recoloration of GDD 15 animates
// it); an explored tile out of view is dimmed toward the grey-blue of memory.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec3 tint : source_color = vec3(1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float memory : hint_range(0.0, 1.0) = 0.0;
uniform vec3 memory_color : source_color = vec3(0.306, 0.345, 0.384);
// An artist's model carries its faction mask in the vertex alpha (1 = takes the side's tint,
// design/art/asset-specs.md); the shapes built in code tint the whole tile or bake the colour.
uniform bool use_mask = false;

void fragment() {
	vec3 base = COLOR.rgb;
	float luma = dot(base, vec3(0.2126, 0.7152, 0.0722));
	// the side's hue at the value of the terrain: relief and shade stay readable under the colour
	float tint_luma = max(dot(tint, vec3(0.2126, 0.7152, 0.0722)), 0.02);
	vec3 owned = clamp(tint * (luma / tint_luma) * 1.15, 0.0, 1.0);
	float mask = use_mask ? COLOR.a : 1.0;
	vec3 shown = mix(base, owned, strength * (use_mask ? 0.9 : 0.65) * mask);
	shown = mix(shown, memory_color * (0.4 + 2.0 * luma), memory * 0.6) * (1.0 - 0.4 * memory);
	ALBEDO = shown;
	ROUGHNESS = 1.0;
}
