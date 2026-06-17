@tool
class_name PixelOreDebugViewer
extends Node2D

const ConfigScript := preload("res://DIG/pixel_ore_damage/PixelOreDamageConfig.gd")
const GeneratorScript := preload("res://DIG/pixel_ore_damage/PixelOreDamageGenerator.gd")
const SolverScript := preload("res://DIG/pixel_ore_damage/PixelOreDamageSolver.gd")
const RendererScript := preload("res://DIG/pixel_ore_damage/PixelOreRenderer.gd")

@export_group("Inputs")
@export var albedo_texture: Texture2D:
	set(value):
		albedo_texture = value
		_mark_grid_dirty()
@export var config: Resource:
	set(value):
		config = value
		_mark_grid_dirty()

@export_group("Damage")
@export var ore_seed := 12345:
	set(value):
		ore_seed = value
		_mark_grid_dirty()
@export_range(0.0, 1.0, 0.01) var damage_ratio := 0.0:
	set(value):
		damage_ratio = clampf(value, 0.0, 1.0)
		_request_refresh()
@export var auto_refresh := true
@export var show_previews := true:
	set(value):
		show_previews = value
		_request_refresh()

@export_group("Scene Nodes")
@export_node_path("Sprite2D") var target_sprite_path: NodePath = ^"OreSprite"
@export_node_path("Sprite2D") var damage_field_sprite_path: NodePath = ^"DamageFieldSprite"
@export_node_path("Sprite2D") var mask_sprite_path: NodePath = ^"MaskSprite"
@export_node_path("Sprite2D") var combined_sprite_path: NodePath = ^"CombinedSprite"
@export_node_path("HSlider") var damage_slider_path: NodePath = ^"DamageSlider"
@export_node_path("SpinBox") var seed_spin_box_path: NodePath = ^"SeedSpinBox"
@export_node_path("Label") var status_label_path: NodePath = ^"StatusLabel"

var _generator = GeneratorScript.new()
var _solver = SolverScript.new()
var _renderer = RendererScript.new()
var _base_grid: Dictionary = {}
var _runtime_grid: Dictionary = {}
var _grid_dirty := true
var _refresh_queued := false
var _last_config_fingerprint := ""
var _target_sprite: Sprite2D
var _damage_field_sprite: Sprite2D
var _mask_sprite: Sprite2D
var _combined_sprite: Sprite2D
var _damage_slider: HSlider
var _seed_spin_box: SpinBox
var _status_label: Label


func _ready() -> void:
	if config == null:
		config = ConfigScript.new()
	_resolve_scene_nodes()
	_setup_controls()
	_mark_grid_dirty()
	_refresh_now()
	set_process(true)


func _process(_delta: float) -> void:
	if not auto_refresh:
		return

	var config_fingerprint := _make_config_fingerprint()
	if config_fingerprint != _last_config_fingerprint:
		_last_config_fingerprint = config_fingerprint
		_mark_grid_dirty()

	if _refresh_queued:
		_refresh_now()


func refresh() -> void:
	_mark_grid_dirty()
	_refresh_now()


func _setup_controls() -> void:
	if _damage_slider != null:
		_damage_slider.min_value = 0.0
		_damage_slider.max_value = 1.0
		_damage_slider.step = 0.01
		_damage_slider.value = damage_ratio
		if not _damage_slider.value_changed.is_connected(_on_damage_slider_value_changed):
			_damage_slider.value_changed.connect(_on_damage_slider_value_changed)

	if _seed_spin_box != null:
		_seed_spin_box.min_value = 0.0
		_seed_spin_box.max_value = 999999.0
		_seed_spin_box.step = 1.0
		_seed_spin_box.value = ore_seed
		if not _seed_spin_box.value_changed.is_connected(_on_seed_spin_box_value_changed):
			_seed_spin_box.value_changed.connect(_on_seed_spin_box_value_changed)


func _mark_grid_dirty() -> void:
	_grid_dirty = true
	_request_refresh()


func _request_refresh() -> void:
	if not is_inside_tree():
		return
	if auto_refresh:
		_refresh_queued = true


