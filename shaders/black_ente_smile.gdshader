shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float dissolution : hint_range(0.0, 1.0) = 0.0;
varying vec3 local_position;
void vertex() {
	float jaw_open = smoothstep(0.15, 1.0, progress);
	VERTEX.y -= UV.y * 0.85 * jaw_open * (1.0 - pow(abs(UV.x * 2.0 - 1.0), 1.7));
	local_position = VERTEX;
}
void fragment() {
	float spread = abs(UV.x * 2.0 - 1.0);
	float opening = abs(UV.y * 2.0 - 1.0);
	if (progress < 0.001 || spread > progress || opening > mix(0.12, 1.0, progress)) { discard; }
	float grain = fract(sin(dot(floor(local_position * 95.0), vec3(127.1, 311.7, 74.7))) * 43758.5453);
	if (dissolution > 0.0 && grain < dissolution) { discard; }
	// Uneven tooth divisions and a crooked dark slit through the grin.
	float seam = 0.5 + sin(UV.x * 21.0) * 0.055;
	float gap = step(abs(UV.y - seam), mix(0.055, 0.34, smoothstep(0.15, 1.0, progress)));
	float divisions = step(fract(UV.x * 19.0 + step(seam, UV.y) * 0.28), 0.10);
	ALBEDO = mix(vec3(0.45, 0.43, 0.38), vec3(0.003), max(gap, divisions));
}
