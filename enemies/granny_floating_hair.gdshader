shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform float drift_strength : hint_range(0.0, 0.15) = 0.052;
uniform float drift_speed : hint_range(0.1, 5.0) = 1.15;
uniform float unnatural_lift : hint_range(0.0, 0.12) = 0.035;

void vertex() {
	float loose = smoothstep(0.025, 1.0, UV.y);
	float tip = loose * loose;
	float seed = UV2.x * 6.2831853;
	float polarity = UV2.y * 2.0 - 1.0;
	float time = TIME * drift_speed;
	float slow_wave = sin(time + seed + UV.y * 3.7);
	float nervous_wave = sin(time * 2.73 - seed * 1.61 + UV.y * 8.5);
	VERTEX.x += loose * drift_strength * (slow_wave + nervous_wave * 0.24);
	VERTEX.z += loose * drift_strength * (cos(time * 0.83 + seed * 1.9 + UV.y * 4.4) * 0.82 + polarity * nervous_wave * 0.18);
	VERTEX.y += tip * (unnatural_lift + sin(time * 1.37 + seed + UV.y * 5.0) * drift_strength * 0.28);
}

void fragment() {
	float greasy_streak = 0.82 + 0.18 * sin(UV.y * 41.0 + UV2.x * 19.0);
	ALBEDO = COLOR.rgb * greasy_streak;
	ROUGHNESS = 0.72;
	SPECULAR = 0.34;
	RIM = 0.08;
	RIM_TINT = 0.72;
}