func _refresh_now() -> void:
	_refresh_queued = false
	_resolve_scene_nodes()

	if albedo_texture == null:
		_set_status("Missing albedo texture.")
		return

	var albedo_image := albedo_texture.get_image()
	if albedo_image == null or albedo_image.is_empty():
		_set_status("Albedo image is empty.")
		return

	if config == null:
		config = ConfigScript.new()
	config.sanitize()

	if _grid_dirty:
		_base_grid = _generator.create_base_grid(albedo_image, config)
		_generator.generate_damage_field(_base_grid, ore_seed, config)
		_grid_dirty = false

	_runtime_grid = _duplicate_grid(_base_grid)
	_solver.apply_damage_ratio(_runtime_grid, damage_ratio, config)
	_solver.solve_connectivity(_runtime_grid, config)

	_apply_output_textures()
	_sync_controls()
	_set_status("Damage %.2f | Seed %d | Grid %dx%d | Solid %d | Main %d | Loose %d" % [
		damage_ratio,
		ore_seed,
		config.grid_size.x,
		config.grid_size.y,
		int(_base_grid.get("solid_count", 0)),
		int(_runtime_grid.get("main_component_size", 0)),
		int(_runtime_grid.get("loose_component_count", 0)),
	])


func _apply_output_textures() -> void:
	var final_image := _renderer.render_final(_runtime_grid, config)
	_set_sprite_texture(_target_sprite, final_image, true)
	_set_sprite_texture(_damage_field_sprite, _renderer.render_damage_field(_base_grid, config), show_previews)
	_set_sprite_texture(_mask_sprite, _renderer.render_mask_preview(_runtime_grid), show_previews)
	_set_sprite_texture(_combined_sprite, _renderer.render_combined_preview(_runtime_grid, config), show_previews)


func _set_sprite_texture(sprite: Sprite2D, image: Image, should_show: bool) -> void:
	if sprite == null:
		return
	sprite.visible = should_show
	if not should_show or image == null or image.is_empty():
		return
	sprite.texture = ImageTexture.create_from_image(image)


func _duplicate_grid(source: Dictionary) -> Dictionary:
	return source.duplicate(true)


func _sync_controls() -> void:
	if _damage_slider != null and not is_equal_approx(float(_damage_slider.value), damage_ratio):
		_damage_slider.set_value_no_signal(damage_ratio)
	if _seed_spin_box != null and int(_seed_spin_box.value) != ore_seed:
		_seed_spin_box.set_value_no_signal(ore_seed)


func _on_damage_slider_value_changed(value: float) -> void:
	damage_ratio = value
	_refresh_now()


func _on_seed_spin_box_value_changed(value: float) -> void:
	ore_seed = int(value)
	_mark_grid_dirty()
	_refresh_now()


func _resolve_scene_nodes() -> void:
	_target_sprite = _resolve_node(target_sprite_path, "OreSprite") as Sprite2D
	_damage_field_sprite = _resolve_node(damage_field_sprite_path, "DamageFieldSprite") as Sprite2D
	_mask_sprite = _resolve_node(mask_sprite_path, "MaskSprite") as Sprite2D
	_combined_sprite = _resolve_node(combined_sprite_path, "CombinedSprite") as Sprite2D
	_damage_slider = _resolve_node(damage_slider_path, "DamageSlider") as HSlider
	_seed_spin_box = _resolve_node(seed_spin_box_path, "SeedSpinBox") as SpinBox
	_status_label = _resolve_node(status_label_path, "StatusLabel") as Label


func _resolve_node(path: NodePath, fallback_name: String) -> Node:
	var node := get_node_or_null(path)
	if node != null:
		return node
	return find_child(fallback_name, true, false)


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _make_config_fingerprint() -> String:
	if config == null:
		return "<null>"

	return "|".join([
		str(config.grid_size),
		str(config.base_alpha_threshold),
		str(config.noise_strength),
		str(config.edge_weakness),
		str(config.damaged_state_margin),
		str(config.weak_band_count_min),
		str(config.weak_band_count_max),
		str(config.weak_band_width_min),
		str(config.weak_band_width_max),
		str(config.weak_band_strength_min),
		str(config.weak_band_strength_max),
		str(config.weak_core_count_min),
		str(config.weak_core_count_max),
		str(config.weak_core_radius_min),
		str(config.weak_core_radius_max),
		str(config.weak_core_strength),
		str(config.loose_piece_min_size),
		str(config.body_color),
		str(config.damaged_color),
		str(config.edge_color),
		str(config.empty_color),
		str(config.damage_field_low_color),
		str(config.damage_field_high_color),
		str(show_previews),
	])
