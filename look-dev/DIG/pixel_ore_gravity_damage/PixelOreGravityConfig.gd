class_name PixelOreGravityConfig
extends Resource

@export_group("Grid")
@export var grid_size := Vector2i(32, 32)
@export_range(1, 16, 1) var pixel_scale := 5
@export_range(0.0, 0.5, 0.01) var ellipse_edge_noise := 0.12

@export_group("Material")
@export_range(0.1, 8.0, 0.1) var stone_strength := 1.0

@export_group("Brush")
@export_range(1, 12, 1) var brush_radius := 3
@export_range(0.1, 8.0, 0.1) var brush_damage := 1.0
@export_range(0.1, 4.0, 0.1) var brush_falloff := 1.0
@export_range(0.0, 1.0, 0.01) var brush_noise_strength := 0.2

@export_group("Gravity")
@export_range(0, 32, 1) var gravity_steps_per_hit := 8
@export_range(0, 64, 1) var min_loose_component_size := 4
@export_range(1, 512, 1) var max_falling_component_size := 80
@export var enable_gravity := true

@export_group("Colors")
@export var body_color := Color(0.35, 0.36, 0.35, 1.0)
@export var damaged_color := Color(0.18, 0.17, 0.16, 1.0)
@export var edge_color := Color(0.65, 0.67, 0.63, 1.0)
@export var loose_color := Color(0.24, 0.22, 0.20, 1.0)
@export var empty_color := Color(0.0, 0.0, 0.0, 0.0)
@export var click_marker_color := Color(1.0, 0.18, 0.08, 1.0)


func sanitize() -> void:
	grid_size.x = clampi(grid_size.x, 4, 256)
	grid_size.y = clampi(grid_size.y, 4, 256)
	min_loose_component_size = clampi(min_loose_component_size, 0, max_falling_component_size)
	max_falling_component_size = maxi(max_falling_component_size, min_loose_component_size)
