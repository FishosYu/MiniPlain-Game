class_name CrackDamageRenderer
extends RefCounted

const MASK_ON := Color(1.0, 1.0, 1.0, 1.0)
const MASK_OFF := Color(0.0, 0.0, 0.0, 1.0)
const ConfigScript := preload("res://DIG/procedural_damage/CrackDamageConfig.gd")


func render_masks(base_mask: Image, crack_plan: Dictionary, damage_ratio: float, config) -> Dictionary:
	if config == null:
		config = ConfigScript.new()
	config.sanitize()

	var size := Vector2i(base_mask.get_width(), base_mask.get_height())
	var crack_mask := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	var damage_mask := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	crack_mask.fill(MASK_OFF)
	damage_mask.fill(MASK_OFF)

	var ratio := clampf(damage_ratio, 0.0, 1.0)
	if int(config.crack_pattern_mode) == int(ConfigScript.CrackPatternMode.VORONOI):
		_draw_voronoi_cracks(crack_mask, base_mask, crack_plan, ratio, config)
	else:
		_draw_cracks(crack_mask, base_mask, crack_plan, ratio)
	_draw_chips(damage_mask, base_mask, crack_plan, ratio, config)

	return {
		"crack_mask": crack_mask,
		"damage_mask": damage_mask,
	}


func compose_diffuse(albedo_image: Image, crack_mask: Image, damage_mask: Image, config, show_crack := true, show_damage := true) -> Image:
	var output := albedo_image.duplicate()
	var size := Vector2i(output.get_width(), output.get_height())

	for y in size.y:
		for x in size.x:
			var point := Vector2i(x, y)
			if show_damage and _mask_has_pixel(damage_mask, point):
				output.set_pixelv(point, Color(0.0, 0.0, 0.0, 0.0) if config.damaged_pixels_transparent else config.damaged_pixel_color)
			elif show_crack and _mask_has_pixel(crack_mask, point) and output.get_pixelv(point).a > 0.0:
				output.set_pixelv(point, config.crack_color)

	return output


func compose_normal(normal_image: Image, damage_mask: Image, config, show_damage := true) -> Image:
	var output := normal_image.duplicate()
	var size := Vector2i(output.get_width(), output.get_height())

	for y in size.y:
		for x in size.x:
			var point := Vector2i(x, y)
			if show_damage and _mask_has_pixel(damage_mask, point):
				output.set_pixelv(point, Color(0.5, 0.5, 1.0, 0.0) if config.damaged_normal_transparent else config.flat_normal_color)

	return output


func _draw_cracks(crack_mask: Image, base_mask: Image, crack_plan: Dictionary, damage_ratio: float) -> void:
	for branch in crack_plan.get("branches", []):
		var appear_at := float(branch.get("appear_at", 0.0))
		if damage_ratio < appear_at:
			continue

		var points: Array = branch.get("points", [])
		if points.is_empty():
			continue

		var local_t := inverse_lerp(appear_at, 1.0, damage_ratio)
		local_t = clampf(local_t, 0.0, 1.0)
		var visible_ratio := local_t * float(branch.get("max_visible_ratio", 1.0))
		var visible_count := clampi(ceili(float(points.size()) * visible_ratio), 0, points.size())
		var thickness := int(branch.get("thickness", 1))

		for index in visible_count:
			_draw_mask_point(crack_mask, base_mask, points[index], thickness)


func _draw_chips(damage_mask: Image, base_mask: Image, crack_plan: Dictionary, damage_ratio: float, config) -> void:
	for chip in crack_plan.get("chip_regions", []):
		var appear_at := float(chip.get("appear_at", config.chip_start_damage))
		if damage_ratio < appear_at:
			continue

		var t := clampf(inverse_lerp(appear_at, 1.0, damage_ratio), 0.0, 1.0)
		if t <= 0.0:
			continue

		var center: Vector2i = chip.get("center", Vector2i.ZERO)
		var max_radius := int(chip.get("radius", 1))
		var current_radius := maxi(1, ceili(float(max_radius) * t))
		var noise_seed := int(chip.get("noise_seed", 0))

		for y in range(-current_radius, current_radius + 1):
			for x in range(-current_radius, current_radius + 1):
				var point := center + Vector2i(x, y)
				if not _is_inside_base_mask(base_mask, point):
					continue

				var distance := Vector2(x, y).length()
				if distance <= float(current_radius) - 0.75:
					damage_mask.set_pixelv(point, MASK_ON)
				elif distance <= float(current_radius):
					var noise := _hash_noise(noise_seed, point.x, point.y)
					if noise >= config.chip_edge_noise:
						damage_mask.set_pixelv(point, MASK_ON)


func _draw_voronoi_cracks(crack_mask: Image, base_mask: Image, crack_plan: Dictionary, damage_ratio: float, config) -> void:
	if damage_ratio < config.voronoi_start_damage:
		return

	var sites: Array = crack_plan.get("voronoi_sites", [])
	if sites.size() < 2:
		return

	var visible_t := clampf(inverse_lerp(config.voronoi_start_damage, 1.0, damage_ratio), 0.0, 1.0)
	var threshold: float = maxf(0.01, config.voronoi_edge_threshold) * visible_t
	if threshold <= 0.0:
		return

	for y in crack_mask.get_height():
		for x in crack_mask.get_width():
			var point := Vector2i(x, y)
			if not _is_inside_base_mask(base_mask, point):
				continue

			var distances := _nearest_two_site_distances(point, sites)
			if distances.y - distances.x <= threshold:
				crack_mask.set_pixelv(point, MASK_ON)


func _nearest_two_site_distances(point: Vector2i, sites: Array) -> Vector2:
	var nearest := INF
	var second_nearest := INF
	var point_v := Vector2(point)

	for site in sites:
		var distance := point_v.distance_squared_to(Vector2(site))
		if distance < nearest:
			second_nearest = nearest
			nearest = distance
		elif distance < second_nearest:
			second_nearest = distance

	return Vector2(sqrt(nearest), sqrt(second_nearest))


func _draw_mask_point(mask: Image, base_mask: Image, point: Vector2i, thickness: int) -> void:
	if thickness <= 1:
		if _is_inside_base_mask(base_mask, point):
			mask.set_pixelv(point, MASK_ON)
		return

	var radius := maxi(1, floori(float(thickness) * 0.5))
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var offset := Vector2i(x, y)
			if Vector2(offset).length() <= float(radius):
				var p := point + offset
				if _is_inside_base_mask(base_mask, p):
					mask.set_pixelv(p, MASK_ON)


func _mask_has_pixel(mask: Image, point: Vector2i) -> bool:
	if point.x < 0 or point.y < 0 or point.x >= mask.get_width() or point.y >= mask.get_height():
		return false
	return mask.get_pixelv(point).r > 0.5


func _is_inside_base_mask(base_mask: Image, point: Vector2i) -> bool:
	return _mask_has_pixel(base_mask, point)


func _hash_noise(noise_seed_value: int, x: int, y: int) -> float:
	var value := absf(sin(float(noise_seed_value) * 0.001 + float(x) * 12.9898 + float(y) * 78.233) * 43758.5453)
	return value - floorf(value)
