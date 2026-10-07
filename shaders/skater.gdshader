
shader_type canvas_item;

varying vec4 custom_modulate; 
void vertex() { 
	custom_modulate = COLOR; 
}
uniform vec4 original_0: source_color;
uniform vec4 original_1: source_color;
uniform vec4 original_2: source_color;
instance uniform vec4 original_3;
instance uniform vec4 original_4;
uniform vec4 replace_0: source_color;
uniform vec4 replace_1: source_color;
uniform vec4 replace_2: source_color;
instance uniform vec4 replace_3;
instance uniform vec4 replace_4;

const float precision = 0.01;


vec4 swap_color(vec4 color){
	vec4 original_colors[5] = vec4[5] (original_0, original_1, original_2, original_3, original_4);
	vec4 replace_colors[5] = vec4[5] (replace_0, replace_1, replace_2, replace_3, replace_4);
	for (int i = 0; i < 5; i ++) {
		if (distance(color, original_colors[i]) <= precision){
			return replace_colors[i];
		}
	}
	return color;
}



void fragment() {
	// Called for every pixel the material is visible on.
	vec4 me = swap_color(texture(TEXTURE, UV));
	float neighbors = max(me.a, max(max(max(
		texture(TEXTURE, UV + TEXTURE_PIXEL_SIZE * vec2(0,1)).a,
		texture(TEXTURE, UV + TEXTURE_PIXEL_SIZE * vec2(0,-1)).a
	),
	texture(TEXTURE, UV + TEXTURE_PIXEL_SIZE * vec2(1,0)).a),
	texture(TEXTURE, UV + TEXTURE_PIXEL_SIZE *  vec2(-1,0)).a));
	COLOR = (me*me.a + vec4(0, 0, 0, neighbors)) * custom_modulate;
}
