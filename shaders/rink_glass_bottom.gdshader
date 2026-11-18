shader_type canvas_item;

uniform int puck_count = 0;
uniform vec2 puck_positions[8];
uniform float inner_radius = 4.0;
uniform float outer_radius = 9.0;

float is_bottom_wall(sampler2D Texture, vec2 tex_pos, vec2 tex_pixel_size) {
	vec2 uv = clamp(tex_pos * tex_pixel_size, vec2(0.0), vec2(1.0));
	vec4 c = texture(Texture, uv);
	return (c.a > 0.5 && c.r > 0.92) ? 1.0 : 0.0;
}

float sample_bottom_wall_smooth(sampler2D Texture, vec2 tex_pos, vec2 tex_pixel_size) {
	vec2 p = tex_pos - vec2(0.5);
	vec2 p0 = floor(p) + vec2(0.5);
	vec2 f = fract(p);
	float v00 = is_bottom_wall(Texture, p0, tex_pixel_size);
	float v10 = is_bottom_wall(Texture, p0 + vec2(1.0, 0.0), tex_pixel_size);
	float v01 = is_bottom_wall(Texture, p0 + vec2(0.0, 1.0), tex_pixel_size);
	float v11 = is_bottom_wall(Texture, p0 + vec2(1.0, 1.0), tex_pixel_size);
	return mix(mix(v00, v10, f.x), mix(v01, v11, f.x), f.y);
}

float get_puck_hidden_amount(sampler2D Texture, vec2 puck_pos, vec2 tex_pixel_size) {
	float hits = 0.0;
	hits += sample_bottom_wall_smooth(Texture, puck_pos, tex_pixel_size);
	hits += sample_bottom_wall_smooth(Texture, puck_pos + vec2(0.0, 1.8), tex_pixel_size);
	hits += sample_bottom_wall_smooth(Texture, puck_pos + vec2(0.0, -1.8), tex_pixel_size);
	hits += sample_bottom_wall_smooth(Texture, puck_pos + vec2(2.5, 0.0), tex_pixel_size);
	hits += sample_bottom_wall_smooth(Texture, puck_pos + vec2(-2.5, 0.0), tex_pixel_size);
	hits += sample_bottom_wall_smooth(Texture, puck_pos + vec2(2.0, 1.5), tex_pixel_size);
	hits += sample_bottom_wall_smooth(Texture, puck_pos + vec2(-2.0, 1.5), tex_pixel_size);
	return smoothstep(0.0, 1.5, hits);
}

void fragment() {
	if (COLOR.a > 0.0 && puck_count > 0) {
		vec2 tex_pos = UV / TEXTURE_PIXEL_SIZE;
		float combined_mask = 1.0;
		for (int i = 0; i < puck_count; i++) {
			if (i >= 8) {
				break;
			}
			vec2 p_pos = puck_positions[i];
			float hidden = get_puck_hidden_amount(TEXTURE, p_pos, TEXTURE_PIXEL_SIZE);
			if (hidden > 0.0) {
				float dist = distance(tex_pos, p_pos);
				float circle = smoothstep(inner_radius, outer_radius, dist);
				float mask = mix(1.0, circle, hidden);
				combined_mask = min(combined_mask, mask);
			}
		}
		COLOR.a *= combined_mask;
	}
}
