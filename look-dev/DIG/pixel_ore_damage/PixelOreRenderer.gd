class_name PixelOreRenderer
extends RefCounted

const STATE_EMPTY := 0
const STATE_HEALTHY := 1
const STATE_DAMAGED := 2
const ConfigScript := preload("res://DIG/pixel_ore_damage/PixelOreDamageConfig.gd")


func render_final(grid: Dictionary, config) -> Image:
	if config == null:
		config = ConfigScript.new()
	config.sanitize()

	var size: Vector2i = grid.get("size", config.grid_size)
	var cells: Array = grid.get("cells", [])
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(config.empty_color)

	for y in size.y:
		for x in size.x:
			var index := _index(x, y, size.x)
			var cell: Dictionary = cells[index]
			if not bool(cell.get("exists", false)):
				continue

			var color: Color
			if int(cell.get("state", STATE_HEALTHY)) == STATE_DAMAGED:
				color = config.damaged_color
			elif _is_current_edge(cells, x, y, size):
				color = config.edge_color
			else:
				color = _shade_body_color(config.body_color, float(cell.get("damage_priority", 1.0)))
			image.set_pixel(x, y, color)

	return image


func render_damage_field(grid: Dictionary, config = null) -> Image:
	if config == null:
		config = ConfigScript.new()
	config.sanitize()

	var size: Vector2i = grid.get("size", config.grid_size)
	var cells: Array = grid.get("cells", [])
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 1.0))

	for y in size.y:
		for x in size.x:
			var cell: Dictionary = cells[_index(x, y, size.x)]
			if not bool(cell.get("base_exists", false)):
				continue
			var early_break := 1.0 - float(cell.get("damage_priority", 1.0))
			image.set_pixel(x, y, config.damage_field_low_color.lerp(config.damage_field_high_color, early_break))

	return image


func render_mask_preview(grid: Dictionary) -> Image:
	var size: Vector2i = grid.get("size", Vector2i(32, 32))
	var cells: Array = grid.get("cells", [])
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 1.0))

	for y in size.y:
		for x in size.x:
			var cell: Dictionary = cells[_index(x, y, size.x)]
			if bool(cell.get("exists", false)):
				image.set_pixel(x, y, Color.WHITE)
			elif bool(cell.get("base_exists", false)):
				image.set_pixel(x, y, Color(0.25, 0.05, 0.04, 1.0))

	return image


func render_combined_preview(grid: Dictionary, config) -> Image:
	if config == null:
		config = ConfigScript.new()
	config.sanitize()

	var size: Vector2i = grid.get("size", config.grid_size)
	var cells: Array = grid.get("cells", [])
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 1.0))

	for y in size.y:
		for x in size.x:
			var index := _index(x, y, size.x)
			var cell: Dictionary = cells[index]
			if not bool(cell.get("base_exists", false)):
				continue
			if not bool(cell.get("exists", false)):
				image.set_pixel(x, y, Color(1.0, 0.18, 0.08, 1.0))
			elif int(cell.get("state", STATE_HEALTHY)) == STATE_DAMAGED:
				image.set_pixel(x, y, Color(1.0, 0.76, 0.12, 1.0))
			elif _is_current_edge(cells, x, y, size):
				image.set_pixel(x, y, Color(0.35, 0.86, 1.0, 1.0))
			else:
				image.set_pixel(x, y, Color(0.65, 0.68, 0.64, 1.0))

	return image


func _is_current_edge(cells: Array, x: int, y: int, size: Vector2i) -> bool:
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
		if not bool(neighbor.get("exists", false)):
			return true
	return false


func _shade_body_color(base: Color, priority: float) -> Color:
	var lift := clampf((priority - 0.35) * 0.22, -0.05, 0.08)
	return Color(
		clampf(base.r + lift, 0.0, 1.0),
		clampf(base.g + lift, 0.0, 1.0),
		clampf(base.b + lift, 0.0, 1.0),
		base.a
	)


func _index(x: int, y: int, width: int) -> int:
	return y * width + x
