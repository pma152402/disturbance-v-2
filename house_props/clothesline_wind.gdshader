shader_type spatial;
render_mode cull_disabled;

uniform vec4 cloth_color : source_color = vec4(0.7, 0.65, 0.5, 1.0);
uniform float wind_strength : hint_range(0.0, 0.4) = 0.12;
uniform float wind_speed : hint_range(0.0, 4.0) = 1.1;
uniform float phase = 0.0;

void vertex() {
	float loose = smoothstep(0.0, 1.0, UV.y);
	float t = TIME * wind_speed + phase;
	VERTEX.z += loose * wind_strength * (sin(t + UV.x * 4.0 + UV.y * 2.0) + 0.3 * sin(t * 2.3 - UV.y * 9.0 + UV.x * 8.0));
	VERTEX.x += loose * wind_strength * 0.18 * sin(t * 0.8 + UV.y * 3.0);
}

void fragment() {
	float weave = sin(UV.x * 650.0) * sin(UV.y * 650.0) * 0.025;
	float hem = step(UV.y, 0.035) + step(0.965, UV.y) + step(UV.x, 0.025) + step(0.975, UV.x);
	ALBEDO = cloth_color.rgb * (1.0 + weave - hem * 0.09);
	ROUGHNESS = 0.96;
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
}
