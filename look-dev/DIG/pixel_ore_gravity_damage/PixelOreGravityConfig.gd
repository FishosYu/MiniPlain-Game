class_name PixelOreGravityConfig
extends Resource

@export_group("Grid")
@export var grid_size := Vector2i(32, 32)
@export_range(1, 16, 1) var pixel_scale := 5
@export_range(0.0, 0.5, 0.01) var ellipse_edge_noise := 0.12

@export_group("Material")
@export_range(0.1, 8.0, 0.1) var stone_strength := 1.0

@export_group("Impact")
@export_range(1, 12, 1) var impact_radius := 4
@export_range(0.1, 8.0, 0.1) var impact_power := 1.2
@export_range(0.1, 4.0, 0.1) var impact_falloff := 1.25
@export_range(0.0, 1.0, 0.01) var impact_noise_strength := 0.18
@export_range(0.1, 4.0, 0.1) var fracture_threshold := 1.0

@export_group("Anchor")
@export var anchor_offset := Vector2(0.0, 0.12)
@export_range(0.5, 8.0, 0.5) var anchor_radius := 3.0
@export var show_anchors := true

@export_group("Gravity")
@export_range(0, 32, 1) var gravity_steps_per_hit := 8
@export_range(0, 64, 1) var min_loose_component_size := 4
@export_range(1, 512, 1) var max_falling_component_size := 80
@export var enable_gravity := true

@export_group("Fragments")
@export_range(1, 128, 1) var fragment_min_pixels := 2
@export_range(0.0, 16.0, 0.5) var fragment_collision_padding := 2.0
@export_range(0.0, 1200.0, 10.0) var fragment_linear_impulse := 260.0
@export_range(0.0, 500.0, 10.0) var fragment_torque_impulse := 80.0

@export_group("Colors")
@export var body_color := Color(0.35, 0.36, 0.35, 1.0)
@export var damaged_color := Color(0.18, 0.17, 0.16, 1.0)
@export var edge_color := Color(0.65, 0.67, 0.63, 1.0)
@export var loose_color := Color(0.24, 0.22, 0.20, 1.0)
@export var empty_color := Color(0.0, 0.0, 0.0, 0.0)
@export var click_marker_color := Color(1.0, 0.18, 0.08, 1.0)
@export var anchor_color := Color(0.12, 0.95, 0.36, 1.0)
@export var unsupported_color := Color(1.0, 0.52, 0.12, 1.0)


func sanitize() -> void:
	grid_size.x = clampi(grid_size.x, 4, 256)
	grid_size.y = clampi(grid_size.y, 4, 256)
	min_loose_component_size = clampi(min_loose_component_size, 0, max_falling_component_size)
	max_falling_component_size = maxi(max_falling_component_size, min_loose_component_size)
	fragment_min_pixels = maxi(fragment_min_pixels, 1)
