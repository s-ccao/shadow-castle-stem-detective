shader_type canvas_item;
render_mode unshaded;

uniform sampler2D specimens : filter_nearest, repeat_disable;
uniform sampler2D vessel_front : filter_nearest, repeat_disable;
uniform sampler2D physical_masks : filter_nearest, repeat_disable;
uniform vec2 glass_origin[7];
uniform vec4 glass_pose[7];
uniform bool glass_fractured = false;
uniform vec4 ice_state;
uniform int preset = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float local_time = 0.0;
uniform float event_onset = 0.0;
uniform float variation = 0.0;
uniform bool active = false;

vec4 over(vec4 under, vec4 top) {
	float a = top.a + under.a * (1.0 - top.a);
	return vec4((top.rgb * top.a + under.rgb * under.a * (1.0 - top.a)) / max(a, 0.0001), a);
}

float noise(vec2 p) {
	return fract(sin(dot(floor(p), vec2(127.1, 311.7)) + variation * 17.0) * 43758.5453);
}

vec2 object_uv(vec2 p, vec2 center, vec2 extent, float angle) {
	vec2 q = p - center;
	return vec2(q.x * cos(angle) + q.y * sin(angle), -q.x * sin(angle) + q.y * cos(angle)) / max(extent, vec2(0.01)) + 0.5;
}

vec4 tile(vec2 uv, float index) {
	vec2 cell = vec2(mod(index, 8.0), floor(index / 8.0));
	vec2 pixel = clamp(floor(uv * 64.0), vec2(0.0), vec2(63.0)) + 0.5;
	vec4 texel = texture(specimens, (cell * 64.0 + pixel) / vec2(512.0, 256.0));
	texel.a *= step(0.0, uv.x) * step(0.0, uv.y) * (1.0 - step(1.0, uv.x)) * (1.0 - step(1.0, uv.y));
	return texel;
}

vec4 specimen(vec2 p, float index, vec2 center, vec2 extent, float angle) {
	return tile(object_uv(p, center, extent, angle), index);
}

vec4 faded(vec4 color, float amount) {
	color.a *= clamp(amount, 0.0, 1.0);
	return color;
}

float pulse(float p) {
	return smoothstep(0.04, 0.18, p) * (1.0 - smoothstep(0.72, 1.0, p));
}

vec4 liquid(vec2 p, float index, float level, float agitation) {
	vec2 q = p;
	q.y += floor(sin(q.x * 0.085 + local_time * 4.0) * agitation);
	return specimen(q, index, vec2(150.0, 90.0 - level * 14.53125), vec2(239.0, max(0.01, level * 62.0)), 0.0);
}

float liquid_surface(float level) {
	return 90.0 - 28.09375 * level;
}

vec4 vapor(vec4 color, vec2 p, float strength, bool smoke, float source_x, float source_y) {
	if (strength <= 0.0) {
		return color;
	}
	for (int i = 0; i < 9; i++) {
		if (!smoke && i >= 7) {
			continue;
		}
		float fi = float(i);
		float seed = noise(vec2(fi * 3.0, 14.0));
		float delay = event_onset + fi * 0.085 + seed * 0.04;
		float age = local_time - delay;
		if (age < 0.0) {
			continue;
		}
		float lifetime = (smoke ? 1.2 : 0.95) + seed * 0.22;
		float birth = delay + floor(age / lifetime) * lifetime;
		if (birth > 1.95) {
			continue;
		}
		float life = mod(age, lifetime) / lifetime;
		vec4 cloud;
		if (smoke) {
			float drift = life * 15.0 + sin(local_time * 1.8 + life * 4.0) * life * 11.0;
			vec2 center = vec2(source_x + (seed - 0.5) * (12.0 + life * 18.0) + drift, source_y - life * 58.0);
			cloud = specimen(p, 25.0, center, vec2(27.0 + life * 34.0, 30.0 + life * 37.0), (seed - 0.5) * 0.35);
			cloud.rgb *= mix(vec3(0.61, 0.50, 0.43), vec3(0.72, 0.73, 0.73), life);
			cloud.a *= 1.6 * smoothstep(0.0, 8.0, p.y);
		} else {
			vec2 center = vec2(source_x + (seed - 0.5) * 39.0 + sin(life * 5.0 + fi) * 8.0, source_y - 8.0 - life * 47.0);
			cloud = specimen(p, 25.0, center, vec2(18.0 + life * 33.0, 25.0 + life * 35.0), 0.0);
		}
		color = over(color, faded(cloud, sin(life * 3.14159) * strength));
	}
	return color;
}

