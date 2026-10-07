shader_type canvas_item;

instance uniform vec4 original_0;
instance uniform vec4 original_1;
instance uniform vec4 original_2;
instance uniform vec4 original_3;
instance uniform vec4 original_4;
instance uniform vec4 original_5;
instance uniform vec4 original_6;

instance uniform vec4 replace_0;
instance uniform vec4 replace_1;
instance uniform vec4 replace_2;
instance uniform vec4 replace_3;
instance uniform vec4 replace_4;
instance uniform vec4 replace_5;
instance uniform vec4 replace_6;


const float precision = 0.01;

vec4 swap_color(vec4 color){
	if (color.a < 0.01) {
		return color;
	}
	vec4 original_colors[7] = vec4[7] (original_0, original_1, original_2, original_3, original_4, original_5, original_6);
	vec4 replace_colors[7] = vec4[7] (replace_0, replace_1, replace_2, replace_3, replace_4, replace_5, replace_6);
	for (int i = 0; i < 7; i ++) {
		if (distance(color, original_colors[i]) <= precision) {
			return replace_colors[i];
		}
	}
	return color;
}

void fragment() {
	COLOR = swap_color(texture(TEXTURE, UV));
}
