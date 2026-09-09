shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float fisheye_strength : hint_range(0.0, 0.03, 0.001) = 0.007;
uniform float pixel_size : hint_range(1.0, 24.0, 1.0) = 8.0;
uniform float color_levels : hint_range(5.0, 64.0, 1.0) = 24.0;
uniform float chromatic_aberration : hint_range(0.0, 9.0, 0.1) = 1.2;
uniform float scanline_strength : hint_range(0.0, 0.6, 0.01) = 0.09;
uniform float vignette_strength : hint_range(0.0, 0.98, 0.01) = 0.94;
uniform float vignette_inner : hint_range(0.0, 0.6, 0.01) = 0.07;
uniform float vignette_outer : hint_range(0.2, 1.2, 0.01) = 0.47;


float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float frame = floor(TIME * 24.0);
	float screen_aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 original_uv = SCREEN_UV;
	vec2 lens_center = original_uv * 2.0 - 1.0;
	lens_center.x *= screen_aspect;
	float lens_radius = dot(lens_center, lens_center);

	// Pixelate first, then distort that source coordinate. Keeping all texture()
	// reads directly in fragment() avoids black screen-texture reads on some GPUs.
	vec2 block = SCREEN_PIXEL_SIZE * pixel_size;
	vec2 uv = floor(original_uv / block) * block + block * 0.5;
	vec2 distorted_center = uv * 2.0 - 1.0;
	distorted_center.x *= screen_aspect;
	float distorted_radius = dot(distorted_center, distorted_center);
	vec2 lens_direction = vec2(distorted_center.x / screen_aspect, distorted_center.y);
	uv += lens_direction * distorted_radius * fisheye_strength;
	float horizontal_band = floor(uv.y * 105.0);
	float random_tear = step(0.965, hash21(vec2(frame * 0.17, horizontal_band)));
	uv.x += sin(uv.y * 18.0 + TIME * 1.7) * 0.00085;
	uv.x += random_tear * (hash21(vec2(horizontal_band, frame)) - 0.5) * 0.006;
	float sampled_row = floor(original_uv.y / SCREEN_PIXEL_SIZE.y);
	uv.x += mod(sampled_row, 2.0) * SCREEN_PIXEL_SIZE.x * sin(frame * 0.37) * 1.5;
	float head_switch = smoothstep(0.82, 0.99, uv.y);
	uv.x += head_switch * sin(uv.y * 170.0 + TIME * 13.0) * 0.0028;
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	vec2 rgb_offset = vec2(SCREEN_PIXEL_SIZE.x * chromatic_aberration, 0.0);
	vec3 center_sample = texture(screen_texture, uv).rgb;
	vec3 source = vec3(
		texture(screen_texture, clamp(uv + rgb_offset, vec2(0.0), vec2(1.0))).r,
		center_sample.g,
		texture(screen_texture, clamp(uv - rgb_offset, vec2(0.0), vec2(1.0))).b
	);
	source = mix(center_sample, source, 0.45);
	float edge_blur = smoothstep(0.18, 1.15, lens_radius) * 0.24;
	vec2 soft_uv = clamp(uv + vec2(block.x * 1.5, block.y), vec2(0.0), vec2(1.0));
	source = mix(source, texture(screen_texture, soft_uv).rgb, edge_blur);
	float flicker = 0.965 + hash21(vec2(frame, 4.0)) * 0.055;
	source *= flicker;
	float luminance = dot(source, vec3(0.299, 0.587, 0.114));
	source = mix(source, vec3(luminance), 0.24);
	source *= vec3(0.91, 1.0, 0.94);
	vec3 limited = floor(clamp(source, 0.0, 1.0) * color_levels) / color_levels;

	float scanline = 1.0 - scanline_strength * (0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159));
	limited *= scanline;
	float tracking_position = fract(TIME * 0.095);
	float tracking_line = 1.0 - smoothstep(0.0, 0.012, abs(uv.y - tracking_position));
	limited += tracking_line * vec3(0.07, 0.085, 0.075);

	vec2 centered = original_uv - vec2(0.5);
	centered.x *= screen_aspect;
	float vignette = smoothstep(vignette_inner, vignette_outer, length(centered));
	limited *= 0.82;
	vec3 minimum_edge_light = vec3(0.002, 0.0022, 0.002) * vignette;
	limited = max(limited * (1.0 - vignette * vignette_strength), minimum_edge_light);
	COLOR = vec4(limited, 1.0);
}
