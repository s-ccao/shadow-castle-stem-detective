shader_type canvas_item;
render_mode unshaded;

// Revealing Draught: the castle drains to bone-grey while the potion runs.
//
// The point of the effect is not the tint, it is what the tint buys. Every
// colour in the hall competes for attention with the Guardian's footprints;
// pulling the saturation out leaves the prints as the only warm thing on the
// screen, so the player reads a direction rather than hunting for marks.
//
// It samples the screen rather than drawing over it, because a translucent grey
// sheet washes the picture out without ever making it monochrome — the reds
// stay red, just paler, and the footprints lose their advantage.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 wash_tint : source_color = vec4(0.80, 0.84, 0.90, 1.0);
uniform float lift : hint_range(0.0, 0.4) = 0.06;
// Slow breathing so the drained castle reads as an effect that is running
// rather than a screen that has broken.
uniform float pulse_speed : hint_range(0.0, 4.0) = 1.1;
uniform float pulse_depth : hint_range(0.0, 0.3) = 0.05;
uniform float vignette : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	// Rec. 709 luma: a plain channel average turns the hall's blues to mud and
	// its golds to paper, which loses the masonry the player navigates by.
	float luma = dot(source, vec3(0.2126, 0.7152, 0.0722));
	vec3 drained = vec3(luma) * wash_tint.rgb + vec3(lift * luma);

	float breath = 1.0 + sin(TIME * pulse_speed) * pulse_depth;
	float amount = clamp(strength * breath, 0.0, 1.0);
	vec3 mixed = mix(source, drained, amount);

	vec2 centred = SCREEN_UV - vec2(0.5);
	float edge = smoothstep(0.22, 0.72, length(centred));
	mixed *= 1.0 - edge * vignette * amount;

	COLOR = vec4(mixed, 1.0);
}
