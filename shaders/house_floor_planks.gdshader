shader_type spatial;
render_mode cull_back;

#include "res://shaders/house_kitchen_marble.gdshaderinc"

uniform sampler2D wood_grain : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float plank_width = 0.19;
uniform float joint_width = 0.0025;
uniform bool kitchen_marble = false;
// House-local bounds: west doorway centre to east slab edge, north wall to
// the centre of DetachedWall13Extension. Upstairs keeps its timber finish.
uniform vec4 kitchen_bounds = vec4(2.914, -6.135, 11.212, 2.025);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	if (kitchen_marble && UV.x >= kitchen_bounds.x && UV.y >= kitchen_bounds.y && UV.x <= kitchen_bounds.z && UV.y <= kitchen_bounds.w) {
		vec3 stone;
		float stone_roughness;
		kitchen_stone(UV, stone, stone_roughness);
		ALBEDO = stone * COLOR.rgb;
		ROUGHNESS = stone_roughness;
		SPECULAR = 0.48;
	} else {
	// Medidas reales, ancladas a la casa, sin estirar la veta por habitacion.
	float row = floor(UV.y / plank_width);
	float board_length = 1.45 + hash21(vec2(row, 9.0)) * 0.75;
	float offset = hash21(vec2(row, 3.0)) * board_length;
	float column = floor((UV.x + offset) / board_length);
	vec2 cell = vec2(column, row);
	vec2 p = vec2(mod(UV.x + offset, board_length), mod(UV.y, plank_width));
	vec2 edge = min(p, vec2(board_length, plank_width) - p);
	float border = min(edge.x, edge.y);
	// Derivar las coordenadas continuas, no mod(): en una junta mod salta
	// un tablon entero y produciria lineas negras gruesas y moire a distancia.
	float aa = max(max(fwidth(UV.x), fwidth(UV.y)), 0.0003);
	float detail_fade = smoothstep(plank_width * 0.16, plank_width * 0.70, aa);
	float seam = 1.0 - smoothstep(joint_width * 0.5 - aa * 0.5, joint_width * 0.5 + aa * 0.5, border);
	seam = mix(seam, joint_width / plank_width + joint_width / board_length, detail_fade);
	float bevel = mix(smoothstep(0.001, 0.006, border), 1.0, detail_fade);
	float seed = hash21(cell);
	vec2 grain_uv = vec2(p.x * 0.62, p.y * 2.8) + vec2(seed * 3.7, hash21(cell + 8.0));
	vec3 wood = texture(wood_grain, grain_uv).rgb;
	vec3 tint = mix(vec3(0.91, 0.80, 0.69), vec3(1.15, 1.02, 0.87), seed);
	wood *= tint * mix(0.78, 1.13, hash21(cell + 31.0));
	wood *= mix(0.72, 1.0, bevel);
	// Dos puntas oscuras a cada extremo, pequenas y antialiasadas.
	vec2 nail_p = vec2(edge.x - 0.032, abs(p.y - plank_width * 0.5) - plank_width * 0.31);
	float nail_distance = length(nail_p);
	float nail = (1.0 - smoothstep(0.002, 0.0035 + aa * 0.5, nail_distance)) * (1.0 - smoothstep(0.003, 0.015, aa));
	ALBEDO = mix(mix(wood, vec3(0.055, 0.040, 0.030), nail * 0.8), vec3(0.027, 0.020, 0.014), seam);
	ALBEDO *= COLOR.rgb;
	ROUGHNESS = mix(0.78 + seed * 0.14, 0.96, seam);
	SPECULAR = 0.22;
	AO = mix(1.0, 0.64, seam);
	}
}
