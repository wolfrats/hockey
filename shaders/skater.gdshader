
shader_type canvas_item;

varying vec4 custom_modulate; 
void vertex() { 
	custom_modulate = COLOR; 
}

uniform vec4 helmet: source_color;
uniform vec4 shirt: source_color;
uniform vec4 pants: source_color;
uniform vec4 skin;
uniform vec4 nose;
uniform vec4 replace_helmet: source_color;
uniform vec4 replace_shirt: source_color;
uniform vec4 replace_pants: source_color;
uniform vec4 replace_sleeve: source_color;
uniform vec4 replace_skin;
uniform vec4 replace_nose;
uniform sampler2D logo: filter_nearest, repeat_disable, hint_default_transparent;
uniform bool draw_logo = false;
uniform sampler2D number_tex: filter_nearest, repeat_disable, hint_default_transparent;
uniform bool draw_number = false;
uniform vec2 logo_pos = vec2(0.0, 0.0);
uniform float logo_offset_x = 0.0;

const vec4 sleeves = vec4(float(0x7C) / 255.0, float(0xB0) / 255.0, float(0xF8) / 255.0, 1);
const vec4 neckline = vec4(float(0x49) / 255.0, float(0xB0) / 255.0, float(0xF8) / 255.0, 1);

const float precision = 0.05;
const float logo_size = 32.0;
const float frame_width = 192.0;


vec4 swap_color(vec4 color){
	const int count = 7;
	vec4 original_colors[count] = vec4[count] (helmet, shirt, pants, skin, nose, sleeves, neckline);
	vec4 replace_colors[count] = vec4[count] (replace_helmet, replace_shirt, replace_shirt, replace_skin, replace_nose, replace_sleeve, replace_sleeve);
	for (int i = 0; i < count; i ++) {
		if (distance(color, original_colors[i]) <= precision) {
			return replace_colors[i];
		}
	}
	return color;
}



void fragment() {
	// Called for every pixel the material is visible on.
	vec4 orig = texture(TEXTURE, UV);
	vec4 me = swap_color(orig);
	if (distance(orig, shirt) <= precision) {
		//if (distance(texture(TEXTURE, UV + TEXTURE_PIXEL_SIZE * vec2(0, 6)), skin) <= precision) me = replace_sleeve;
		//if (distance(texture(TEXTURE, UV + TEXTURE_PIXEL_SIZE * vec2(0, -6)), skin) <= precision) me = replace_sleeve;
		//if (distance(texture(TEXTURE, UV + TEXTURE_PIXEL_SIZE * vec2(6,0)), skin) <= precision) me = replace_sleeve;
		//if (distance(texture(TEXTURE, UV + TEXTURE_PIXEL_SIZE * vec2(-6,0)), skin) <= precision) me = replace_sleeve;
		if (UV.y > 0.64) me = replace_pants;
		//if (UV.y < 0.54) me = replace_sleeve;
		if (draw_logo || draw_number) {
			vec2 tex_px = UV / TEXTURE_PIXEL_SIZE;
			vec2 frame_px = vec2(mod(tex_px.x, frame_width), tex_px.y);
			vec2 rel = frame_px - logo_pos;
			float lx = rel.x + logo_offset_x;
			float ly = rel.y;
			if (rel.x >= 0.0 && lx >= 0.0 && lx < logo_size && ly >= 0.0 && ly < logo_size) {
				vec2 overlay_uv = vec2(lx, ly) / logo_size;
				vec4 overlay_color = draw_logo ? texture(logo, overlay_uv) : texture(number_tex, overlay_uv);
				me.rgb = mix(me.rgb, overlay_color.rgb, overlay_color.a);
			}
		}
	}
	float neighbors = max(me.a, max(max(max(
		texture(TEXTURE, UV + TEXTURE_PIXEL_SIZE * vec2(0,1)).a,
		texture(TEXTURE, UV + TEXTURE_PIXEL_SIZE * vec2(0,-1)).a
	),
	texture(TEXTURE, UV + TEXTURE_PIXEL_SIZE * vec2(1,0)).a),
	texture(TEXTURE, UV + TEXTURE_PIXEL_SIZE *  vec2(-1,0)).a));
	COLOR = (me*me.a + vec4(0, 0, 0, neighbors)) * custom_modulate;
}
