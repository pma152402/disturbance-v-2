shader_type spatial;
render_mode cull_disabled;
uniform vec4 water_tint : source_color = vec4(0.17, 0.18, 0.15, 1.0);
varying vec2 water_position;
void vertex() { water_position = VERTEX.xz; }
void fragment() {
	float ripple = sin(water_position.x*24.0 + water_position.y*9.0) * sin(water_position.y*19.0);
	float sky = pow(1.0 - clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
	ALBEDO = mix(water_tint.rgb,vec3(0.35,0.39,0.40),0.25 + sky*0.5) + ripple*0.008;
	ROUGHNESS = 0.18;
	METALLIC = 0.0;
	SPECULAR = 0.8;
}
