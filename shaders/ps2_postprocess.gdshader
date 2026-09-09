shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
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
	vec2 uv = SCREEN_UV;
	float frame = floor(TIME * 24.0);
	vec2 lens_center = uv * 2.0 - 1.0;
	float screen_aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	lens_center.x *= screen_aspect;
	float lens_radius = dot(lens_center, lens_center);

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
