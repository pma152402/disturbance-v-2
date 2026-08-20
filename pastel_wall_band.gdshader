shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 upper_white : source_color = vec3(0.94, 0.94, 0.94);
uniform vec3 lower_pastel_blue : source_color = vec3(0.14, 0.39, 0.64);
uniform vec3 border_blue : source_color = vec3(0.025, 0.12, 0.28);
uniform float border_width = 0.075;
uniform float ground_band_top = 1.38;
uniform float upper_floor_start = 4.1;
uniform float upper_band_top = 5.48;

varying float world_height;


void vertex() {
	world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}


void fragment() {
	bool ground_blue = world_height < ground_band_top;
	bool upper_blue = world_height >= upper_floor_start && world_height < upper_band_top;
	bool ground_border = world_height >= ground_band_top - border_width && world_height < ground_band_top + border_width;
	bool upper_border = world_height >= upper_band_top - border_width && world_height < upper_band_top + border_width;
	if (ground_border || upper_border) {
		ALBEDO = border_blue;
	} else {
		ALBEDO = (ground_blue || upper_blue) ? lower_pastel_blue : upper_white;
	}
	ROUGHNESS = 0.92;
}
