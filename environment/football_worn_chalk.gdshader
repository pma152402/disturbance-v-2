shader_type spatial;
render_mode cull_disabled;
uniform vec4 chalk_color : source_color = vec4(0.70, 0.66, 0.51, 1.0);
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p = world_position.xz;
	float broad = noise(p*1.25 + vec2(14.0, 8.0));
	float grain = noise(p*85.0);
	if (broad < 0.27 || grain < 0.16) { discard; }
	ALBEDO = chalk_color.rgb * mix(0.60, 1.0, smoothstep(0.27,0.60,broad)) * mix(0.85,1.0,grain);
	ROUGHNESS = 1.0;
}
