shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float pixel_size : hint_range(1.0, 24.0, 1.0) = 8.0;
uniform float color_levels : hint_range(5.0, 64.0, 1.0) = 24.0;
uniform float noise_strength : hint_range(0.0, 0.25, 0.005) = 0.025;
uniform float chromatic_aberration : hint_range(0.0, 9.0, 0.1) = 1.2;
uniform float scanline_strength : hint_range(0.0, 0.6, 0.01) = 0.09;
uniform float fisheye_strength : hint_range(0.0, 0.03, 0.001) = 0.007;
uniform float vignette_strength : hint_range(0.0, 0.98, 0.01) = 0.94;
uniform float vignette_inner : hint_range(0.0, 0.6, 0.01) = 0.07;
uniform float vignette_outer : hint_range(0.2, 1.2, 0.01) = 0.47;

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(12.9898, 78.233))) * 43758.5453);
}

float ordered_dither(vec2 pixel) {
	vec2 p = mod(floor(pixel), 2.0);
	return mix(mix(0.0, 2.0, p.x), mix(3.0, 1.0, p.x), p.y) / 4.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float frame = floor(TIME * 24.0);
	vec2 lens_center = uv * 2.0 - 1.0;
	float screen_aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	lens_center.x *= screen_aspect;
	float lens_radius = dot(lens_center, lens_center);
	vec2 lens_direction = vec2(lens_center.x / screen_aspect, lens_center.y);
	uv += lens_direction * lens_radius * fisheye_strength;
	float horizontal_band = floor(uv.y * 105.0);
	float random_tear = step(0.965, hash21(vec2(frame * 0.17, horizontal_band)));
	uv.x += sin(uv.y * 18.0 + TIME * 1.7) * 0.00085;
	uv.x += random_tear * (hash21(vec2(horizontal_band, frame)) - 0.5) * 0.006;
	float interlace_shift = mod(floor(FRAGCOORD.y), 2.0) * SCREEN_PIXEL_SIZE.x * sin(frame * 0.37) * 1.5;
	uv.x += interlace_shift;
	float head_switch = smoothstep(0.82, 0.99, uv.y);
	uv.x += head_switch * sin(uv.y * 170.0 + TIME * 13.0) * 0.0028;

	vec2 block = SCREEN_PIXEL_SIZE * pixel_size;
	uv = floor(uv / block) * block + block * 0.5;
	vec2 rgb_offset = vec2(SCREEN_PIXEL_SIZE.x * chromatic_aberration, 0.0);
	vec3 source;
	source.r = texture(screen_texture, clamp(uv + rgb_offset, vec2(0.0), vec2(1.0))).r;
	source.g = texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0))).g;
	source.b = texture(screen_texture, clamp(uv - rgb_offset, vec2(0.0), vec2(1.0))).b;
	vec3 readable_source = texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
	source = mix(readable_source, source, 0.45);
	float edge_blur = smoothstep(0.18, 1.15, lens_radius) * 0.24;
	vec3 soft_sample = texture(screen_texture, clamp(uv + vec2(block.x * 1.5, block.y), vec2(0.0), vec2(1.0))).rgb;
	source = mix(source, soft_sample, edge_blur);

	float grain = hash21(floor(FRAGCOORD.xy / pixel_size) + vec2(frame * 7.1, frame * 3.7)) - 0.5;
	float dither = ordered_dither(FRAGCOORD.xy / pixel_size) - 0.375;
	float flicker = 0.965 + hash21(vec2(frame, 4.0)) * 0.055;
	float source_luma = dot(source, vec3(0.299, 0.587, 0.114));
	float shadow_noise = mix(1.25, 0.45, smoothstep(0.02, 0.72, source_luma));
	source = source * flicker + grain * noise_strength * shadow_noise + dither / color_levels;
	float luminance = dot(source, vec3(0.299, 0.587, 0.114));
	source = mix(source, vec3(luminance), 0.24);
	source *= vec3(0.91, 1.0, 0.94);
	vec3 limited = floor(clamp(source, 0.0, 1.0) * color_levels) / color_levels;

	float scanline = 1.0 - scanline_strength * (0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159));
	limited *= scanline;
	float dropout_seed = hash21(vec2(floor(FRAGCOORD.x / 4.0) + frame * 19.0, floor(FRAGCOORD.y / 3.0) - frame));
	float dropout = step(0.9975, dropout_seed);
	limited = mix(limited, vec3(0.34, 0.37, 0.35), dropout * 0.68);
	float tape_scar = step(0.992, hash21(vec2(floor(uv.y * 260.0), floor(TIME * 8.0)))) * step(0.42, hash21(vec2(floor(uv.x * 34.0), frame)));
	limited += tape_scar * vec3(0.055, 0.065, 0.058);
	float tracking_position = fract(TIME * 0.095);
	float tracking_line = 1.0 - smoothstep(0.0, 0.012, abs(uv.y - tracking_position));
	limited += tracking_line * vec3(0.07, 0.085, 0.075);

	vec2 centered = SCREEN_UV - vec2(0.5);
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float vignette = smoothstep(vignette_inner, vignette_outer, length(centered));
	float outside_lens = step(0.0, -uv.x) + step(1.0, uv.x) + step(0.0, -uv.y) + step(1.0, uv.y);
	limited *= 0.82;
	vec3 minimum_edge_light = vec3(0.002, 0.0022, 0.002) * vignette;
	limited = max(limited * (1.0 - vignette * vignette_strength), minimum_edge_light);
	limited *= 1.0 - clamp(outside_lens, 0.0, 1.0);
	COLOR = vec4(limited, 1.0);
}
