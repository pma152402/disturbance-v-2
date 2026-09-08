shader_type canvas_item;

// Acabado de cámara aplicado sólo al rectángulo del vídeo archivado.
uniform float pixel_size : hint_range(1.0, 8.0, 1.0) = 2.0;
uniform float color_levels : hint_range(5.0, 64.0, 1.0) = 24.0;
uniform float chromatic_aberration : hint_range(0.0, 4.0, 0.1) = 0.5;
uniform float scanline_strength : hint_range(0.0, 0.4, 0.01) = 0.06;

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 block = TEXTURE_PIXEL_SIZE * pixel_size;
	vec2 uv = floor(UV / block) * block + block * 0.5;
	vec2 offset = vec2(TEXTURE_PIXEL_SIZE.x * chromatic_aberration, 0.0);
	vec3 clean = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
	vec3 split;
	split.r = texture(TEXTURE, clamp(uv + offset, vec2(0.0), vec2(1.0))).r;
	split.g = clean.g;
	split.b = texture(TEXTURE, clamp(uv - offset, vec2(0.0), vec2(1.0))).b;
	vec3 source = mix(clean, split, 0.32);
	source *= 0.965 + hash21(vec2(floor(TIME * 24.0), 4.0)) * 0.055;
	float luminance = dot(source, vec3(0.299, 0.587, 0.114));
	source = mix(source, vec3(luminance), 0.18) * vec3(0.94, 1.0, 0.96);
	vec3 limited = floor(clamp(source, 0.0, 1.0) * color_levels) / color_levels;
	limited *= 1.0 - scanline_strength * (0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159));
	vec2 centered = UV - vec2(0.5);
	centered.x *= 1.65;
	limited *= 1.0 - smoothstep(0.28, 0.82, length(centered)) * 0.38;
	COLOR = vec4(limited, texture(TEXTURE, UV).a);
}
