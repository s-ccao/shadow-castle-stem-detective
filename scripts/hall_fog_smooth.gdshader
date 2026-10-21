shader_type canvas_item;

// Smooths the Hall's fog-of-war grid. The fog is a 120x80 alpha image drawn
// 16x larger, so nearest sampling showed every 16 px cell as a hard black
// block, and plain bilinear sampling shows the grid as a diamond lattice. Easing
// the bilinear weights with a smoothstep keeps one texture fetch per pixel and
// turns each cell boundary into a soft, rounded falloff. Needs the node's
// texture filter set to linear.

void fragment() {
	vec2 cells = vec2(textureSize(TEXTURE, 0));
	vec2 position = UV * cells - 0.5;
	vec2 cell = floor(position);
	vec2 blend = fract(position);
	blend = blend * blend * (3.0 - 2.0 * blend);
	COLOR = texture(TEXTURE, (cell + blend + 0.5) / cells);
}
