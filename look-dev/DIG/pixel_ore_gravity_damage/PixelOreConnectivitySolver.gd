class_name PixelOreConnectivitySolver
extends RefCounted

const GridScript := preload("res://DIG/pixel_ore_gravity_damage/PixelOreGravityGrid.gd")

var _grid = GridScript.new()


func solve_components(grid: Dictionary, config) -> Dictionary:
	config.sanitize()

	var size: Vector2i = grid.get("size", config.grid_size)
	var visited: Array[bool] = []
	visited.resize(size.x * size.y)

	var components: Array = []
	for y in size.y:
		for x in size.x:
			var start_index: int = _index(x, y, size.x)
			if visited[start_index] or _grid.is_empty(grid, x, y):
				continue
			components.append(_collect_component(grid, visited, Vector2i(x, y), size))

	var largest_index: int = _find_largest_component_index(components)
	var deleted_count: int = 0
	var falling_count: int = 0
	var oversized_count: int = 0

	for component_index in components.size():
		var component: Array = components[component_index]
		var role := "stable"
		var falling := false

		if component_index == largest_index:
			role = "stable"
			falling = false
		elif component.size() < int(config.min_loose_component_size):
			for cell_index in component:
				var point := _point_from_index(cell_index, size.x)
				_grid.clear_cell(grid, point.x, point.y)
				deleted_count += 1
			continue
		elif component.size() <= int(config.max_falling_component_size):
			role = "falling"
			falling = true
			falling_count += component.size()
		else:
			role = "oversized"
			falling = false
			oversized_count += component.size()

		for cell_index in component:
			var point := _point_from_index(cell_index, size.x)
			var cell := _grid.get_cell(grid, point.x, point.y)
			cell["falling"] = falling
			cell["component_id"] = component_index
			cell["component_role"] = role
			_grid.set_cell(grid, point.x, point.y, cell)

	grid["component_count"] = components.size()
	grid["main_component_size"] = components[largest_index].size() if largest_index >= 0 else 0
	grid["deleted_loose_count"] = deleted_count
	grid["falling_count"] = falling_count
	grid["oversized_count"] = oversized_count

	return {
		"component_count": components.size(),
		"main_component_size": grid["main_component_size"],
		"deleted_loose_count": deleted_count,
		"falling_count": falling_count,
		"oversized_count": oversized_count,
	}


func _collect_component(grid: Dictionary, visited: Array[bool], start: Vector2i, size: Vector2i) -> Array[int]:
	var component: Array[int] = []
	var queue: Array[Vector2i] = [start]
	visited[_index(start.x, start.y, size.x)] = true

	var cursor: int = 0
	while cursor < queue.size():
		var point: Vector2i = queue[cursor]
		cursor += 1
		component.append(_index(point.x, point.y, size.x))

		for neighbor in _neighbors4(point):
			if not _grid.is_inside(grid, neighbor.x, neighbor.y):
				continue
			var neighbor_index: int = _index(neighbor.x, neighbor.y, size.x)
			if visited[neighbor_index] or _grid.is_empty(grid, neighbor.x, neighbor.y):
				continue
			visited[neighbor_index] = true
			queue.append(neighbor)

	return component


func _find_largest_component_index(components: Array) -> int:
	var largest_index: int = -1
	var largest_size: int = -1
	for index in components.size():
		var component: Array = components[index]
		if component.size() > largest_size:
			largest_size = component.size()
			largest_index = index
	return largest_index


func _neighbors4(point: Vector2i) -> Array[Vector2i]:
	return [
		point + Vector2i(1, 0),
		point + Vector2i(-1, 0),
		point + Vector2i(0, 1),
		point + Vector2i(0, -1),
	]


func _point_from_index(index: int, width: int) -> Vector2i:
	return Vector2i(index % width, floori(float(index) / float(width)))


func _index(x: int, y: int, width: int) -> int:
	return y * width + x
