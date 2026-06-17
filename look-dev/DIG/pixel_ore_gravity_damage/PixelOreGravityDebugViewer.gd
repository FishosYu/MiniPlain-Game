@tool
class_name PixelOreGravityDebugViewer
extends Node2D

const ConfigScript := preload("res://DIG/pixel_ore_gravity_damage/PixelOreGravityConfig.gd")
const GridScript := preload("res://DIG/pixel_ore_gravity_damage/PixelOreGravityGrid.gd")
const BrushSolverScript := preload("res://DIG/pixel_ore_gravity_damage/PixelOreBrushDamageSolver.gd")
const ConnectivitySolverScript := preload("res://DIG/pixel_ore_gravity_damage/PixelOreConnectivitySolver.gd")
const GravitySolverScript := preload("res://DIG/pixel_ore_gravity_damage/PixelOreGravitySolver.gd")
const RendererScript := preload("res://DIG/pixel_ore_gravity_damage/PixelOreGravityRenderer.gd")

@export var config: Resource:
	set(value):
		config = value
		_mark_grid_dirty()

@export var ore_seed := 12345:
	set(value):
		ore_seed = value
		_mark_grid_dirty()

@export_node_path("Sprite2D") var target_sprite_path: NodePath = ^"OreSprite"
@export_node_path("Sprite2D") var component_sprite_path: NodePath = ^"ComponentSprite"
@export_node_path("Sprite2D") var falling_sprite_path: NodePath = ^"FallingSprite"
@export_node_path("SpinBox") var seed_spin_box_path: NodePath = ^"SeedSpinBox"
@export_node_path("SpinBox") var brush_radius_spin_box_path: NodePath = ^"BrushRadiusSpinBox"
@export_node_path("SpinBox") var brush_damage_spin_box_path: NodePath = ^"BrushDamageSpinBox"
@export_node_path("CheckBox") var gravity_toggle_path: NodePath = ^"GravityToggle"
@export_node_path("Button") var reset_button_path: NodePath = ^"ResetButton"
@export_node_path("Button") var gravity_step_button_path: NodePath = ^"GravityStepButton"
@export_node_path("Label") var status_label_path: NodePath = ^"StatusLabel"

var _grid_tool = GridScript.new()
var _brush_solver = BrushSolverScript.new()
var _connectivity_solver = ConnectivitySolverScript.new()
var _gravity_solver = GravitySolverScript.new()
var _renderer = RendererScript.new()
var _grid: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _grid_dirty := true
var _last_click_pixel := Vector2i(-1, -1)
var _last_hit_stats: Dictionary = {}
var _last_connectivity_stats: Dictionary = {}
var _last_gravity_stats: Dictionary = {}
var _target_sprite: Sprite2D
var _component_sprite: Sprite2D
var _falling_sprite: Sprite2D
var _seed_spin_box: SpinBox
var _brush_radius_spin_box: SpinBox
var _brush_damage_spin_box: SpinBox
var _gravity_toggle: CheckBox
var _reset_button: Button
var _gravity_step_button: Button
var _status_label: Label


func _ready() -> void:
	if config == null:
		config = ConfigScript.new()
	_resolve_scene_nodes()
	_setup_controls()
	_reset_grid()
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var pixel := world_to_pixel(get_global_mouse_position())
	if not _grid_tool.is_inside(_grid, pixel.x, pixel.y):
		return

	hit_at_world_position(get_global_mouse_position())
	get_viewport().set_input_as_handled()


func hit_at_world_position(world_pos: Vector2) -> void:
	if _grid_dirty:
		_reset_grid()

	var pixel := world_to_pixel(world_pos)
	if not _grid_tool.is_inside(_grid, pixel.x, pixel.y):
		return

	_last_click_pixel = pixel
	_rng.seed = int(ore_seed) * 1009 + pixel.x * 9176 + pixel.y * 31337 + Time.get_ticks_msec()
	_last_hit_stats = _brush_solver.apply_brush_damage(_grid, pixel, config, _rng)
	_last_connectivity_stats = _connectivity_solver.solve_components(_grid, config)

	if bool(config.enable_gravity):
		_last_gravity_stats = _gravity_solver.simulate_steps(_grid, config, _rng)
	else:
		_last_gravity_stats = {"steps_run": 0, "moved_count": 0}

	_render_and_update()


