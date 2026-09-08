shader_type spatial;
render_mode unshaded;

uniform sampler2D program_texture : source_color, filter_nearest, repeat_disable;
uniform vec2 sheet_size = vec2(1536.0, 1024.0);
uniform int frame_index = 0;
uniform bool powered_on = false;
uniform vec2 visual_shift_pixels = vec2(4.0, -2.0);
uniform float screen_aspect = 1.333333;
uniform float brightness = 1.15;
uniform float black_frame = 0.025;
uniform vec2 cell_crop = vec2(0.032, 0.042);


void fragment() {
	if (!powered_on) {
		// Negro absoluto: la pantalla apagada no aporta luminancia alguna.
		ALBEDO = vec3(0.0);
	} else {
		// Marco negro estable, aunque la lamina original tenga margenes blancos
		// o de cualquier otro color.
		bool outside = (
			UV.x < black_frame || UV.x > 1.0 - black_frame ||
			UV.y < black_frame || UV.y > 1.0 - black_frame
		);
		vec2 inner_uv = (UV - vec2(black_frame)) / (1.0 - 2.0 * black_frame);

		// Conserva la proporcion propia de cada fotograma y lo centra dentro
		// de la pantalla. Las zonas sobrantes se convierten en marco negro.
		float frame_aspect = sheet_size.x / sheet_size.y;
		vec2 fitted_uv = inner_uv;
		if (frame_aspect > screen_aspect) {
			float fitted_height = screen_aspect / frame_aspect;
			float top = (1.0 - fitted_height) * 0.5;
			outside = outside || inner_uv.y < top || inner_uv.y > 1.0 - top;
			fitted_uv.y = (inner_uv.y - top) / fitted_height;
		} else {
			float fitted_width = frame_aspect / screen_aspect;
			float left = (1.0 - fitted_width) * 0.5;
			outside = outside || inner_uv.x < left || inner_uv.x > 1.0 - left;
			fitted_uv.x = (inner_uv.x - left) / fitted_width;
		}

		if (outside) {
			ALBEDO = vec3(0.008);
		} else {
			// Recorta el margen/separador incluido en cada una de las nueve celdas.
			// Los valores cubren las cinco laminas, incluidas las de 1672x941.
			fitted_uv = mix(cell_crop, vec2(1.0) - cell_crop, fitted_uv);
			int column = frame_index % 3;
			int row = frame_index / 3;
			vec2 atlas_uv = (vec2(float(column), float(row)) + fitted_uv) / 3.0;
			// El muestreo se mueve al contrario que la imagen: +4 px visuales a la
			// derecha y -2 px visuales hacia arriba, independientemente del tamano.
			atlas_uv -= visual_shift_pixels / sheet_size;
			vec3 picture = texture(program_texture, atlas_uv).rgb;
			ALBEDO = picture * brightness;
		}
	}
}
