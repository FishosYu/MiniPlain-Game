shader_type spatial;

render_mode world_vertex_coords;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D normal_texture : filter_nearest, repeat_disable;
uniform sampler2D material_texture : filter_nearest, repeat_disable;

uniform bool use_normal_map = true;
uniform bool use_material_map = false;

uniform bool flip_projection_y = false;
uniform bool invert_normal_y = false;

uniform vec2 projection_scale = vec2(1.0);
uniform vec2 projection_offset = vec2(0.0);

uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float metallic_multiplier : hint_range(0.0, 1.0) = 1.0;
uniform float roughness_multiplier : hint_range(0.0, 1.0) = 1.0;
uniform float default_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float default_roughness : hint_range(0.0, 1.0) = 0.8;
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform float emission_strength : hint_range(0.0, 2.0) = 0.0;

uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 hit_flash_color : source_color = vec3(1.0);

uniform int debug_view : hint_enum("Final,Projection UV,Albedo,Normal,Metallic,Roughness,AO") = 0;


vec2 get_projection_uv(vec2 screen_uv) {
	vec2 result = screen_uv;

	if (flip_projection_y) {
		result.y = 1.0 - result.y;
	}

	return result * projection_scale + projection_offset;
}


void vertex() {
	vec3 camera_right = normalize(MAIN_CAM_INV_VIEW_MATRIX[0].xyz);
	vec3 camera_up = normalize(MAIN_CAM_INV_VIEW_MATRIX[1].xyz);
	vec3 camera_facing_normal = normalize(MAIN_CAM_INV_VIEW_MATRIX[2].xyz);

	NORMAL = camera_facing_normal;
	TANGENT = camera_right;
	BINORMAL = camera_up;
}


void fragment() {
	vec2 projection_uv = get_projection_uv(SCREEN_UV);
	vec4 albedo_sample = texture(albedo_texture, projection_uv);
	vec4 material_sample = vec4(default_metallic, default_roughness, 1.0, 1.0);

	if (use_material_map) {
		material_sample = texture(material_texture, projection_uv);
	}

	ALBEDO = mix(albedo_sample.rgb, hit_flash_color, hit_flash);
	METALLIC = clamp(material_sample.r * metallic_multiplier, 0.0, 1.0);
	ROUGHNESS = clamp(material_sample.g * roughness_multiplier, 0.0, 1.0);
	AO = mix(1.0, material_sample.b, ao_strength);
	EMISSION = albedo_sample.rgb * emission_strength;

	vec3 mapped_normal = texture(normal_texture, projection_uv).rgb;
	if (invert_normal_y) {
		mapped_normal.g = 1.0 - mapped_normal.g;
	}
	if (use_normal_map) {
		NORMAL_MAP = mapped_normal;
		NORMAL_MAP_DEPTH = normal_strength;
	}

	if (debug_view == 1) {
		ALBEDO = vec3(projection_uv, 0.0);
	} else if (debug_view == 2) {
		ALBEDO = albedo_sample.rgb;
	} else if (debug_view == 3) {
		ALBEDO = mapped_normal;
	} else if (debug_view == 4) {
		ALBEDO = vec3(material_sample.r);
	} else if (debug_view == 5) {
		ALBEDO = vec3(material_sample.g);
	} else if (debug_view == 6) {
		ALBEDO = vec3(material_sample.b);
	}

	if (debug_view != 0) {
		METALLIC = 0.0;
		ROUGHNESS = 1.0;
		AO = 1.0;
		EMISSION = vec3(0.0);
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
		NORMAL_MAP_DEPTH = 0.0;
	}
}
