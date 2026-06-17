class_name PixelOreFragmentSpawner
extends RefCounted

const GridScript := preload("res://DIG/pixel_ore_gravity_damage/PixelOreGravityGrid.gd")

var _grid = GridScript.new()


func spawn_fragments(parent: Node, grid: Dictionary, unsupported_components: Array, ore_sprite: Sprite2D, hit_pixel: Vector2i, config) -> Dictionary:
	config.sanitize()
	if parent == null or ore_sprite == null:
		return {"spawned_count": 0, "cleared_pixels": 0}

	var spawned_count: int = 0
	var cleared_pixels: int = 0
	for component_info in unsupported_components:
		var component: Array = component_info.get("cells", [])
		if component.size() < int(config.fragment_min_pixels):
			cleared_pixels += _clear_component(grid, component)
			continue

		var fragment := _create_fragment(grid, component, ore_sprite, hit_pixel, config)
		if fragment != null:
			parent.add_child(fragment)
			_apply_initial_impulse(fragment)
			spawned_count += 1
		cleared_pixels += _clear_component(grid, component)

	return {
		"spawned_count": spawned_count,
		"cleared_pixels": cleared_pixels,
	}


func _create_fragment(grid: Dictionary, component: Array, ore_sprite: Sprite2D, hit_pixel: Vector2i, config) -> RigidBody2D:
	var size: Vector2i = grid.get("size", config.grid_size)
	var bounds := _component_bounds(component, size.x)
	var min_point: Vector2i = bounds["min"]
	var max_point: Vector2i = bounds["max"]
	var fragment_size := max_point - min_point + Vector2i.ONE
	if fragment_size.x <= 0 or fragment_size.y <= 0:
		return null

	var image := Image.create(fragment_size.x, fragment_size.y, false, Image.FORMAT_RGBA8)
	image.fill(config.empty_color)
	for cell_index in component:
		var point := _point_from_index(cell_index, size.x)
		var cell := _grid.get_cell(grid, point.x, point.y)
		if int(cell.get("material_type", GridScript.MATERIAL_EMPTY)) == GridScript.MATERIAL_EMPTY:
			continue
		var local_point := point - min_point
		image.set_pixel(local_point.x, local_point.y, config.loose_color)

	var body := RigidBody2D.new()
	body.name = "OreFragment"
	body.gravity_scale = 1.0
	body.mass = maxf(0.1, float(component.size()) * 0.05)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.scale = ore_sprite.scale
	body.add_child(sprite)

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(fragment_size) * ore_sprite.scale.abs() + Vector2.ONE * float(config.fragment_collision_padding)
	collision.shape = shape
	body.add_child(collision)

	var component_center_pixel := Vector2(min_point) + Vector2(fragment_size) * 0.5
	var local_center := component_center_pixel - Vector2(size) * 0.5
	body.global_position = ore_sprite.to_global(local_center)

	var direction := (component_center_pixel - Vector2(hit_pixel)).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2(randf() - 0.5, -0.6).normalized()
	body.set_meta("initial_impulse", direction * float(config.fragment_linear_impulse))
	body.set_meta("initial_torque", float(config.fragment_torque_impulse) * (-1.0 if direction.x < 0.0 else 1.0))
	return body


func _apply_initial_impulse(body: RigidBody2D) -> void:
	if body == null:
		return
	body.apply_impulse(body.get_meta("initial_impulse", Vector2.ZERO))
	body.apply_torque_impulse(float(body.get_meta("initial_torque", 0.0)))


func _clear_component(grid: Dictionary, component: Array) -> int:
	var size: Vector2i = grid.get("size", Vector2i.ZERO)
	var cleared: int = 0
	for cell_index in component:
		var point := _point_from_index(cell_index, size.x)
		if not _grid.is_empty(grid, point.x, point.y):
			_grid.clear_cell(grid, point.x, point.y)
			cleared += 1
	return cleared


func _component_bounds(component: Array, width: int) -> Dictionary:
	var min_point := Vector2i(999999, 999999)
	var max_point := Vector2i(-999999, -999999)
	for cell_index in component:
		var point := _point_from_index(cell_index, width)
		min_point.x = mini(min_point.x, point.x)
		min_point.y = mini(min_point.y, point.y)
		max_point.x = maxi(max_point.x, point.x)
		max_point.y = maxi(max_point.y, point.y)
	return {"min": min_point, "max": max_point}


func _point_from_index(index: int, width: int) -> Vector2i:
	return Vector2i(index % width, floori(float(index) / float(width)))
