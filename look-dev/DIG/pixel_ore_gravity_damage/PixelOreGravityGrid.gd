class_name PixelOreGravityGrid
extends RefCounted

const MATERIAL_EMPTY := 0
const MATERIAL_STONE := 1


func create_ellipse(config, grid_seed: int) -> Dictionary:
	config.sanitize()

	var size: Vector2i = config.grid_size
	var cells: Array = []
	cells.resize(size.x * size.y)

	var center := (Vector2(size) - Vector2.ONE) * 0.5
	var radius := Vector2(float(size.x) * 0.43, float(size.y) * 0.38)
	var solid_count: int = 0

	for y in size.y:
		for x in size.x:
			var point := Vector2(x, y)
			var normalized := Vector2((point.x - center.x) / radius.x, (point.y - center.y) / radius.y)
			var distance_value: float = normalized.length()
			var edge_noise: float = (_hash_noise(grid_seed, x, y) - 0.5) * 2.0 * float(config.ellipse_edge_noise)
			var is_solid: bool = distance_value <= 1.0 + edge_noise
			if is_solid:
				solid_count += 1

			cells[_index(x, y, size.x)] = _make_cell(
				MATERIAL_STONE if is_solid else MATERIAL_EMPTY,
				float(config.stone_strength)
			)

	var anchor_points := _make_anchor_points(size, config)
	return {
		"size": size,
		"cells": cells,
		"seed": grid_seed,
		"solid_count": solid_count,
		"last_moved_count": 0,
		"anchor_points": anchor_points,
	}


func get_cell(grid: Dictionary, x: int, y: int) -> Dictionary:
	var size: Vector2i = grid.get("size", Vector2i.ZERO)
	if not is_inside(grid, x, y):
		return _make_cell(MATERIAL_EMPTY, 0.0)
	var cells: Array = grid.get("cells", [])
	return cells[_index(x, y, size.x)]


func set_cell(grid: Dictionary, x: int, y: int, cell: Dictionary) -> void:
	if not is_inside(grid, x, y):
		return
	var size: Vector2i = grid.get("size", Vector2i.ZERO)
	var cells: Array = grid.get("cells", [])
	cells[_index(x, y, size.x)] = cell
	grid["cells"] = cells


func is_inside(grid: Dictionary, x: int, y: int) -> bool:
	var size: Vector2i = grid.get("size", Vector2i.ZERO)
	return x >= 0 and y >= 0 and x < size.x and y < size.y


func is_empty(grid: Dictionary, x: int, y: int) -> bool:
	if not is_inside(grid, x, y):
		return true
	return int(get_cell(grid, x, y).get("material_type", MATERIAL_EMPTY)) == MATERIAL_EMPTY


func swap_cells(grid: Dictionary, from: Vector2i, to: Vector2i) -> void:
	if not is_inside(grid, from.x, from.y) or not is_inside(grid, to.x, to.y):
		return

	var size: Vector2i = grid.get("size", Vector2i.ZERO)
	var cells: Array = grid.get("cells", [])
	var from_index: int = _index(from.x, from.y, size.x)
	var to_index: int = _index(to.x, to.y, size.x)
	var from_cell: Dictionary = cells[from_index]
	cells[from_index] = cells[to_index]
	cells[to_index] = from_cell
	grid["cells"] = cells


func clear_cell(grid: Dictionary, x: int, y: int) -> void:
	set_cell(grid, x, y, _make_cell(MATERIAL_EMPTY, 0.0))


func _make_cell(material_type: int, max_strength: float) -> Dictionary:
	return {
		"material_type": material_type,
		"strength": max_strength,
		"max_strength": max_strength,
		"stress": 0.0,
		"falling": false,
		"component_id": -1,
		"component_role": "empty" if material_type == MATERIAL_EMPTY else "stable",
	}


func _make_anchor_points(size: Vector2i, config) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var center := (Vector2(size) - Vector2.ONE) * 0.5
	var anchor_center := center + Vector2(float(size.x) * config.anchor_offset.x, float(size.y) * config.anchor_offset.y)
	var radius: float = float(config.anchor_radius)
	for y in size.y:
		for x in size.x:
			if Vector2(x, y).distance_to(anchor_center) <= radius:
				points.append(Vector2i(x, y))
	return points


func _hash_noise(noise_seed_value: int, x: int, y: int) -> float:
	var value: float = absf(sin(float(noise_seed_value) * 0.001 + float(x) * 12.9898 + float(y) * 78.233) * 43758.5453)
	return value - floorf(value)


func _index(x: int, y: int, width: int) -> int:
	return y * width + x
