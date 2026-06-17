class_name CrackDamageGenerator
extends RefCounted

const MASK_ON := Color(1.0, 1.0, 1.0, 1.0)
const MASK_OFF := Color(0.0, 0.0, 0.0, 1.0)
const ConfigScript := preload("res://DIG/procedural_damage/CrackDamageConfig.gd")


func create_base_mask(albedo_image: Image, alpha_threshold: float) -> Image:
	var mask := Image.create(albedo_image.get_width(), albedo_image.get_height(), false, Image.FORMAT_L8)

	for y in mask.get_height():
		for x in mask.get_width():
			var alpha := albedo_image.get_pixel(x, y).a
			mask.set_pixel(x, y, MASK_ON if alpha > alpha_threshold else MASK_OFF)

	return mask


func generate_plan(base_mask: Image, plan_seed: int, config) -> Dictionary:
	if config == null:
		config = ConfigScript.new()
	config.sanitize()

	var rng := RandomNumberGenerator.new()
	rng.seed = plan_seed

	var solid_points := _collect_solid_points(base_mask)
	var plan := {
		"size": Vector2i(base_mask.get_width(), base_mask.get_height()),
		"seed": plan_seed,
		"branches": [],
		"chip_regions": [],
		"voronoi_sites": [],
	}

	if solid_points.is_empty():
		return plan

	plan["voronoi_sites"] = _pick_fracture_cores(base_mask, solid_points, config.voronoi_site_count, rng)

	var main_count := rng.randi_range(config.main_crack_count_min, config.main_crack_count_max)
	var start_angle := rng.randf_range(0.0, TAU)
	var cores := _pick_fracture_cores(base_mask, solid_points, main_count, rng)

	for core_index in cores.size():
		var core: Vector2i = cores[core_index]
		var generated := false
		var attempts := 0
		var max_attempts := 8
		while not generated and attempts < max_attempts:
			var spread_angle := start_angle + TAU * float(core_index) / float(maxi(main_count, 1))
			var direction_angle := spread_angle + deg_to_rad(rng.randf_range(-28.0, 28.0))
			var direction := Vector2(cos(direction_angle), sin(direction_angle))
			var start := _jitter_start_inside(base_mask, core, rng)
			var energy := rng.randf_range(config.main_crack_energy_min, config.main_crack_energy_max)
			var appear_at := rng.randf_range(config.crack_start_damage, minf(config.branch_start_damage, 1.0))
			var branch_start_count: int = plan["branches"].size()
			if _grow_branch(plan, base_mask, start, direction, energy, 0, appear_at, rng, config, core_index):
				generated = true
			elif plan["branches"].size() > branch_start_count:
				plan["branches"].resize(branch_start_count)
			attempts += 1

	_generate_chips(plan, base_mask, solid_points, rng, config)
	return plan


