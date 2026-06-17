class_name PixelOreImpactSolver
extends RefCounted

const GridScript := preload("res://DIG/pixel_ore_gravity_damage/PixelOreGravityGrid.gd")

var _grid = GridScript.new()


func apply_impact(grid: Dictionary, center_pixel: Vector2i, config, rng: RandomNumberGenerator) -> Dictionary:
	config.sanitize()

	var radius: int = int(config.impact_radius)
	var impacted_count: int = 0
	var fractured_count: int = 0

	for y in range(center_pixel.y - radius, center_pixel.y + radius + 1):
		for x in range(center_pixel.x - radius, center_pixel.x + radius + 1):
			if not _grid.is_inside(grid, x, y):
				continue

			var offset := Vector2(x - center_pixel.x, y - center_pixel.y)
			var distance: float = offset.length()
			if distance > float(radius):
				continue

			var cell := _grid.get_cell(grid, x, y)
			if int(cell.get("material_type", GridScript.MATERIAL_EMPTY)) == GridScript.MATERIAL_EMPTY:
				continue

			var t: float = 1.0 - distance / maxf(float(radius), 0.001)
			var impulse: float = float(config.impact_power) * pow(t, float(config.impact_falloff))
			impulse *= rng.randf_range(1.0 - float(config.impact_noise_strength), 1.0 + float(config.impact_noise_strength))
			cell["stress"] = float(cell.get("stress", 0.0)) + impulse
			impacted_count += 1

			var break_limit: float = float(cell.get("max_strength", 1.0)) * float(config.fracture_threshold)
			if float(cell["stress"]) >= break_limit:
				cell["material_type"] = GridScript.MATERIAL_EMPTY
				cell["strength"] = 0.0
				cell["stress"] = 0.0
				cell["falling"] = false
				cell["component_id"] = -1
				cell["component_role"] = "fractured"
				fractured_count += 1
			else:
				cell["component_role"] = "damaged"

			_grid.set_cell(grid, x, y, cell)

	grid["last_impact_center"] = center_pixel
	grid["last_impacted_count"] = impacted_count
	grid["last_fractured_count"] = fractured_count
	return {
		"center_pixel": center_pixel,
		"impacted_count": impacted_count,
		"fractured_count": fractured_count,
	}