vec4 bubbles(vec4 color, vec2 p, float strength, bool fizz, float level) {
	if (strength <= 0.0 || level < 0.12) {
		return color;
	}
	for (int i = 0; i < 16; i++) {
		float fi = float(i);
		float seed = noise(vec2(fi, 38.0));
		float age = local_time - event_onset - fi * 0.037 - seed * 0.06;
		if (age < 0.0) {
			continue;
		}
		float life = fract(age * ((fizz ? 0.85 : 0.75) + seed * 0.28));
		float surface = liquid_surface(level) + 3.0;
		float radius = min((fizz ? 9.0 : 8.0) + seed * (fizz ? 15.0 : 14.0), (90.0 - surface) * 0.85);
		float rise = pow(min(life / 0.8, 1.0), 0.78);
		vec2 center = vec2(88.0 + seed * 123.0 + sin(life * 7.0 + fi) * 2.0, mix(90.0 - radius * 0.34, surface + radius * 0.3, rise));
		if (life < 0.8) {
			color = over(color, faded(specimen(p, 26.0, center, vec2(radius * (0.55 + rise * 0.45)), 0.0), strength * smoothstep(0.0, 0.12, life)));
		} else {
			float pop = (life - 0.8) * 5.0;
			vec2 uv = object_uv(p, center, vec2(radius * (1.0 + pop * 0.7), radius * (0.65 - pop * 0.3)), 0.0);
			vec4 ring = tile(uv, 26.0);
			ring.a *= step(0.16 + pop * 0.14, abs(uv.x - 0.5));
			color = over(color, faded(ring, strength * (1.0 - pop)));
		}
	}
	return color;
}