func world_to_pixel(world_pos: Vector2) -> Vector2i:
	_resolve_scene_nodes()
	if _target_sprite == null:
		return Vector2i(-1, -1)

	var size: Vector2i = _grid.get("size", config.grid_size)
	var local_pos := _target_sprite.to_local(world_pos)
	var sprite_size := Vector2(size)
	var top_left := -sprite_size * 0.5
	var uv := (local_pos - top_left) / sprite_size
	return Vector2i(floori(uv.x * float(size.x)), floori(uv.y * float(size.y)))


func _reset_grid() -> void:
	if config == null:
		config = ConfigScript.new()
	config.sanitize()

	_rng.seed = ore_seed
	_grid = _grid_tool.create_ellipse(config, ore_seed)
	_last_click_pixel = Vector2i(-1, -1)
	_last_hit_stats = {}
	_last_connectivity_stats = _connectivity_solver.solve_components(_grid, config)
	_last_gravity_stats = {}
	_grid_dirty = false
	_render_and_update()


func _render_and_update() -> void:
	_resolve_scene_nodes()
	_sync_controls()

	var final_image := _renderer.render_final(_grid, config)
	var component_image := _renderer.render_component_preview(_grid)
	var falling_image := _renderer.render_falling_preview(_grid)
	if _last_click_pixel.x >= 0:
		_renderer.mark_pixel(final_image, _last_click_pixel, config.click_marker_color)
		_renderer.mark_pixel(component_image, _last_click_pixel, config.click_marker_color)
		_renderer.mark_pixel(falling_image, _last_click_pixel, config.click_marker_color)

	_set_sprite_texture(_target_sprite, final_image)
	_set_sprite_texture(_component_sprite, component_image)
	_set_sprite_texture(_falling_sprite, falling_image)
	_set_status(_make_status_text())


func _set_sprite_texture(sprite: Sprite2D, image: Image) -> void:
	if sprite == null or image == null or image.is_empty():
		return
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.scale = Vector2(float(config.pixel_scale), float(config.pixel_scale))


func _make_status_text() -> String:
	var click_text := "none" if _last_click_pixel.x < 0 else "%d,%d" % [_last_click_pixel.x, _last_click_pixel.y]
	return "Seed %d | Grid %dx%d | Click %s | Hit %d/%d | Components %d | Falling %d | Gravity %d/%d" % [
		ore_seed,
		config.grid_size.x,
		config.grid_size.y,
		click_text,
		int(_last_hit_stats.get("removed_count", 0)),
		int(_last_hit_stats.get("damaged_count", 0)),
		int(_last_connectivity_stats.get("component_count", 0)),
		int(_last_connectivity_stats.get("falling_count", 0)),
		int(_last_gravity_stats.get("moved_count", 0)),
		int(_last_gravity_stats.get("steps_run", 0)),
	]


