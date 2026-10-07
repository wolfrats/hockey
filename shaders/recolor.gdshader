shader_type canvas_item;

instance uniform vec4 original_0;
instance uniform vec4 original_1;
instance uniform vec4 original_2;
instance uniform vec4 original_3;
instance uniform vec4 original_4;
instance uniform vec4 original_5;
instance uniform vec4 replace_0;
instance uniform vec4 replace_1;
instance uniform vec4 replace_2;
instance uniform vec4 replace_3;
instance uniform vec4 replace_4;
instance uniform vec4 replace_5;

const float precision = 0.1;


vec4 swap_color(vec4 color){
	vec4 original_colors[6] = vec4[6] (original_0, original_1, original_2, original_3, original_4, original_5);
	vec4 replace_colors[6] = vec4[6] (replace_0, replace_1, replace_2, replace_3, replace_4, replace_5);
	for (int i = 0; i < 6; i ++) {
		if (distance(color, original_colors[i]) <= precision){
			return replace_colors[i];
		}
	}
	return color;
}

void fragment() {
	COLOR = swap_color(texture(TEXTURE, UV));
}
