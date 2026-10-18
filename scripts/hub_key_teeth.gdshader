shader_type canvas_item;
render_mode unshaded;

uniform float contact : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 source = COLOR;
	// The working teeth are on the lower shaft of the authored key raster.
	// Only brass pixels respond, never its transparent/background field.
	float teeth = step(0.60, UV.y) * (1.0 - step(0.86, UV.y));
	float brass = smoothstep(0.06, 0.22, source.r - source.b);
	source.rgb = mix(source.rgb, vec3(1.0, 0.84, 0.43), teeth * brass * contact * 0.68);
	COLOR = source;
}