func _setup_controls() -> void:
	if _seed_spin_box != null:
		_seed_spin_box.min_value = 0.0
		_seed_spin_box.max_value = 999999.0
		_seed_spin_box.step = 1.0
		_seed_spin_box.value = ore_seed
		if not _seed_spin_box.value_changed.is_connected(_on_seed_changed):
			_seed_spin_box.value_changed.connect(_on_seed_changed)

	if _brush_radius_spin_box != null:
		_brush_radius_spin_box.min_value = 1.0
		_brush_radius_spin_box.max_value = 12.0
		_brush_radius_spin_box.step = 1.0
		_brush_radius_spin_box.value = config.brush_radius
		if not _brush_radius_spin_box.value_changed.is_connected(_on_brush_radius_changed):
			_brush_radius_spin_box.value_changed.connect(_on_brush_radius_changed)

	if _brush_damage_spin_box != null:
		_brush_damage_spin_box.min_value = 0.1
		_brush_damage_spin_box.max_value = 8.0
		_brush_damage_spin_box.step = 0.1
		_brush_damage_spin_box.value = config.brush_damage
		if not _brush_damage_spin_box.value_changed.is_connected(_on_brush_damage_changed):
			_brush_damage_spin_box.value_changed.connect(_on_brush_damage_changed)

	if _gravity_toggle != null:
		_gravity_toggle.button_pressed = config.enable_gravity
		if not _gravity_toggle.toggled.is_connected(_on_gravity_toggled):
			_gravity_toggle.toggled.connect(_on_gravity_toggled)

	if _reset_button != null and not _reset_button.pressed.is_connected(_on_reset_pressed):
		_reset_button.pressed.connect(_on_reset_pressed)

	if _gravity_step_button != null and not _gravity_step_button.pressed.is_connected(_on_gravity_step_pressed):
		_gravity_step_button.pressed.connect(_on_gravity_step_pressed)


func _sync_controls() -> void:
	if _seed_spin_box != null and int(_seed_spin_box.value) != ore_seed:
		_seed_spin_box.set_value_no_signal(ore_seed)
	if _brush_radius_spin_box != null and int(_brush_radius_spin_box.value) != int(config.brush_radius):
		_brush_radius_spin_box.set_value_no_signal(config.brush_radius)
	if _brush_damage_spin_box != null and not is_equal_approx(float(_brush_damage_spin_box.value), float(config.brush_damage)):
		_brush_damage_spin_box.set_value_no_signal(config.brush_damage)
	if _gravity_toggle != null and _gravity_toggle.button_pressed != bool(config.enable_gravity):
		_gravity_toggle.set_pressed_no_signal(config.enable_gravity)


func _on_seed_changed(value: float) -> void:
	ore_seed = int(value)
	_reset_grid()


func _on_brush_radius_changed(value: float) -> void:
	config.brush_radius = int(value)
	_render_and_update()


func _on_brush_damage_changed(value: float) -> void:
	config.brush_damage = value
	_render_and_update()


func _on_gravity_toggled(enabled: bool) -> void:
	config.enable_gravity = enabled
	_render_and_update()


func _on_reset_pressed() -> void:
	_reset_grid()


func _on_gravity_step_pressed() -> void:
	_rng.seed = Time.get_ticks_msec() + ore_seed
	var moved: int = _gravity_solver.simulate_step(_grid, _rng)
	_last_gravity_stats = {"steps_run": 1, "moved_count": moved}
	_render_and_update()


func _mark_grid_dirty() -> void:
	_grid_dirty = true
	if is_inside_tree():
		_reset_grid()


func _resolve_scene_nodes() -> void:
	_target_sprite = _resolve_node(target_sprite_path, "OreSprite") as Sprite2D
	_component_sprite = _resolve_node(component_sprite_path, "ComponentSprite") as Sprite2D
	_falling_sprite = _resolve_node(falling_sprite_path, "FallingSprite") as Sprite2D
	_seed_spin_box = _resolve_node(seed_spin_box_path, "SeedSpinBox") as SpinBox
	_brush_radius_spin_box = _resolve_node(brush_radius_spin_box_path, "BrushRadiusSpinBox") as SpinBox
	_brush_damage_spin_box = _resolve_node(brush_damage_spin_box_path, "BrushDamageSpinBox") as SpinBox
	_gravity_toggle = _resolve_node(gravity_toggle_path, "GravityToggle") as CheckBox
	_reset_button = _resolve_node(reset_button_path, "ResetButton") as Button
	_gravity_step_button = _resolve_node(gravity_step_button_path, "GravityStepButton") as Button
	_status_label = _resolve_node(status_label_path, "StatusLabel") as Label


func _resolve_node(path: NodePath, fallback_name: String) -> Node:
	var node := get_node_or_null(path)
	if node != null:
		return node
	return find_child(fallback_name, true, false)


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
