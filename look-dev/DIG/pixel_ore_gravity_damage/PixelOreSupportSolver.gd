class_name PixelOreSupportSolver
extends RefCounted

const GridScript := preload("res://DIG/pixel_ore_gravity_damage/PixelOreGravityGrid.gd")

var _grid = GridScript.new()


func solve_supported_components(grid: Dictionary, config) -> Dictionary:
	config.sanitize()

	var size: Vector2i = grid.get("size", config.grid_size)
	var visited: Array[bool] = []
	visited.resize(size.x * size.y)

	var components: Array = []
	var anchored_component_ids := {}
	for y in size.y:
		for x in size.x:
			var start_index: int = _index(x, y, size.x)
			if visited[start_index] or _grid.is_empty(grid, x, y):
				continue

			var component: Array = _collect_component(grid, visited, Vector2i(x, y), size)
			var component_id: int = components.size()
			if _component_has_anchor(grid, component):
				anchored_component_ids[component_id] = true
			components.append(component)

	var stable_count: int = 0
	var unsupported_count: int = 0
	var unsupported_components: Array = []
	for component_id in components.size():
		var component: Array = components[component_id]
		var is_supported: bool = anchored_component_ids.has(component_id)
		for cell_index in component:
			var point := _point_from_index(cell_index, size.x)
			var cell := _grid.get_cell(grid, point.x, point.y)
			cell["falling"] = not is_supported
			cell["component_id"] = component_id
			cell["component_role"] = "stable" if is_supported else "unsupported"
			_grid.set_cell(grid, point.x, point.y, cell)

		if is_supported:
			stable_count += component.size()
		else:
			unsupported_count += component.size()
			unsupported_components.append({
				"id": component_id,
				"cells": component,
				"size": component.size(),
			})

	grid["component_count"] = components.size()
	grid["stable_count"] = stable_count
	grid["unsupported_count"] = unsupported_count
	grid["unsupported_component_count"] = unsupported_components.size()

	return {
		"component_count": components.size(),
		"stable_count": stable_count,
		"unsupported_count": unsupported_count,
		"unsupported_components": unsupported_components,
	}


func _component_has_anchor(grid: Dictionary, component: Array) -> bool:
	var size: Vector2i = grid.get("size", Vector2i.ZERO)
	var occupied := {}
	for cell_index in component:
		occupied[cell_index] = true

	for anchor in grid.get("anchor_points", []):
		var anchor_point: Vector2i = anchor
		if not _grid.is_inside(grid, anchor_point.x, anchor_point.y):
			continue
		if _grid.is_empty(grid, anchor_point.x, anchor_point.y):
			continue
		if occupied.has(_index(anchor_point.x, anchor_point.y, size.x)):
			return true
	return false


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
