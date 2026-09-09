shader_type canvas_item;

uniform float crack_brightness : hint_range(1.0, 2.5, 0.05) = 1.45;
uniform float shadow_lift : hint_range(0.0, 0.35, 0.01) = 0.12;
uniform float alpha_boost : hint_range(1.0, 2.0, 0.05) = 1.0;
uniform float white_mix : hint_range(0.0, 1.0, 0.05) = 0.0;
uniform vec3 crack_tint : source_color = vec3(0.56, 0.90, 1.0);
uniform float tint_mix : hint_range(0.0, 1.0, 0.05) = 0.0;
uniform float edge_thickness : hint_range(0.0, 8.0, 0.5) = 0.0;
uniform float postfilter_readability : hint_range(0.0, 1.0, 0.05) = 0.0;


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// Dilatado cardinal: conserva el grosor con cinco lecturas totales. Las cuatro
	// diagonales anteriores casi duplicaban el coste del overlay a pantalla completa.
	vec2 px = TEXTURE_PIXEL_SIZE * edge_thickness;
	float dilated_alpha = source.a;
	dilated_alpha = max(dilated_alpha, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	dilated_alpha = max(dilated_alpha, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	dilated_alpha = max(dilated_alpha, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	dilated_alpha = max(dilated_alpha, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	// Aclara exclusivamente el cristal roto.
	vec3 brightened = source.rgb * crack_brightness + vec3(shadow_lift) * dilated_alpha;
	brightened = mix(brightened, vec3(1.0), white_mix);
	brightened = mix(brightened, crack_tint, tint_mix * dilated_alpha);
	// Magenta funciona como una marca técnica de corta vida. El postfiltro la
	// reconoce después de pixelar/distorsionar y la devuelve al cian de la grieta.
	// No se muestra en la imagen final ni puede confundirse con luces azuladas.
	vec3 tagged_color = mix(brightened, vec3(1.0, 0.0, 1.0), postfilter_readability * dilated_alpha);
	COLOR = vec4(
		clamp(tagged_color, vec3(0.0), vec3(1.0)),
		min(dilated_alpha * alpha_boost, 1.0)
	) * COLOR;
}