func _pick_fracture_cores(base_mask: Image, solid_points: Array[Vector2i], count: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cores: Array[Vector2i] = []
	var target_count := maxi(count, 1)
	var min_distance := maxf(3.0, minf(float(base_mask.get_width()), float(base_mask.get_height())) / maxf(float(target_count), 1.0) * 0.45)

	for index in target_count:
		var core := _pick_spread_core(solid_points, cores, min_distance, rng)
		cores.append(core)

	return cores


func _pick_spread_core(solid_points: Array[Vector2i], existing_cores: Array[Vector2i], min_distance: float, rng: RandomNumberGenerator) -> Vector2i:
	if existing_cores.is_empty():
		return solid_points[rng.randi_range(0, solid_points.size() - 1)]

	var best_point := solid_points[rng.randi_range(0, solid_points.size() - 1)]
	var best_distance := -1.0
	for attempt in 48:
		var candidate := solid_points[rng.randi_range(0, solid_points.size() - 1)]
		var distance := _distance_to_nearest_core(candidate, existing_cores)
		if distance >= min_distance:
			return candidate
		if distance > best_distance:
			best_distance = distance
			best_point = candidate

	return best_point


func _distance_to_nearest_core(point: Vector2i, existing_cores: Array[Vector2i]) -> float:
	var nearest := INF
	for core in existing_cores:
		nearest = minf(nearest, Vector2(point).distance_to(Vector2(core)))
	return nearest


func _grow_branch(
		plan: Dictionary,
		base_mask: Image,
		start: Vector2i,
		direction: Vector2,
		energy: float,
		generation: int,
		appear_at: float,
		rng: RandomNumberGenerator,
		config,
		core_index: int) -> bool:
	if generation > config.max_generation:
		return false
	if plan["branches"].size() >= config.max_branch_count:
		return false

	var points: Array[Vector2i] = []
	var branch := {
		"points": points,
		"appear_at": clampf(appear_at, 0.0, 1.0),
		"max_visible_ratio": 1.0,
		"thickness": config.crack_thickness,
		"generation": generation,
		"core_index": core_index,
	}
	plan["branches"].append(branch)

	var pos := Vector2(start)
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	if _is_inside_base_mask(base_mask, start):
		points.append(start)

	var last_pixel := Vector2i(-999999, -999999)
	while energy > 0.0:
		pos += dir
		var pixel := Vector2i(roundi(pos.x), roundi(pos.y))

		if pixel == last_pixel:
			energy -= 0.5
			continue
		last_pixel = pixel

		if not _is_inside_base_mask(base_mask, pixel):
			break

		points.append(pixel)

		if generation < config.max_generation and plan["branches"].size() < config.max_branch_count:
			var branch_chance: float = config.main_branch_chance if generation == 0 else config.child_branch_chance
			if energy > 4.0 and rng.randf() < branch_chance:
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				var child_angle := deg_to_rad(rng.randf_range(30.0, 70.0)) * side
				var child_dir := dir.rotated(child_angle)
				var child_energy := energy * rng.randf_range(0.35, 0.6)
				var child_appear_at := _appear_at_for_generation(generation + 1, rng, config)
				child_appear_at = maxf(child_appear_at, appear_at)
				_grow_branch(plan, base_mask, pixel, child_dir, child_energy, generation + 1, child_appear_at, rng, config, core_index)

		dir = dir.rotated(deg_to_rad(rng.randf_range(-config.direction_jitter_degrees, config.direction_jitter_degrees)))
		energy -= rng.randf_range(0.8, 1.3)

	if points.is_empty():
		plan["branches"].erase(branch)
		return false

	if generation == 0 and points.size() < 3:
		plan["branches"].erase(branch)
		return false

	return true


func _generate_chips(
		plan: Dictionary,
		base_mask: Image,
		solid_points: Array[Vector2i],
		rng: RandomNumberGenerator,
		config) -> void:
	var chip_count := rng.randi_range(config.chip_count_min, config.chip_count_max)
	if chip_count <= 0:
		return

	var crack_points: Array[Vector2i] = []
	for branch in plan["branches"]:
		crack_points.append_array(branch["points"])

	var edge_points := _collect_edge_points(base_mask, solid_points)

	for index in chip_count:
		var use_crack_point := not crack_points.is_empty() and (edge_points.is_empty() or rng.randf() < 0.6)
		var center := Vector2i.ZERO
		if use_crack_point:
			center = crack_points[rng.randi_range(0, crack_points.size() - 1)]
		else:
			center = edge_points[rng.randi_range(0, edge_points.size() - 1)]

		var chip := {
			"center": center,
			"radius": rng.randi_range(config.chip_radius_min, config.chip_radius_max),
			"appear_at": rng.randf_range(config.chip_start_damage, minf(0.9, 1.0)),
			"noise_seed": rng.randi(),
		}
		plan["chip_regions"].append(chip)


func _appear_at_for_generation(generation: int, rng: RandomNumberGenerator, config) -> float:
	if generation <= 0:
		return rng.randf_range(config.crack_start_damage, minf(config.branch_start_damage, 1.0))
	if generation == 1:
		return rng.randf_range(config.branch_start_damage, minf(config.chip_start_damage + 0.05, 1.0))
	return rng.randf_range(maxf(config.branch_start_damage, 0.6), 0.9)


func _pick_fracture_core(base_mask: Image, solid_points: Array[Vector2i], rng: RandomNumberGenerator) -> Vector2i:
	var size := Vector2(base_mask.get_width(), base_mask.get_height())
	var center := (size - Vector2.ONE) * 0.5
	var radius := minf(size.x, size.y) * 0.3
	var candidates: Array[Vector2i] = []

	for point in solid_points:
		if Vector2(point).distance_to(center) <= radius:
			candidates.append(point)

	if candidates.is_empty():
		candidates = solid_points.duplicate()

	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _jitter_start_inside(base_mask: Image, core: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	for attempt in 12:
		var offset := Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
		var candidate := core + offset
		if _is_inside_base_mask(base_mask, candidate):
			return candidate
	return core


func _collect_solid_points(base_mask: Image) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for y in base_mask.get_height():
		for x in base_mask.get_width():
			var point := Vector2i(x, y)
			if _is_inside_base_mask(base_mask, point):
				points.append(point)
	return points


func _collect_edge_points(base_mask: Image, solid_points: Array[Vector2i]) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var offsets := [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]

	for point in solid_points:
		for offset in offsets:
			if not _is_inside_base_mask(base_mask, point + offset):
				points.append(point)
				break

	return points


func _is_inside_base_mask(base_mask: Image, point: Vector2i) -> bool:
	if point.x < 0 or point.y < 0 or point.x >= base_mask.get_width() or point.y >= base_mask.get_height():
		return false
	return base_mask.get_pixelv(point).r > 0.5
