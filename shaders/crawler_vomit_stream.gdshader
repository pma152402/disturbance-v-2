shader_type spatial;
render_mode cull_disabled;

void fragment() {
	float flow = UV.y - TIME * 14.5;
	float streak = sin(UV.x * 50.2655 + sin(flow * 0.7) * 0.5);
	float fine = sin(UV.x * 94.2478 + flow * 1.3) * 0.5 + 0.5;
	ALBEDO = mix(vec3(0.12, 0.29, 0.012), vec3(0.32, 0.60, 0.025), 0.62 + streak * 0.19 + fine * 0.12);
	ROUGHNESS = 0.43;
	SPECULAR = 0.4;
}
