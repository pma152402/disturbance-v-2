shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 upper_white : source_color = vec3(0.96, 0.955, 0.94);
uniform vec3 lower_pastel_blue : source_color = vec3(0.89, 0.885, 0.86);
uniform vec3 lower_stripe_blue : source_color = vec3(0.80, 0.795, 0.77);
uniform vec3 border_blue : source_color = vec3(0.85, 0.84, 0.81);
uniform float stripe_width = 0.32;
uniform float border_width = 0.075;
uniform float ground_band_top = 1.38;
uniform float upper_floor_start = 4.1;
uniform float upper_band_top = 5.48;

varying float world_height;
varying float stripe_coordinate;


void vertex() {
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	world_height = world_position.y;
	stripe_coordinate = abs(world_normal.z) > abs(world_normal.x) ? world_position.x : world_position.z;
}


void fragment() {
	bool ground_blue = world_height < ground_band_top;
	bool upper_blue = world_height >= upper_floor_start && world_height < upper_band_top;
	bool ground_border = world_height >= ground_band_top - border_width && world_height < ground_band_top + border_width;
	bool upper_border = world_height >= upper_band_top - border_width && world_height < upper_band_top + border_width;
	if (ground_border || upper_border) {
		ALBEDO = border_blue;
	} else {
		bool striped_section = ground_blue || upper_blue;
		float stripe = mod(floor((stripe_coordinate + 100.0) / stripe_width), 2.0);
		vec3 striped_color = mix(lower_pastel_blue, lower_stripe_blue, stripe);
		ALBEDO = striped_section ? striped_color : upper_white;
	}
	ROUGHNESS = 0.92;
}
