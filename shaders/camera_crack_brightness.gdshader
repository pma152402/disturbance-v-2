shader_type canvas_item;

uniform float crack_brightness : hint_range(1.0, 2.5, 0.05) = 1.45;
uniform float shadow_lift : hint_range(0.0, 0.35, 0.01) = 0.12;


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// Aclara exclusivamente el cristal roto. El filtro global se aplica después.
	vec3 brightened = source.rgb * crack_brightness + vec3(shadow_lift) * source.a;
	COLOR = vec4(clamp(brightened, vec3(0.0), vec3(1.0)), source.a) * COLOR;
}
