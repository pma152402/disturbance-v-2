// Light grey stone with irregular darker clouds and subtle mineral veins.
float marble_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 marble_gradient(vec2 cell) {
	float angle = marble_hash(cell) * 6.2831853;
	return vec2(cos(angle), sin(angle));
}

float marble_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	// Gradient noise with smooth second derivatives avoids the square patches
	// produced by interpolating a flat colour at each lattice corner.
	vec2 blend = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(marble_gradient(cell), f);
	float b = dot(marble_gradient(cell + vec2(1, 0)), f - vec2(1, 0));
	float c = dot(marble_gradient(cell + vec2(0, 1)), f - vec2(0, 1));
	float d = dot(marble_gradient(cell + vec2(1, 1)), f - vec2(1, 1));
	return 0.5 + 0.5 * mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}

void kitchen_stone(vec2 uv, out vec3 stone, out float roughness) {
	float slab_size = 0.80;
	vec2 cell = floor(uv / slab_size);
	vec2 p = mod(uv, slab_size);
	float seed = marble_hash(cell);
	// Stone uses continuous coordinates; only the grout uses tile-local p.
	// Rotate successive noise layers so their grids cannot line up into boxes.
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	vec2 q = turn * uv + vec2(3.7, 8.2);
	vec2 warp = vec2(marble_noise(q * 1.3), marble_noise(turn * q * 1.6 + 19.0)) - 0.5;
	vec2 mineral = q + warp * 1.8;
	float cloud = marble_noise(mineral * 2.1) * 0.65 + marble_noise(turn * mineral * 5.3) * 0.35;
	float dark_patch = smoothstep(0.49, 0.64, cloud);
	float fine = marble_noise(mineral * 22.0);
	float vein_field = abs(marble_noise(turn * mineral * 3.2) - 0.51);
	float aa = max(max(fwidth(uv.x), fwidth(uv.y)), 0.0003);
	float vein = (1.0 - smoothstep(0.003, 0.012 + aa * 0.5, vein_field)) * smoothstep(0.43, 0.60, cloud);
	stone = mix(vec3(0.36, 0.37, 0.37), vec3(0.19, 0.21, 0.22), dark_patch * 0.75);
	stone *= mix(0.985, 1.015, seed) + (fine - 0.5) * 0.055;
	stone = mix(stone, vec3(0.17, 0.19, 0.20), vein * 0.20);
	vec2 edge = min(p, vec2(slab_size) - p);
	float grout = 1.0 - smoothstep(0.0015 - aa * 0.5, 0.0015 + aa * 0.5, min(edge.x, edge.y));
	stone = mix(stone, vec3(0.25, 0.27, 0.27), grout);
	roughness = mix(0.40 + cloud * 0.10, 0.85, grout);
}
