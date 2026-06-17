class_name CrackDamageConfig
extends Resource

enum CrackPatternMode {
	RANDOM_WALK,
	VORONOI,
}

@export_group("Base Mask")
@export_range(0.0, 1.0, 0.01) var base_alpha_threshold := 0.1

@export_group("Cracks")
@export var crack_pattern_mode := CrackPatternMode.RANDOM_WALK
@export_range(1, 8, 1) var main_crack_count_min := 2
@export_range(1, 8, 1) var main_crack_count_max := 4
@export_range(1.0, 64.0, 0.5) var main_crack_energy_min := 10.0
@export_range(1.0, 64.0, 0.5) var main_crack_energy_max := 22.0
@export_range(0.0, 90.0, 1.0) var direction_jitter_degrees := 18.0
@export_range(1, 4, 1) var crack_thickness := 1
@export var crack_color := Color(1.0, 0.88, 0.18, 1.0)

@export_group("Voronoi Cracks")
@export_range(2, 32, 1) var voronoi_site_count := 10
@export_range(0.1, 8.0, 0.1) var voronoi_edge_threshold := 1.2
@export_range(0.0, 1.0, 0.01) var voronoi_start_damage := 0.2

@export_group("Branches")
@export_range(0, 4, 1) var max_generation := 2
@export_range(0.0, 0.5, 0.01) var main_branch_chance := 0.08
@export_range(0.0, 0.5, 0.01) var child_branch_chance := 0.03
@export_range(4, 96, 1) var max_branch_count := 32

@export_group("Chips")
@export_range(0, 16, 1) var chip_count_min := 2
@export_range(0, 16, 1) var chip_count_max := 5
@export_range(1, 12, 1) var chip_radius_min := 1
@export_range(1, 12, 1) var chip_radius_max := 4
@export_range(0.0, 1.0, 0.01) var chip_edge_noise := 0.25
@export var damaged_pixels_transparent := true
@export var damaged_pixel_color := Color(0.025, 0.02, 0.018, 1.0)

@export_group("Damage Stages")
@export_range(0.0, 1.0, 0.01) var crack_start_damage := 0.2
@export_range(0.0, 1.0, 0.01) var branch_start_damage := 0.45
@export_range(0.0, 1.0, 0.01) var chip_start_damage := 0.6

@export_group("Normal Output")
@export var damaged_normal_transparent := true
@export var flat_normal_color := Color(0.5, 0.5, 1.0, 1.0)


func sanitize() -> void:
	main_crack_count_max = maxi(main_crack_count_min, main_crack_count_max)
	main_crack_energy_max = maxf(main_crack_energy_min, main_crack_energy_max)
	chip_count_max = maxi(chip_count_min, chip_count_max)
	chip_radius_max = maxi(chip_radius_min, chip_radius_max)
	branch_start_damage = maxf(branch_start_damage, crack_start_damage)
	chip_start_damage = maxf(chip_start_damage, branch_start_damage)
