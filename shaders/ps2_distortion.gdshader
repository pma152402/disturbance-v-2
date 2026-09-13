shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float fisheye_strength : hint_range(0.0, 0.03, 0.001) = 0.007;

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
	vec2 lens_direction = vec2(lens_center.x / screen_aspect, lens_center.y);
	uv += lens_direction * lens_radius * fisheye_strength;
	float horizontal_band = floor(uv.y * 105.0);
	float random_tear = step(0.965, hash21(vec2(frame * 0.17, horizontal_band)));
	uv.x += sin(uv.y * 18.0 + TIME * 1.7) * 0.00085;
	uv.x += random_tear * (hash21(vec2(horizontal_band, frame)) - 0.5) * 0.006;
	uv.x += mod(floor(FRAGCOORD.y), 2.0) * SCREEN_PIXEL_SIZE.x * sin(frame * 0.37) * 1.5;
	COLOR = texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0)));
}
