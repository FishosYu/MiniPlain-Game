class_name PixelOreBrushDamageSolver
extends RefCounted

const GridScript := preload("res://DIG/pixel_ore_gravity_damage/PixelOreGravityGrid.gd")

var _grid = GridScript.new()


func apply_brush_damage(grid: Dictionary, center_pixel: Vector2i, config, rng: RandomNumberGenerator) -> Dictionary:
	config.sanitize()

	var radius: int = int(config.brush_radius)
	var damaged_count: int = 0
	var removed_count: int = 0

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
			var damage_amount: float = float(config.brush_damage) * pow(t, float(config.brush_falloff))
			damage_amount *= rng.randf_range(1.0 - float(config.brush_noise_strength), 1.0 + float(config.brush_noise_strength))

			cell["strength"] = float(cell.get("strength", 0.0)) - damage_amount
			damaged_count += 1

			if float(cell["strength"]) <= 0.0:
				cell["material_type"] = GridScript.MATERIAL_EMPTY
				cell["strength"] = 0.0
				cell["max_strength"] = 0.0
				cell["falling"] = false
				cell["component_id"] = -1
				cell["component_role"] = "empty"
				removed_count += 1
			else:
				cell["component_role"] = "damaged"

			_grid.set_cell(grid, x, y, cell)

	return {
		"center_pixel": center_pixel,
		"damaged_count": damaged_count,
		"removed_count": removed_count,
	}
