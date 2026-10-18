shader_type canvas_item;
render_mode unshaded;

uniform float scan : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 fog = texture(TEXTURE, UV);
	float written = step(UV.x, scan);
	float known = 1.0 - step(0.99, fog.a);
	float nib = (1.0 - smoothstep(0.0, 0.012, abs(UV.x - scan))) * known;
	// This effect can only ADD darkness to the existing CPU exploration mask.
	// Unknown pixels remain opaque black, including along the moving ink edge.
	COLOR = vec4(vec3(0.22, 0.16, 0.07) * nib, max(fog.a, 1.0 - written));
}
