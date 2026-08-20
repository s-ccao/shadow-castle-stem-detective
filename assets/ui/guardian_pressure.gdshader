shader_type canvas_item;
render_mode unshaded;

// Guardian pressure is information, not decoration. The contact meter can be
// missed while the player is steering, so the world itself loses stability as
// capture approaches. UI is drawn on a higher CanvasLayer and stays sharp.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centred = uv - vec2(0.5);
	float edge = smoothstep(0.12, 0.72, length(centred));

	// Two frequencies avoid a regular left-right shake. The centre remains much
	// steadier than the edges so movement is still controllable at full pressure.
	float shiver = sin(TIME * 27.0 + uv.y * 31.0)
		+ sin(TIME * 41.0 - uv.y * 19.0) * 0.45;
	float displacement = shiver * 0.0022 * strength * (0.28 + edge * 0.72);
	vec2 warped_uv = clamp(uv + vec2(displacement, displacement * -0.22), vec2(0.002), vec2(0.998));

	// A small cross blur grows only in the final half. At maximum it is visibly
	// wrong without destroying the corridor edges the player still needs.
	float blur = 0.0017 * smoothstep(0.42, 1.0, strength);
	vec3 colour = texture(screen_texture, warped_uv).rgb * 0.44;
	colour += texture(screen_texture, warped_uv + vec2(blur, 0.0)).rgb * 0.14;
	colour += texture(screen_texture, warped_uv - vec2(blur, 0.0)).rgb * 0.14;
	colour += texture(screen_texture, warped_uv + vec2(0.0, blur)).rgb * 0.14;
	colour += texture(screen_texture, warped_uv - vec2(0.0, blur)).rgb * 0.14;

	// Chromatic separation is confined to the rim; it reads as a destabilising
	// field rather than a camera focus failure.
	float split = 0.0024 * strength * edge;
	colour.r = texture(screen_texture, clamp(warped_uv + vec2(split, 0.0), vec2(0.002), vec2(0.998))).r;
	colour.b = texture(screen_texture, clamp(warped_uv - vec2(split, 0.0), vec2(0.002), vec2(0.998))).b;

	float pulse = 0.90 + sin(TIME * mix(2.0, 7.0, strength)) * 0.04 * strength;
	float vignette = 1.0 - edge * 0.28 * strength;
	COLOR = vec4(colour * pulse * vignette, 1.0);
}