void fragment() {
	vec2 p = floor(UV * vec2(300.0, 110.0)) + 0.5;
	float t = progress;
	float motion = active ? pulse(t) : 0.0;
	float ease = smoothstep(0.0, 1.0, t);
	float reflected_heat = 0.0;
	vec3 backdrop = mix(vec3(0.047, 0.043, 0.067), vec3(0.095, 0.084, 0.111), max(0.0, 1.0 - length((p - vec2(150.0, 75.0)) / vec2(170.0, 85.0))));
	vec4 color = over(vec4(backdrop, 1.0), texture(TEXTURE, UV));

	if (preset == 0) {
		// Burn a travelling edge into the raster paper, leaving ash rather than a dissolve glow.
		color = over(color, faded(specimen(p, 16.0, vec2(150.0, 65.0), vec2(99.0, 43.0 + t * 14.0), 0.0), smoothstep(0.12, 0.8, t)));
		vec2 uv = object_uv(p, vec2(150.0, 53.0 + ease * 16.0), vec2(78.0, 78.0 - ease * 26.0), -0.10 + ease * 0.16);
		vec4 paper = tile(uv, 0.0);
		float edge = (1.0 - uv.y) * 0.61 + (1.0 - uv.x) * 0.20 + noise(uv * 9.0) * 0.22 + noise(uv * 37.0) * 0.08;
		float charred = smoothstep(edge - 0.19, edge - 0.02, t * 1.25) * smoothstep(0.02, 0.12, t);
		paper.rgb = mix(paper.rgb, vec3(0.17, 0.135, 0.14) + noise(uv * 47.0) * 0.07, charred);
		float consumed = smoothstep(edge + 0.17, edge + 0.26, t * 1.3);
		paper.a *= (1.0 - consumed) * (1.0 - smoothstep(0.88, 1.0, t));
		float ember_edge = (1.0 - smoothstep(0.0, 0.045, abs(t * 1.3 - edge - 0.18))) * motion;
		paper.rgb += vec3(0.23, 0.067, 0.016) * ember_edge;
		color = over(color, paper);
		reflected_heat = motion * (1.0 - smoothstep(0.58, 0.90, t));
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float seed = noise(vec2(fi, 24.0));
			float flicker = sin(local_time * (9.0 + seed * 6.0) + fi * 2.3) + sin(local_time * 21.0 + seed * 8.0) * 0.35;
			float height = ((i == 1 ? 68.0 : 32.0 + seed * 19.0) + flicker * 8.0) * (0.7 + reflected_heat * 0.3);
			vec2 center = vec2(136.0 + fi * 11.0 + seed * 3.0, 84.0 - height * 0.36);
			vec2 flame_uv = object_uv(p, center, vec2(i == 1 ? 44.0 : 29.0 + seed * 12.0, height), (seed - 0.5) * 0.21);
			flame_uv.x += pow(max(0.0, 1.0 - flame_uv.y), 2.0) * sin(local_time * 8.0 + flame_uv.y * 5.0 + fi) * 0.14;
			color = over(color, faded(tile(flame_uv, 24.0), reflected_heat * (0.73 + seed * 0.27)));
			float life = fract(local_time * (0.48 + seed * 0.2) + seed * 2.7);
			float ember_life = smoothstep(0.08, 0.2, life) * (1.0 - smoothstep(0.46, 0.80, life));
			color = over(color, faded(specimen(p, 27.0, vec2(136.0 + fi * 9.0 + life * 17.0 + sin(fi + life * 4.0) * 7.0, 70.0 - life * 56.0), vec2(7.0 + seed * 4.0), 0.0), motion * ember_life));
		}
		color = vapor(color, p, motion, true, 149.0, 64.0);
	} else if (preset == 1) {
		// A raster melt-front retreats inward; the remaining bottom stays on the tray.
		float pool_size = sqrt(ice_state.z / 0.917);
		if (pool_size > 0.0) {
			color = over(color, specimen(p, 21.0, vec2(150.0, 86.0), vec2(205.0, 36.0) * pool_size, 0.0));
		}
		vec2 uv = object_uv(p, vec2(150.0, 90.0 - (ice_state.y - 32.0) * 79.0 / 64.0), vec2(79.0), 0.0);
		vec4 ice = tile(uv, 1.0);
		float arrival = floor(texture(physical_masks, vec2(0.5 + clamp(uv.x, 0.0, 0.999) * 0.5, clamp(uv.y, 0.0, 0.999))).r * 255.0 + 0.5);
		ice.a *= step(ice_state.x + 0.5, arrival);
		float wet_edge = (1.0 - smoothstep(0.0, 16.0, arrival - ice_state.x)) * step(0.5, ice_state.x);
		ice.rgb = mix(ice.rgb, vec3(0.73, 0.88, 0.89), wet_edge * 0.4);
		color = over(color, ice);
	} else if (preset == 2) {
		// Complementary masks move the original pane pixels, not replacement triangle sprites.
		for (int i = 0; i < 7; i++) {
			vec4 pose = glass_pose[i];
			vec2 q = p - pose.xy;
			q.y /= max(0.01, pose.w);
			q = vec2(q.x * cos(pose.z) + q.y * sin(pose.z), -q.x * sin(pose.z) + q.y * cos(pose.z));
			vec2 uv = (q * 64.0 / 79.0 + glass_origin[i]) / 64.0;
			vec2 mask_uv = vec2(clamp(uv.x, 0.0, 0.999) * 0.5, clamp(uv.y, 0.0, 0.999));
			float region = floor(texture(physical_masks, mask_uv).r * 255.0 + 0.5);
			vec4 shard = tile(uv, 2.0);
			shard.a *= 1.0 - step(0.5, abs(region - float(i + 1)));
			if (glass_fractured && shard.a > 0.0) {
				float neighbor = floor(texture(physical_masks, mask_uv + vec2(1.0 / 128.0, 0.0)).r * 255.0 + 0.5);
				float edge = step(0.5, abs(neighbor - region));
				shard.rgb = mix(shard.rgb, vec3(0.77, 0.80, 0.74), edge * 0.6);
				shard.a = max(shard.a, edge * 0.65);
			}
			color = over(color, shard);
		}
	} else if (preset == 3) {
		color = over(color, liquid(p, 21.0, 1.0, motion * 0.5));
		for (int i = 0; i < 9; i++) {
			float fi = float(i);
			float seed = noise(vec2(fi, 10.0));
			float dissolve = smoothstep(seed * 0.18, 0.68 + seed * 0.28, t);
			vec2 center = vec2(106.0 + noise(vec2(fi, 42.0)) * 85.0, 82.0 + seed * 5.0);
			vec4 grain = specimen(p, 3.0, center, vec2(23.0 * max(0.01, 1.0 - dissolve)), fi);
			color = over(color, grain);
		}
	} else if (preset == 4 || preset == 10) {
		vec2 uv = object_uv(p, vec2(150.0, 56.0), vec2(86.0), 0.0);
		vec4 metal = tile(uv, preset == 4 ? 4.0 : 9.0);
		float coarse = noise(uv * 10.0) * 0.62 + noise(uv * 37.0) * 0.28;
		float spread = smoothstep(coarse - 0.08, coarse + 0.08, t * 1.1 - 0.09);
		float pits = noise(uv * 32.0);
		vec3 patina = preset == 4 ? mix(vec3(0.29, 0.135, 0.10), vec3(0.66, 0.35, 0.16), pits) : mix(vec3(0.10, 0.095, 0.13), vec3(0.29, 0.27, 0.33), pits);
		float relief = dot(metal.rgb, vec3(0.333));
		metal.rgb = mix(metal.rgb, patina * (0.55 + relief * 0.85), spread * (preset == 10 ? 0.90 : 0.94));
		color = over(color, metal);
	} else if (preset == 5) {
		color = over(color, faded(specimen(p, 22.0, vec2(150.0, 84.0), vec2(45.0 + ease * 143.0, 20.0 + ease * 19.0), 0.0), smoothstep(0.0, 0.30, t)));
		float shrink = 1.0 - smoothstep(0.05, 0.99, t);
		vec2 wax_p = p;
		wax_p.x -= pow(max(0.0, (90.0 - p.y) / 65.0), 2.0) * ease * 8.0;
		vec2 extent = vec2(78.0 + sin(ease * 3.14159) * 12.0, max(0.1, 78.0 * shrink));
		color = over(color, specimen(wax_p, 5.0, vec2(150.0, 90.0 - extent.y * 0.375), extent, 0.0));
	} else if (preset == 6) {
		vec4 fluid = liquid(p, 21.0, 1.0, motion);
		fluid.rgb *= vec3(1.12, 1.03, 0.88);
		color = over(color, fluid);
		color = over(color, faded(specimen(p, 6.0, vec2(150.0, 58.0), vec2(62.0, 51.0), 0.0), 1.0 - smoothstep(0.1, 0.58, t)));
		color = bubbles(color, p, motion, true, 1.0);
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float swell = sin(local_time * (4.0 + fi) + fi * 1.8);
			color = over(color, faded(specimen(p, 30.0, vec2(119.0 + fi * 32.0, 65.0 - motion * (3.0 + swell)), vec2(65.0 - fi * 6.0, 21.0 + motion * (15.0 + swell * 4.0)), 0.0), motion * (0.76 - fi * 0.12) + ease * 0.06));
		}
	} else if (preset == 7) {
		float level = max(0.0, 1.0 - ease);
		color = over(color, liquid(p, 21.0, level, motion * level));
		color = bubbles(color, p, motion, false, level);
		color = vapor(color, p, motion * 1.65, false, 150.0, liquid_surface(level));
	} else if (preset == 8) {
		vec2 uv = object_uv(p, vec2(150.0, 63.0), vec2(156.0, 77.0), 0.0);
		vec4 raw = tile(uv, 7.0);
		vec4 cooked = tile(uv, 23.0);
		float setting = smoothstep(0.04, 0.18, t - (1.0 - length((uv - vec2(0.5, 0.62)) * 2.0)) * 0.56 + noise(uv * 29.0) * 0.08);
		color = over(color, mix(raw, cooked, setting));
	} else if (preset == 9) {
		float tear = smoothstep(0.16, 0.82, t);
		float sag = smoothstep(0.65, 1.0, t) * 4.0;
		for (int i = 0; i < 2; i++) {
			float side = i == 0 ? -1.0 : 1.0;
			float y = (p.y - 56.0 - sag) / 76.0 + 0.5;
			float opening = smoothstep(y - 0.12, y + 0.06, tear);
			vec2 uv = object_uv(p, vec2(150.0 + side * tear * opening * 30.0, 56.0 + sag), vec2(91.0, 76.0), 0.0);
			float seam = 0.49 + (noise(vec2(floor(uv.y * 22.0), 77.0)) - 0.5) * 0.06;
			vec4 cloth = tile(uv, 8.0);
			cloth.a *= i == 0 ? 1.0 - step(seam, uv.x) : step(seam, uv.x);
			color = over(color, cloth);
		}
	} else if (preset == 11) {
		color = over(color, specimen(p, 10.0, vec2(159.0, 32.0), vec2(67.0), 3.14159));
		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			float travel = clamp((t - 0.12 - fi * 0.035) / (0.36 + fi * 0.025), 0.0, 1.0);
			float pull = (exp(travel * 2.6) - 1.0) / (exp(2.6) - 1.0);
			vec2 center = mix(vec2(103.0 + fi * 29.0, 87.0), vec2(fi < 2.0 ? 142.0 + fi * 5.0 : 175.0 + (fi - 2.0) * 5.0, 65.0), pull);
			color = over(color, specimen(p, 11.0, center, vec2(25.0, 42.0), mix(1.4 + fi * 0.2, 0.0, smoothstep(0.0, 0.7, travel))));
		}
	} else if (preset == 12) {
		vec4 milk = specimen(p, 12.0, vec2(150.0, 80.0), vec2(222.0, 51.0), 0.0);
		milk.rgb = mix(milk.rgb, milk.rgb * vec3(0.94, 0.94, 0.82), ease * 0.65);
		color = over(color, milk);
		for (int i = 0; i < 8; i++) {
			float fi = float(i);
			float seed = noise(vec2(fi, 13.0));
			float form = smoothstep(seed * 0.35 + 0.15, 0.86, t);
			vec2 center = vec2(88.0 + noise(vec2(fi, 43.0)) * 122.0, 75.0 + seed * 9.0);
			color = over(color, faded(specimen(p, 20.0, center, vec2(24.0 + seed * 13.0, 17.0 + seed * 12.0) * max(form, 0.01), (seed - 0.5) * 0.6), form * 0.88));
		}
	} else if (preset == 13) {
		color = over(color, liquid(p, 21.0, max(0.01, 1.0 - ease), 0.0));
		for (int i = 0; i < 10; i++) {
			float fi = float(i);
			float seed = noise(vec2(fi, 16.0));
			float growth = smoothstep(seed * 0.36 + 0.22, 0.9, t);
			float extent = (15.0 + seed * 20.0) * max(growth, 0.01);
			vec2 center = vec2(82.0 + noise(vec2(fi, 44.0)) * 136.0, 78.0 + seed * 12.0 - extent * 0.40625);
			color = over(color, specimen(p, 13.0, center, vec2(extent), 0.0));
		}
	} else if (preset == 14) {
		float heat = smoothstep(0.08, 0.65, t);
		vec2 q = p;
		q.x += floor(sin(p.y * 0.31 + local_time * 9.0) * motion * 0.85) * step(15.0, p.y) * (1.0 - step(64.0, p.y));
		color = over(color, specimen(q, 14.0, vec2(150.0, 55.0), vec2(85.0), 0.0));
		vec4 window = specimen(p, 31.0, vec2(150.0, 55.0), vec2(85.0), 0.0);
		window.a *= heat * (0.8 + motion * sin(local_time * 11.0) * 0.08);
		color = over(color, window);
		float glow = max(0.0, 1.0 - length((p - vec2(150.0, 54.0)) / vec2(27.0, 29.0)));
		color.rgb += vec3(0.12, 0.048, 0.012) * glow * heat;
		color = vapor(color, p, motion * 0.52, true, 164.0, 64.0);
	} else if (preset == 15) {
		float stretch = smoothstep(0.0, 0.40, t) * 0.86;
		if (t > 0.4) {
			stretch = 0.86 * cos((t - 0.4) * 32.0) * exp(-(t - 0.4) * 9.0);
		}
		if (!active) {
			stretch = 0.0;
		}
		color = over(color, specimen(p, 15.0, vec2(150.0, 65.0), vec2(105.0 * (1.0 + stretch), 67.0 - stretch * 11.0), 0.0));
	}

	float reflected_patch = max(0.0, 1.0 - length((p - vec2(151.0, 84.0)) / vec2(67.0, 17.0)));
	color.rgb += vec3(0.085, 0.031, 0.007) * reflected_patch * reflected_heat;
	vec4 glass = texture(vessel_front, UV);
	glass.rgb += vec3(0.23, 0.08, 0.012) * reflected_heat * reflected_patch;
	color = over(color, glass);
	COLOR = color;
}
