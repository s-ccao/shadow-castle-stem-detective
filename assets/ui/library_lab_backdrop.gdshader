shader_type canvas_item;
render_mode unshaded;

uniform vec4 upper_tint : source_color = vec4(0.105, 0.072, 0.170, 1.0);
uniform vec4 lower_tint : source_color = vec4(0.018, 0.026, 0.052, 1.0);
uniform vec4 grid_tint : source_color = vec4(0.42, 0.31, 0.66, 1.0);
uniform vec4 scan_tint : source_color = vec4(0.92, 0.72, 0.34, 1.0);
uniform float energy : hint_range(0.0, 1.0) = 0.55;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec3 base = mix(lower_tint.rgb, upper_tint.rgb, pow(1.0 - uv.y, 1.35));

	vec2 grid_uv = uv * vec2(34.0, 15.0);
	vec2 grid_cell = abs(fract(grid_uv - 0.5) - 0.5) / max(fwidth(grid_uv), vec2(0.001));
	float grid_line = 1.0 - min(min(grid_cell.x, grid_cell.y), 1.0);
	float grid_pulse = 0.22 + 0.12 * sin(TIME * 0.75 + uv.y * 5.0);
	base += grid_tint.rgb * grid_line * grid_pulse * energy;

	float scan_y = fract(TIME * 0.055);
	float scan = exp(-abs(uv.y - scan_y) * 95.0);
	base += scan_tint.rgb * scan * 0.16 * energy;

	vec2 star_cell = floor(uv * vec2(72.0, 32.0));
	float star_seed = hash21(star_cell);
	vec2 star_uv = fract(uv * vec2(72.0, 32.0)) - 0.5;
	float star = smoothstep(0.07, 0.0, length(star_uv));
	star *= step(0.965, star_seed);
	star *= 0.35 + 0.65 * sin(TIME * (0.7 + star_seed) + star_seed * 16.0) * 0.5 + 0.5;
	base += mix(grid_tint.rgb, scan_tint.rgb, star_seed) * star * energy;

	float vignette = smoothstep(0.78, 0.18, length((uv - 0.5) * vec2(1.15, 0.92)));
	base *= mix(0.48, 1.0, vignette);

	COLOR = vec4(base, 0.94);
}
