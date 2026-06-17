class_name PixelOreDamageSolver
extends RefCounted

const STATE_EMPTY := 0
const STATE_HEALTHY := 1
const STATE_DAMAGED := 2
const ConfigScript := preload("res://DIG/pixel_ore_damage/PixelOreDamageConfig.gd")


func apply_damage_ratio(grid: Dictionary, damage_ratio: float, config) -> void:
	if config == null:
		config = ConfigScript.new()
	config.sanitize()

	var size: Vector2i = grid.get("size", config.grid_size)
	var cells: Array = grid.get("cells", [])
	var ratio := clampf(damage_ratio, 0.0, 1.0)

	for y in size.y:
		for x in size.x:
			var index := _index(x, y, size.x)
			var cell: Dictionary = cells[index]
			if not bool(cell.get("base_exists", false)):
				cell["exists"] = false
				cell["state"] = STATE_EMPTY
				cells[index] = cell
				continue

			var priority := float(cell.get("damage_priority", 1.0))
			if ratio >= priority:
				cell["exists"] = false
				cell["state"] = STATE_EMPTY
			else:
				cell["exists"] = true
				cell["state"] = STATE_DAMAGED if ratio >= priority - config.damaged_state_margin else STATE_HEALTHY
			cells[index] = cell

	grid["cells"] = cells


func solve_connectivity(grid: Dictionary, config) -> void:
	if config == null:
		config = ConfigScript.new()
	config.sanitize()

	var size: Vector2i = grid.get("size", config.grid_size)
	var cells: Array = grid.get("cells", [])
	var visited: Array[bool] = []
	visited.resize(size.x * size.y)

	var largest_component: Array[int] = []
	var loose_components: Array = []

	for y in size.y:
		for x in size.x:
			var start_index := _index(x, y, size.x)
			if visited[start_index] or not _cell_exists(cells, start_index):
				continue

			var component := _collect_component(cells, visited, Vector2i(x, y), size)
			if component.size() > largest_component.size():
				if not largest_component.is_empty():
					loose_components.append(largest_component)
				largest_component = component
			else:
				loose_components.append(component)

	for component in loose_components:
		for index in component:
			var cell: Dictionary = cells[index]
			cell["exists"] = false
			cell["state"] = STATE_EMPTY
			cells[index] = cell

	grid["cells"] = cells
	grid["main_component_size"] = largest_component.size()
	grid["loose_component_count"] = loose_components.size()


func _collect_component(cells: Array, visited: Array[bool], start: Vector2i, size: Vector2i) -> Array[int]:
	var component: Array[int] = []
	var queue: Array[Vector2i] = [start]
	visited[_index(start.x, start.y, size.x)] = true

	var cursor := 0
	while cursor < queue.size():
		var point := queue[cursor]
		cursor += 1
		var point_index := _index(point.x, point.y, size.x)
		component.append(point_index)

		for neighbor in _neighbors4(point):
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= size.x or neighbor.y >= size.y:
				continue
			var neighbor_index := _index(neighbor.x, neighbor.y, size.x)
			if visited[neighbor_index] or not _cell_exists(cells, neighbor_index):
				continue
			visited[neighbor_index] = true
			queue.append(neighbor)

	return component


func _neighbors4(point: Vector2i) -> Array[Vector2i]:
	return [
		point + Vector2i(1, 0),
		point + Vector2i(-1, 0),
		point + Vector2i(0, 1),
		point + Vector2i(0, -1),
	]


func _cell_exists(cells: Array, index: int) -> bool:
	var cell: Dictionary = cells[index]
	return bool(cell.get("exists", false))


func _index(x: int, y: int, width: int) -> int:
	return y * width + x
