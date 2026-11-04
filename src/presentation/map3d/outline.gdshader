// The 1 pt edge of a unit (art bible 5): the hull, a little larger, seen from inside.
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec3 color : source_color = vec3(0.118, 0.137, 0.161);
uniform float grow = 0.07;

void vertex() {
	VERTEX = VERTEX * (1.0 + grow) - vec3(0.0, 0.01, 0.0);
}

void fragment() {
	ALBEDO = color;
}
