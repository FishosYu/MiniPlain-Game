shader_type canvas_item;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D normal_texture : filter_nearest, repeat_disable;
uniform sampler2D crack_mask : filter_nearest, repeat_disable;
uniform sampler2D damage_mask : filter_nearest, repeat_disable;

uniform vec4 crack_color : source_color = vec4(0.08, 0.055, 0.045, 1.0);
uniform vec4 damaged_pixel_color : source_color = vec4(0.025, 0.02, 0.018, 1.0);
uniform vec4 flat_normal_color = vec4(0.5, 0.5, 1.0, 1.0);
uniform bool damaged_pixels_transparent = true;
uniform bool show_crack = true;
uniform bool show_damage = true;


void fragment() {
	vec4 albedo = texture(albedo_texture, UV);
	float crack = texture(crack_mask, UV).r;
	float damage = texture(damage_mask, UV).r;

	vec4 final_color = albedo;
	if (show_crack && crack > 0.5 && albedo.a > 0.0) {
		final_color = crack_color;
	}
	if (show_damage && damage > 0.5) {
		final_color = damaged_pixels_transparent ? vec4(0.0) : damaged_pixel_color;
	}
	COLOR = final_color;

	vec3 normal_color = texture(normal_texture, UV).rgb;
	if (show_damage && damage > 0.5) {
		normal_color = flat_normal_color.rgb;
	}
	NORMAL_MAP = normal_color;
}
