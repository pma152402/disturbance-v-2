shader_type spatial;
render_mode cull_disabled;

uniform float dissolution : hint_range(0.0, 1.0) = 0.0;
uniform float eye_glow : hint_range(0.0, 1.0) = 0.0;
uniform float eye_brightness : hint_range(0.0, 1.0) = 1.0;
uniform float pupil_dilation : hint_range(0.0, 1.0) = 0.0;
varying vec3 local_position;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	// Opaque fragmented fade: disappearing fragments stop casting shadows too.
	float grain = hash(floor(local_position * 95.0));
	if (dissolution > 0.0 && grain < dissolution) {
		discard;
	}
	// Paint the pupil on the curved eye itself so it cannot float over the rim.
	float pupil = step(length(local_position.xy), 0.232 * pupil_dilation) * step(0.0, local_position.z) * step(0.001, pupil_dilation);
	float white_eye = eye_glow * (1.0 - pupil);
	ALBEDO = mix(vec3(0.009, 0.011, 0.014), vec3(eye_brightness), white_eye);
	EMISSION = vec3(white_eye * eye_brightness * 1.2);
	ROUGHNESS = 0.98;
	SPECULAR = 0.05;
}
