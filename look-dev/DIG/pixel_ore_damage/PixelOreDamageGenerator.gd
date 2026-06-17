class_name PixelOreDamageGenerator
extends RefCounted

const STATE_EMPTY := 0
const STATE_HEALTHY := 1
const ConfigScript := preload("res://DIG/pixel_ore_damage/PixelOreDamageConfig.gd")


func create_base_grid(albedo_image: Image, config) -> Dictionary:
	if config == null:
		config = ConfigScript.new()
	config.sanitize()

	var size: Vector2i = config.grid_size
	var cells: Array = []
	cells.resize(size.x * size.y)

	var solid_count: int = 0
	for y in size.y:
		for x in size.x:
			var alpha: float = _sample_cell_alpha(albedo_image, Vector2i(x, y), size)
			var is_solid: bool = alpha > float(config.base_alpha_threshold)
			if is_solid:
				solid_count += 1
			cells[_index(x, y, size.x)] = {
				"base_exists": is_solid,
				"exists": is_solid,
				"damage_priority": 1.0,
				"state": STATE_HEALTHY if is_solid else STATE_EMPTY,
			}

	return {
		"size": size,
		"cells": cells,
		"solid_count": solid_count,
		"weak_bands": [],
		"weak_cores": [],
	}


func generate_damage_field(grid: Dictionary, field_seed: int, config) -> void:
	if config == null:
		config = ConfigScript.new()
	config.sanitize()

	var size: Vector2i = grid.get("size", config.grid_size)
	var cells: Array = grid.get("cells", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = field_seed

	var weak_bands: Array = _generate_weak_bands(size, rng, config)
	var weak_cores: Array = _generate_weak_cores(size, rng, config)
	grid["weak_bands"] = weak_bands
	grid["weak_cores"] = weak_cores

	for y in size.y:
		for x in size.x:
			var index: int = _index(x, y, size.x)
			var cell: Dictionary = cells[index]
			if not bool(cell.get("base_exists", false)):
				cell["damage_priority"] = 1.0
				cells[index] = cell
				continue

			var point := Vector2(x, y)
			var noise: float = _hash_noise(field_seed, x, y)
			var priority: float = 0.34 + noise * float(config.noise_strength) + rng.randf_range(0.0, 0.04)

			for band in weak_bands:
				var distance: float = _distance_to_segment(point, band["start"], band["end"])
				var t: float = 1.0 - clampf(distance / float(band["width"]), 0.0, 1.0)
				if t > 0.0:
					priority -= t * float(band["strength"])

			for core in weak_cores:
				var distance_to_core: float = point.distance_to(core["center"])
				var t: float = 1.0 - clampf(distance_to_core / float(core["radius"]), 0.0, 1.0)
				if t > 0.0:
					priority -= t * config.weak_core_strength

			if _is_base_edge(cells, x, y, size):
				priority -= float(config.edge_weakness)

			cell["damage_priority"] = clampf(priority, 0.03, 0.98)
			cells[index] = cell

	grid["cells"] = cells


func _generate_weak_bands(size: Vector2i, rng: RandomNumberGenerator, config) -> Array:
	var bands: Array = []
	var count: int = rng.randi_range(int(config.weak_band_count_min), int(config.weak_band_count_max))
	for _i in count:
		var angle: float = rng.randf_range(0.0, TAU)
		var direction := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-direction.y, direction.x)
		var center := (Vector2(size) - Vector2.ONE) * 0.5
		center += tangent * rng.randf_range(-minf(size.x, size.y) * 0.25, minf(size.x, size.y) * 0.25)
		var half_length: float = maxf(size.x, size.y) * rng.randf_range(0.42, 0.72)
		bands.append({
			"start": center - direction * half_length,
			"end": center + direction * half_length,
			"width": rng.randf_range(float(config.weak_band_width_min), float(config.weak_band_width_max)),
			"strength": rng.randf_range(float(config.weak_band_strength_min), float(config.weak_band_strength_max)),
		})
	return bands


func _generate_weak_cores(size: Vector2i, rng: RandomNumberGenerator, config) -> Array:
	var cores: Array = []
	var count: int = rng.randi_range(int(config.weak_core_count_min), int(config.weak_core_count_max))
	var margin := Vector2(size) * 0.18
	for _i in count:
		cores.append({
			"center": Vector2(
				rng.randf_range(margin.x, maxf(margin.x, float(size.x) - margin.x)),
				rng.randf_range(margin.y, maxf(margin.y, float(size.y) - margin.y))
			),
			"radius": rng.randf_range(float(config.weak_core_radius_min), float(config.weak_core_radius_max)),
		})
	return cores


func _sample_cell_alpha(albedo_image: Image, cell: Vector2i, grid_size: Vector2i) -> float:
	if albedo_image == null or albedo_image.is_empty():
		return 0.0

	var source_size: Vector2i = albedo_image.get_size()
	var x0: int = int(floor(float(cell.x) * float(source_size.x) / float(grid_size.x)))
	var y0: int = int(floor(float(cell.y) * float(source_size.y) / float(grid_size.y)))
	var x1: int = int(ceil(float(cell.x + 1) * float(source_size.x) / float(grid_size.x)))
	var y1: int = int(ceil(float(cell.y + 1) * float(source_size.y) / float(grid_size.y)))
	x0 = clampi(x0, 0, source_size.x - 1)
	y0 = clampi(y0, 0, source_size.y - 1)
	x1 = clampi(maxi(x1, x0 + 1), 1, source_size.x)
	y1 = clampi(maxi(y1, y0 + 1), 1, source_size.y)

	var total: float = 0.0
	var count: int = 0
	for y in range(y0, y1):
		for x in range(x0, x1):
			total += albedo_image.get_pixel(x, y).a
			count += 1

	return total / float(maxi(count, 1))


func _is_base_edge(cells: Array, x: int, y: int, size: Vector2i) -> bool:
	var offsets := [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	for offset in offsets:
		var p: Vector2i = Vector2i(x, y) + offset
		if p.x < 0 or p.y < 0 or p.x >= size.x or p.y >= size.y:
			return true
		var neighbor: Dictionary = cells[_index(p.x, p.y, size.x)]
		if not bool(neighbor.get("base_exists", false)):
			return true
	return false


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)


func _hash_noise(noise_seed_value: int, x: int, y: int) -> float:
	var value: float = absf(sin(float(noise_seed_value) * 0.001 + float(x) * 12.9898 + float(y) * 78.233) * 43758.5453)
	return value - floorf(value)


func _index(x: int, y: int, width: int) -> int:
	return y * width + x
