shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D reflection_texture : filter_linear, repeat_disable;
uniform mat4 reflection_projection;
uniform float strength : hint_range(0.0, 1.0) = 0.22;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Proyeccion guardada con la captura: no arrastrar el reflejo al mover la camara.
	vec4 projected = reflection_projection * vec4(world_position, 1.0);
	vec2 uv = projected.xy / max(projected.w, 0.0001) * vec2(0.5, -0.5) + 0.5;
	if (projected.w <= 0.0 || any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		discard;
	}
	vec4 reflected = texture(reflection_texture, uv);
	// La baja resolucion y el filtrado suavizan los detalles sin pases de blur.
	ALBEDO = reflected.rgb * vec3(0.80, 0.89, 0.94);
	ALPHA = reflected.a * strength;
}
