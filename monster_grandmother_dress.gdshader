shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 cloth_red : source_color = vec3(0.34, 0.055, 0.045);
uniform vec3 faded_red : source_color = vec3(0.49, 0.12, 0.085);
uniform vec3 flower_blue : source_color = vec3(0.34, 0.49, 0.52);
uniform vec3 flower_cream : source_color = vec3(0.69, 0.62, 0.43);

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 cloth_uv = UV * vec2(10.0, 15.0);
	vec2 cell = floor(cloth_uv);
	vec2 local_uv = fract(cloth_uv) - vec2(0.5);
	float random_value = hash21(cell);
	vec3 base = mix(cloth_red, faded_red, 0.22 + 0.18 * sin(UV.y * 26.0));
	float flower = 1.0 - smoothstep(0.13, 0.24, length(local_uv));
	float petal_a = 1.0 - smoothstep(0.06, 0.13, length(local_uv - vec2(0.13, 0.0)));
	float petal_b = 1.0 - smoothstep(0.06, 0.13, length(local_uv + vec2(0.13, 0.0)));
	float petal_c = 1.0 - smoothstep(0.06, 0.13, length(local_uv - vec2(0.0, 0.13)));
	float petal_d = 1.0 - smoothstep(0.06, 0.13, length(local_uv + vec2(0.0, 0.13)));
	float floral_cluster = max(flower, max(max(petal_a, petal_b), max(petal_c, petal_d)));
	floral_cluster *= step(0.48, random_value);
	vec3 flower_color = mix(flower_cream, flower_blue, step(0.72, random_value));
	ALBEDO = mix(base, flower_color, floral_cluster * 0.82);
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
}
