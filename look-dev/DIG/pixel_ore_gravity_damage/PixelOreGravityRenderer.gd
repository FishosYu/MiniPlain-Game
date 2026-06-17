class_name PixelOreGravityRenderer
extends RefCounted

const GridScript := preload("res://DIG/pixel_ore_gravity_damage/PixelOreGravityGrid.gd")

var _grid = GridScript.new()


func render_final(grid: Dictionary, config) -> Image:
	config.sanitize()

	var size: Vector2i = grid.get("size", config.grid_size)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(config.empty_color)

	for y in size.y:
		for x in size.x:
			var cell := _grid.get_cell(grid, x, y)
			if int(cell.get("material_type", GridScript.MATERIAL_EMPTY)) == GridScript.MATERIAL_EMPTY:
				continue

			if bool(cell.get("falling", false)):
				image.set_pixel(x, y, config.loose_color)
			elif _is_edge_pixel(grid, x, y):
				image.set_pixel(x, y, config.edge_color)
			elif float(cell.get("strength", 0.0)) < float(cell.get("max_strength", 1.0)):
				image.set_pixel(x, y, config.damaged_color)
			else:
				image.set_pixel(x, y, config.body_color)

	return image


func render_component_preview(grid: Dictionary) -> Image:
	var size: Vector2i = grid.get("size", Vector2i(32, 32))
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 1.0))

	for y in size.y:
		for x in size.x:
			var cell := _grid.get_cell(grid, x, y)
			if int(cell.get("material_type", GridScript.MATERIAL_EMPTY)) == GridScript.MATERIAL_EMPTY:
				continue

			var role: String = str(cell.get("component_role", "stable"))
			if role == "falling":
				image.set_pixel(x, y, Color(1.0, 0.72, 0.16, 1.0))
			elif role == "oversized":
				image.set_pixel(x, y, Color(0.42, 0.48, 1.0, 1.0))
			else:
				image.set_pixel(x, y, Color(0.78, 0.80, 0.76, 1.0))

	return image


func render_falling_preview(grid: Dictionary) -> Image:
	var size: Vector2i = grid.get("size", Vector2i(32, 32))
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 1.0))

	for y in size.y:
		for x in size.x:
			var cell := _grid.get_cell(grid, x, y)
			if int(cell.get("material_type", GridScript.MATERIAL_EMPTY)) == GridScript.MATERIAL_EMPTY:
				continue
			if bool(cell.get("falling", false)):
				image.set_pixel(x, y, Color(1.0, 0.30, 0.08, 1.0))
			else:
				image.set_pixel(x, y, Color(0.22, 0.24, 0.23, 1.0))

	return image


func mark_pixel(image: Image, pixel: Vector2i, color: Color) -> void:
	if image == null or image.is_empty():
		return
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= image.get_width() or pixel.y >= image.get_height():
		return
	image.set_pixelv(pixel, color)


func _is_edge_pixel(grid: Dictionary, x: int, y: int) -> bool:
	var offsets := [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	for offset in offsets:
		var p: Vector2i = Vector2i(x, y) + offset
		if _grid.is_empty(grid, p.x, p.y):
			return true
	return false
