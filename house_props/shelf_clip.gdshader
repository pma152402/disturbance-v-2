shader_type spatial;
render_mode cull_disabled;
uniform sampler2D wood_texture : source_color, filter_nearest;
uniform float split_height = 0.03;
uniform bool keep_upper = true;
varying float mesh_height;
void vertex() { mesh_height = VERTEX.y; }
void fragment() {
	if ((keep_upper && mesh_height < split_height) || (!keep_upper && mesh_height >= split_height)) { discard; }
	ALBEDO = texture(wood_texture, UV).rgb;
	ROUGHNESS = 0.92;
}
