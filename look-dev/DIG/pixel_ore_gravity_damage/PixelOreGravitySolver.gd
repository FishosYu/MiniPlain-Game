class_name PixelOreGravitySolver
extends RefCounted

const GridScript := preload("res://DIG/pixel_ore_gravity_damage/PixelOreGravityGrid.gd")

var _grid = GridScript.new()


func simulate_steps(grid: Dictionary, config, rng: RandomNumberGenerator) -> Dictionary:
	config.sanitize()

	var moved_total: int = 0
	var steps_run: int = 0
	for _step in int(config.gravity_steps_per_hit):
		var moved: int = simulate_step(grid, rng)
		steps_run += 1
		moved_total += moved
		if moved <= 0:
			break

	grid["last_moved_count"] = moved_total
	return {
		"steps_run": steps_run,
		"moved_count": moved_total,
	}


func simulate_step(grid: Dictionary, rng: RandomNumberGenerator) -> int:
	var size: Vector2i = grid.get("size", Vector2i.ZERO)
	var moved_count: int = 0

	for y in range(size.y - 2, -1, -1):
		for x in size.x:
			var cell := _grid.get_cell(grid, x, y)
			if int(cell.get("material_type", GridScript.MATERIAL_EMPTY)) == GridScript.MATERIAL_EMPTY:
				continue
			if not bool(cell.get("falling", false)):
				continue

			var target := _find_fall_target(grid, Vector2i(x, y), rng)
			if target == Vector2i(x, y):
				continue

			_grid.swap_cells(grid, Vector2i(x, y), target)
			moved_count += 1

	grid["last_moved_count"] = moved_count
	return moved_count


func _find_fall_target(grid: Dictionary, point: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	if _grid.is_empty(grid, point.x, point.y + 1):
		return point + Vector2i(0, 1)

	var prefer_left: bool = rng.randf() < 0.5
	var first_x: int = point.x - 1 if prefer_left else point.x + 1
	var second_x: int = point.x + 1 if prefer_left else point.x - 1

	if _grid.is_empty(grid, first_x, point.y + 1):
		return Vector2i(first_x, point.y + 1)
	if _grid.is_empty(grid, second_x, point.y + 1):
		return Vector2i(second_x, point.y + 1)

	return point
