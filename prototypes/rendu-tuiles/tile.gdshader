// PROTOTYPE - NOT FOR PRODUCTION
// Question: wave computed in shader from per-instance start time + global time
// Date: 2026-10-30
shader_type canvas_item;

global uniform float g_time;          // seconds, written once per frame
uniform vec3 pal[8];                  // mode*4 + idx : 0 gray, 1 propre, 2 ennemi, 3 fog
uniform int mode = 0;                 // 0 normal, 1 daltonien
uniform float t_fondu = 0.4;
uniform float t_rev = 0.15;

varying flat vec4 cd;                 // shown, prev, fog(+4 if revelation), start

void vertex() {
	cd = INSTANCE_CUSTOM;
}

void fragment() {
	int shown = int(cd.x + 0.5);
	int prev = int(cd.y + 0.5);
	float fogf = cd.z;
	bool rev = fogf > 3.5;
	int fog = int(fogf - (rev ? 4.0 : 0.0) + 0.5);
	float D = rev ? t_rev : t_fondu;
	float u = clamp((g_time - cd.w) / D, 0.0, 1.0);
	int base = mode * 4;
	vec3 gray = pal[base];
	vec3 fogc = pal[base + 3];
	float s;
	int hue;
	if (prev == shown) { s = shown == 0 ? 0.0 : 1.0; hue = shown; }
	else if (prev == 0) { s = u; hue = shown; }
	else if (shown == 0) { s = 1.0 - u; hue = prev; }
	else if (u < 0.5) { s = 1.0 - 2.0 * u; hue = prev; }   // f -> gris, jamais de melange
	else { s = 2.0 * u - 1.0; hue = shown; }                // gris -> g
	vec3 col = mix(gray, pal[base + hue], s);
	if (fog == 0) col = fogc;                  // INCONNUE aplatie
	else if (fog == 1) col = mix(col, fogc, 0.45); // EXPLOREE assombrie
	COLOR = vec4(col, 1.0);
}
