class_name PixelOreDamageConfig
extends Resource

@export_group("Base Grid")
@export var grid_size := Vector2i(32, 32)
@export_range(0.0, 1.0, 0.01) var base_alpha_threshold := 0.1

@export_group("Damage Field")
@export_range(0.0, 1.0, 0.01) var noise_strength := 0.28
@export_range(0.0, 1.0, 0.01) var edge_weakness := 0.16
@export_range(0.0, 0.25, 0.01) var damaged_state_margin := 0.08

@export_group("Weak Bands")
@export_range(0, 8, 1) var weak_band_count_min := 2
@export_range(0, 8, 1) var weak_band_count_max := 4
@export_range(0.5, 8.0, 0.1) var weak_band_width_min := 1.4
@export_range(0.5, 8.0, 0.1) var weak_band_width_max := 3.2
@export_range(0.0, 1.0, 0.01) var weak_band_strength_min := 0.20
@export_range(0.0, 1.0, 0.01) var weak_band_strength_max := 0.44

@export_group("Weak Cores")
@export_range(0, 5, 1) var weak_core_count_min := 1
@export_range(0, 5, 1) var weak_core_count_max := 2
@export_range(1.0, 16.0, 0.5) var weak_core_radius_min := 4.0
@export_range(1.0, 16.0, 0.5) var weak_core_radius_max := 8.0
@export_range(0.0, 1.0, 0.01) var weak_core_strength := 0.24

@export_group("Connectivity")
@export_range(0, 64, 1) var loose_piece_min_size := 4

@export_group("Colors")
@export var body_color := Color(0.33, 0.36, 0.38, 1.0)
@export var damaged_color := Color(0.15, 0.14, 0.13, 1.0)
@export var edge_color := Color(0.64, 0.67, 0.66, 1.0)
@export var empty_color := Color(0.0, 0.0, 0.0, 0.0)
@export var damage_field_low_color := Color(0.06, 0.06, 0.07, 1.0)
@export var damage_field_high_color := Color(0.9, 0.92, 0.86, 1.0)


func sanitize() -> void:
	grid_size.x = clampi(grid_size.x, 2, 256)
	grid_size.y = clampi(grid_size.y, 2, 256)
	weak_band_count_max = maxi(weak_band_count_min, weak_band_count_max)
	weak_band_width_max = maxf(weak_band_width_min, weak_band_width_max)
	weak_band_strength_max = maxf(weak_band_strength_min, weak_band_strength_max)
	weak_core_count_max = maxi(weak_core_count_min, weak_core_count_max)
	weak_core_radius_max = maxf(weak_core_radius_min, weak_core_radius_max)
