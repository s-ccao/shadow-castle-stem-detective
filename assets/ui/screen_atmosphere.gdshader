shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// Atmosphere pass for full-screen archive records (intake, interruption,
// resolution, archive review). It sits between the painted backdrop and the
// dossier so every screen inherits one lit-room feeling instead of each screen
// inventing its own: edge falloff, a single warm lamp, drifting dust and a
// faint emulsion grain.
//
// Premultiplied alpha lets one pass both darken (COLOR.a) and emit (COLOR.rgb),
// so the vignette and the motes never need two stacked overlays.

uniform vec4 edge_tint : source_color = vec4(0.010, 0.006, 0.020, 1.0);
uniform vec4 lamp_tint : source_color = vec4(1.0, 0.76, 0.40, 1.0);
uniform vec4 mote_tint : source_color = vec4(1.0, 0.88, 0.58, 1.0);
uniform vec2 lamp_anchor = vec2(0.5, 0.26);
uniform float aspect = 1.3333;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.58;
uniform float vignette_radius : hint_range(0.2, 1.4) = 0.34;
uniform float lamp_strength : hint_range(0.0, 1.0) = 0.26;
uniform float lamp_radius : hint_range(0.05, 1.5) = 0.46;
uniform float mote_strength : hint_range(0.0, 1.0) = 0.42;
uniform float grain_strength : hint_range(0.0, 0.25) = 0.030;
// Slow uneasy breathing for failure states; 0.0 keeps the room perfectly still.
uniform float unrest : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(127.31, 311.7));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float mote_layer(vec2 uv, float scale, float rise, float seed_shift) {
	vec2 p = uv * scale;
	p.y -= TIME * rise;
	p.x += sin(TIME * 0.17 + p.y * 0.55 + seed_shift) * 0.22;
	vec2 cell = floor(p);
	vec2 offset = fract(p) - 0.5;
	float seed = hash21(cell + vec2(seed_shift));
	float present = step(0.945, seed);
	float radius = 0.045 + 0.055 * fract(seed * 37.13);
	float speck = smoothstep(radius, 0.0, length(offset));
	float twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(TIME * (0.7 + seed * 1.6) + seed * 21.0));
	return speck * present * twinkle;
}

void fragment() {
	vec2 uv = UV;
	vec2 centred = (uv - vec2(0.5)) * vec2(aspect, 1.0);
	float falloff = smoothstep(vignette_radius, 1.05, length(centred));
	float breath = 1.0 + unrest * 0.10 * sin(TIME * 0.9);
	float vignette = clamp(pow(falloff, 1.25) * vignette_strength * breath, 0.0, 0.96);

	float lamp_flicker = 0.86
		+ 0.14 * (0.5 + 0.5 * sin(TIME * 2.7)) * (0.5 + 0.5 * sin(TIME * 1.13 + 1.7));
	float lamp_distance = length((uv - lamp_anchor) * vec2(aspect, 1.0)) / max(lamp_radius, 0.05);
	float lamp = exp(-lamp_distance * lamp_distance * 1.8) * lamp_strength * lamp_flicker;

	float motes = mote_layer(uv, 11.0, 0.42, 0.0) * 0.70;
	motes += mote_layer(uv, 19.0, 0.26, 5.3) * 0.42;
	motes *= mote_strength * (1.0 - vignette * 0.45);

	vec2 grain_uv = uv * vec2(1024.0, 768.0)
		+ vec2(fract(TIME * 7.3) * 137.0, fract(TIME * 5.1) * 91.0);
	float grain = max(hash21(grain_uv) - 0.5, 0.0) * grain_strength;

	vec3 emitted = edge_tint.rgb * vignette;
	emitted += lamp_tint.rgb * lamp;
	emitted += mote_tint.rgb * motes;
	emitted += vec3(grain);

	COLOR = vec4(emitted, vignette);
}
