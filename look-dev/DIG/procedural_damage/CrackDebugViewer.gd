@tool
class_name CrackDebugViewer
extends Node2D

const ConfigScript := preload("res://DIG/procedural_damage/CrackDamageConfig.gd")
const GeneratorScript := preload("res://DIG/procedural_damage/CrackDamageGenerator.gd")
const RendererScript := preload("res://DIG/procedural_damage/CrackDamageRenderer.gd")

@export_group("Inputs")
@export var albedo_texture: Texture2D:
	set(value):
		albedo_texture = value
		_mark_plan_dirty()
@export var normal_texture: Texture2D:
	set(value):
		normal_texture = value
		_request_refresh()
@export var config: Resource:
	set(value):
		config = value
		_mark_plan_dirty()

@export_group("Damage")
@export var crack_seed := 12345:
	set(value):
		crack_seed = value
		_mark_plan_dirty()
@export_range(0.0, 1.0, 0.01) var damage_ratio := 0.0:
	set(value):
		damage_ratio = clampf(value, 0.0, 1.0)
		_request_refresh()
@export var auto_refresh := true
@export var show_mask_previews := true:
	set(value):
		show_mask_previews = value
		_request_refresh()
@export var show_crack_layer := true:
	set(value):
		show_crack_layer = value
		_request_refresh()
@export var show_damage_layer := true:
	set(value):
		show_damage_layer = value
		_request_refresh()

@export_group("Scene Nodes")
@export_node_path("Sprite2D") var target_sprite_path: NodePath = ^"OreSprite"
@export_node_path("Sprite2D") var crack_mask_sprite_path: NodePath = ^"CrackMaskSprite"
@export_node_path("Sprite2D") var damage_mask_sprite_path: NodePath = ^"DamageMaskSprite"
@export_node_path("Sprite2D") var combined_mask_sprite_path: NodePath = ^"CombinedMaskSprite"
@export_node_path("HSlider") var damage_slider_path: NodePath = ^"DamageSlider"
@export_node_path("SpinBox") var seed_spin_box_path: NodePath = ^"SeedSpinBox"
@export_node_path("SpinBox") var main_count_spin_box_path: NodePath = ^"MainCountSpinBox"
@export_node_path("SpinBox") var energy_spin_box_path: NodePath = ^"EnergySpinBox"
@export_node_path("SpinBox") var branch_chance_spin_box_path: NodePath = ^"BranchChanceSpinBox"
@export_node_path("CheckBox") var crack_toggle_path: NodePath = ^"CrackToggle"
@export_node_path("CheckBox") var damage_toggle_path: NodePath = ^"DamageToggle"
@export_node_path("ColorPickerButton") var crack_color_picker_path: NodePath = ^"CrackColorPicker"
@export_node_path("OptionButton") var crack_mode_option_path: NodePath = ^"CrackModeOption"
@export_node_path("SpinBox") var voronoi_site_count_spin_box_path: NodePath = ^"VoronoiSiteCountSpinBox"
@export_node_path("SpinBox") var voronoi_edge_threshold_spin_box_path: NodePath = ^"VoronoiEdgeThresholdSpinBox"
@export_node_path("Label") var status_label_path: NodePath = ^"StatusLabel"

var base_mask: Image
var crack_mask: Image
var damage_mask: Image

var _generator = GeneratorScript.new()
var _renderer = RendererScript.new()
var _crack_plan: Dictionary = {}
var _runtime_canvas_texture: CanvasTexture
var _plan_dirty := true
var _refresh_queued := false
var _last_config_fingerprint := ""
var _target_sprite: Sprite2D
var _crack_mask_sprite: Sprite2D
var _damage_mask_sprite: Sprite2D
var _combined_mask_sprite: Sprite2D
var _damage_slider: HSlider
var _seed_spin_box: SpinBox
var _main_count_spin_box: SpinBox
var _energy_spin_box: SpinBox
var _branch_chance_spin_box: SpinBox
var _crack_toggle: CheckBox
var _damage_toggle: CheckBox
var _crack_color_picker: ColorPickerButton
var _crack_mode_option: OptionButton
var _voronoi_site_count_spin_box: SpinBox
var _voronoi_edge_threshold_spin_box: SpinBox
var _status_label: Label


func _ready() -> void:
	if config == null:
		config = ConfigScript.new()

	_resolve_scene_nodes()
	_setup_slider()
	_setup_crack_controls()
	_setup_display_controls()
	_setup_voronoi_controls()
	_mark_plan_dirty()
	_refresh_now()
	set_process(true)


func _process(_delta: float) -> void:
	if not auto_refresh:
		return

	var config_fingerprint := _make_config_fingerprint()
	if config_fingerprint != _last_config_fingerprint:
		_last_config_fingerprint = config_fingerprint
		_mark_plan_dirty()

	if _refresh_queued:
		_refresh_now()


func refresh() -> void:
	_mark_plan_dirty()


func _setup_slider() -> void:
	if _damage_slider == null:
		return

	_damage_slider.min_value = 0.0
	_damage_slider.max_value = 1.0
	_damage_slider.step = 0.01
	_damage_slider.value = damage_ratio

	if not _damage_slider.value_changed.is_connected(_on_damage_slider_value_changed):
		_damage_slider.value_changed.connect(_on_damage_slider_value_changed)


func _setup_crack_controls() -> void:
	if config == null:
		config = ConfigScript.new()

	if _seed_spin_box != null:
		_seed_spin_box.min_value = 0.0
		_seed_spin_box.max_value = 999999.0
		_seed_spin_box.step = 1.0
		_seed_spin_box.value = crack_seed
		if not _seed_spin_box.value_changed.is_connected(_on_seed_spin_box_value_changed):
			_seed_spin_box.value_changed.connect(_on_seed_spin_box_value_changed)

	if _main_count_spin_box != null:
		_main_count_spin_box.min_value = 1.0
		_main_count_spin_box.max_value = 8.0
		_main_count_spin_box.step = 1.0
		_main_count_spin_box.value = config.main_crack_count_min
		if not _main_count_spin_box.value_changed.is_connected(_on_main_count_spin_box_value_changed):
			_main_count_spin_box.value_changed.connect(_on_main_count_spin_box_value_changed)

	if _energy_spin_box != null:
		_energy_spin_box.min_value = 4.0
		_energy_spin_box.max_value = 48.0
		_energy_spin_box.step = 1.0
		_energy_spin_box.value = roundf((config.main_crack_energy_min + config.main_crack_energy_max) * 0.5)
		if not _energy_spin_box.value_changed.is_connected(_on_energy_spin_box_value_changed):
			_energy_spin_box.value_changed.connect(_on_energy_spin_box_value_changed)

	if _branch_chance_spin_box != null:
		_branch_chance_spin_box.min_value = 0.0
		_branch_chance_spin_box.max_value = 50.0
		_branch_chance_spin_box.step = 1.0
		_branch_chance_spin_box.value = roundf(config.main_branch_chance * 100.0)
		if not _branch_chance_spin_box.value_changed.is_connected(_on_branch_chance_spin_box_value_changed):
			_branch_chance_spin_box.value_changed.connect(_on_branch_chance_spin_box_value_changed)


func _setup_display_controls() -> void:
	if config == null:
		config = ConfigScript.new()

	if _crack_toggle != null:
		_crack_toggle.button_pressed = show_crack_layer
		if not _crack_toggle.toggled.is_connected(_on_crack_toggle_toggled):
			_crack_toggle.toggled.connect(_on_crack_toggle_toggled)

	if _damage_toggle != null:
		_damage_toggle.button_pressed = show_damage_layer
		if not _damage_toggle.toggled.is_connected(_on_damage_toggle_toggled):
			_damage_toggle.toggled.connect(_on_damage_toggle_toggled)

	if _crack_color_picker != null:
		_crack_color_picker.color = config.crack_color
		if not _crack_color_picker.color_changed.is_connected(_on_crack_color_changed):
			_crack_color_picker.color_changed.connect(_on_crack_color_changed)


func _setup_voronoi_controls() -> void:
	if config == null:
		config = ConfigScript.new()

	if _crack_mode_option != null:
		if _crack_mode_option.item_count == 0:
			_crack_mode_option.add_item("Random Walk", ConfigScript.CrackPatternMode.RANDOM_WALK)
			_crack_mode_option.add_item("Voronoi", ConfigScript.CrackPatternMode.VORONOI)
		_crack_mode_option.select(_item_index_for_mode(config.crack_pattern_mode))
		if not _crack_mode_option.item_selected.is_connected(_on_crack_mode_selected):
			_crack_mode_option.item_selected.connect(_on_crack_mode_selected)

	if _voronoi_site_count_spin_box != null:
		_voronoi_site_count_spin_box.min_value = 2.0
		_voronoi_site_count_spin_box.max_value = 32.0
		_voronoi_site_count_spin_box.step = 1.0
		_voronoi_site_count_spin_box.value = config.voronoi_site_count
		if not _voronoi_site_count_spin_box.value_changed.is_connected(_on_voronoi_site_count_changed):
			_voronoi_site_count_spin_box.value_changed.connect(_on_voronoi_site_count_changed)

	if _voronoi_edge_threshold_spin_box != null:
		_voronoi_edge_threshold_spin_box.min_value = 0.1
		_voronoi_edge_threshold_spin_box.max_value = 8.0
		_voronoi_edge_threshold_spin_box.step = 0.1
		_voronoi_edge_threshold_spin_box.value = config.voronoi_edge_threshold
		if not _voronoi_edge_threshold_spin_box.value_changed.is_connected(_on_voronoi_edge_threshold_changed):
			_voronoi_edge_threshold_spin_box.value_changed.connect(_on_voronoi_edge_threshold_changed)


func _item_index_for_mode(mode: int) -> int:
	if _crack_mode_option == null:
		return 0
	for index in _crack_mode_option.item_count:
		if _crack_mode_option.get_item_id(index) == mode:
			return index
	return 0


func _on_damage_slider_value_changed(value: float) -> void:
	damage_ratio = value
	_refresh_now()


func _on_seed_spin_box_value_changed(value: float) -> void:
	crack_seed = int(value)
	_mark_plan_dirty()
	_refresh_now()


func _on_main_count_spin_box_value_changed(value: float) -> void:
	var count := clampi(int(value), 1, 8)
	config.main_crack_count_min = count
	config.main_crack_count_max = count
	_mark_plan_dirty()
	_refresh_now()


func _on_energy_spin_box_value_changed(value: float) -> void:
	var energy := clampf(value, 4.0, 48.0)
	config.main_crack_energy_min = maxf(1.0, energy - 2.0)
	config.main_crack_energy_max = energy + 2.0
	_mark_plan_dirty()
	_refresh_now()


func _on_branch_chance_spin_box_value_changed(value: float) -> void:
	config.main_branch_chance = clampf(value / 100.0, 0.0, 0.5)
	_mark_plan_dirty()
	_refresh_now()


func _on_crack_toggle_toggled(enabled: bool) -> void:
	show_crack_layer = enabled
	_refresh_now()


func _on_damage_toggle_toggled(enabled: bool) -> void:
	show_damage_layer = enabled
	_refresh_now()


func _on_crack_color_changed(color: Color) -> void:
	config.crack_color = color
	_request_refresh()
	_refresh_now()


func _on_crack_mode_selected(index: int) -> void:
	if _crack_mode_option == null:
		return
	config.crack_pattern_mode = _crack_mode_option.get_item_id(index)
	_request_refresh()
	_refresh_now()


func _on_voronoi_site_count_changed(value: float) -> void:
	config.voronoi_site_count = clampi(int(value), 2, 32)
	_mark_plan_dirty()
	_refresh_now()


func _on_voronoi_edge_threshold_changed(value: float) -> void:
	config.voronoi_edge_threshold = clampf(value, 0.1, 8.0)
	_request_refresh()
	_refresh_now()


func _mark_plan_dirty() -> void:
	_plan_dirty = true
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

	var normal_image := _get_normal_image(albedo_image.get_size())
	if normal_image == null:
		_set_status("Normal image is missing or invalid.")
		return

	if config == null:
		config = ConfigScript.new()
	config.sanitize()

	if _plan_dirty:
		base_mask = _generator.create_base_mask(albedo_image, config.base_alpha_threshold)
		_crack_plan = _generator.generate_plan(base_mask, crack_seed, config)
		_plan_dirty = false

	var masks := _renderer.render_masks(base_mask, _crack_plan, damage_ratio, config)
	crack_mask = masks["crack_mask"]
	damage_mask = masks["damage_mask"]

	var diffuse_image := _renderer.compose_diffuse(albedo_image, crack_mask, damage_mask, config, show_crack_layer, show_damage_layer)
	var output_normal_image := _renderer.compose_normal(normal_image, damage_mask, config, show_damage_layer)
	_apply_output_textures(diffuse_image, output_normal_image)
	_apply_mask_previews()
	_sync_slider()
	_set_status("Damage %.2f | %s | Seed %d | Cores %d | Sites %d | Branches %d | Chips %d | Solid %d | Crack px %d | Damage px %d | %s" % [
		damage_ratio,
		_crack_mode_name(),
		crack_seed,
		config.main_crack_count_min,
		_crack_plan.get("voronoi_sites", []).size(),
		_crack_plan.get("branches", []).size(),
		_crack_plan.get("chip_regions", []).size(),
		_count_mask_pixels(base_mask),
		_count_mask_pixels(crack_mask),
		_count_mask_pixels(damage_mask),
		"CanvasTexture",
	])


func _get_normal_image(expected_size: Vector2i) -> Image:
	if normal_texture == null:
		var flat_image := Image.create(expected_size.x, expected_size.y, false, Image.FORMAT_RGBA8)
		flat_image.fill(config.flat_normal_color if config != null else Color(0.5, 0.5, 1.0, 1.0))
		return flat_image

	var source_image := normal_texture.get_image()
	if source_image == null or source_image.is_empty():
		return null

	if source_image.get_size() != expected_size:
		source_image.resize(expected_size.x, expected_size.y, Image.INTERPOLATE_NEAREST)

	return source_image


func _apply_output_textures(diffuse_image: Image, normal_image: Image) -> void:
	if _target_sprite == null:
		_set_status("Missing target Sprite2D.")
		return

	var diffuse_texture := ImageTexture.create_from_image(diffuse_image)
	var normal_output_texture := ImageTexture.create_from_image(normal_image)

	_runtime_canvas_texture = CanvasTexture.new()
	_runtime_canvas_texture.diffuse_texture = diffuse_texture
	_runtime_canvas_texture.normal_texture = normal_output_texture
	_target_sprite.material = null
	_target_sprite.texture = _runtime_canvas_texture


func _apply_mask_previews() -> void:
	var previews_visible := show_mask_previews
	_set_sprite_preview(_crack_mask_sprite, _make_single_mask_preview(crack_mask, Color(1.0, 1.0, 1.0, 1.0)), previews_visible)
	_set_sprite_preview(_damage_mask_sprite, _make_single_mask_preview(damage_mask, Color(1.0, 1.0, 1.0, 1.0)), previews_visible)
	_set_sprite_preview(_combined_mask_sprite, _make_combined_mask_preview(), previews_visible)


func _set_sprite_preview(sprite: Sprite2D, image: Image, preview_visible: bool) -> void:
	if sprite == null:
		return
	sprite.visible = preview_visible
	if not preview_visible or image == null:
		return
	sprite.texture = ImageTexture.create_from_image(image)


func _make_single_mask_preview(mask: Image, tint: Color) -> Image:
	if mask == null or mask.is_empty():
		return null

	var image := Image.create(mask.get_width(), mask.get_height(), false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 1.0))
	for y in mask.get_height():
		for x in mask.get_width():
			if mask.get_pixel(x, y).r > 0.5:
				image.set_pixel(x, y, tint)
	return image


func _make_combined_mask_preview() -> Image:
	if crack_mask == null or damage_mask == null or crack_mask.is_empty() or damage_mask.is_empty():
		return null

	var image := Image.create(crack_mask.get_width(), crack_mask.get_height(), false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 1.0))
	for y in image.get_height():
		for x in image.get_width():
			var crack := crack_mask.get_pixel(x, y).r > 0.5
			var damage := damage_mask.get_pixel(x, y).r > 0.5
			if damage:
				image.set_pixel(x, y, Color(1.0, 0.16, 0.08, 1.0))
			elif crack:
				image.set_pixel(x, y, Color(1.0, 0.88, 0.22, 1.0))
	return image


func _sync_slider() -> void:
	if _damage_slider == null:
		return
	if not is_equal_approx(float(_damage_slider.value), damage_ratio):
		_damage_slider.set_value_no_signal(damage_ratio)


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _resolve_scene_nodes() -> void:
	_target_sprite = _resolve_node(target_sprite_path, "OreSprite") as Sprite2D
	_crack_mask_sprite = _resolve_node(crack_mask_sprite_path, "CrackMaskSprite") as Sprite2D
	_damage_mask_sprite = _resolve_node(damage_mask_sprite_path, "DamageMaskSprite") as Sprite2D
	_combined_mask_sprite = _resolve_node(combined_mask_sprite_path, "CombinedMaskSprite") as Sprite2D
	_damage_slider = _resolve_node(damage_slider_path, "DamageSlider") as HSlider
	_seed_spin_box = _resolve_node(seed_spin_box_path, "SeedSpinBox") as SpinBox
	_main_count_spin_box = _resolve_node(main_count_spin_box_path, "MainCountSpinBox") as SpinBox
	_energy_spin_box = _resolve_node(energy_spin_box_path, "EnergySpinBox") as SpinBox
	_branch_chance_spin_box = _resolve_node(branch_chance_spin_box_path, "BranchChanceSpinBox") as SpinBox
	_crack_toggle = _resolve_node(crack_toggle_path, "CrackToggle") as CheckBox
	_damage_toggle = _resolve_node(damage_toggle_path, "DamageToggle") as CheckBox
	_crack_color_picker = _resolve_node(crack_color_picker_path, "CrackColorPicker") as ColorPickerButton
	_crack_mode_option = _resolve_node(crack_mode_option_path, "CrackModeOption") as OptionButton
	_voronoi_site_count_spin_box = _resolve_node(voronoi_site_count_spin_box_path, "VoronoiSiteCountSpinBox") as SpinBox
	_voronoi_edge_threshold_spin_box = _resolve_node(voronoi_edge_threshold_spin_box_path, "VoronoiEdgeThresholdSpinBox") as SpinBox
	_status_label = _resolve_node(status_label_path, "StatusLabel") as Label


func _resolve_node(path: NodePath, fallback_name: String) -> Node:
	var node := get_node_or_null(path)
	if node != null:
		return node
	return find_child(fallback_name, true, false)


func _count_mask_pixels(mask: Image) -> int:
	if mask == null or mask.is_empty():
		return 0

	var count := 0
	for y in mask.get_height():
		for x in mask.get_width():
			if mask.get_pixel(x, y).r > 0.5:
				count += 1
	return count


func _crack_mode_name() -> String:
	if config == null:
		return "Random Walk"
	if int(config.crack_pattern_mode) == int(ConfigScript.CrackPatternMode.VORONOI):
		return "Voronoi"
	return "Random Walk"


func _make_config_fingerprint() -> String:
	if config == null:
		return "<null>"

	return "|".join([
		str(config.base_alpha_threshold),
		str(config.main_crack_count_min),
		str(config.main_crack_count_max),
		str(config.main_crack_energy_min),
		str(config.main_crack_energy_max),
		str(config.direction_jitter_degrees),
		str(config.crack_thickness),
		str(config.crack_color),
		str(config.crack_pattern_mode),
		str(config.voronoi_site_count),
		str(config.voronoi_edge_threshold),
		str(config.voronoi_start_damage),
		str(config.max_generation),
		str(config.main_branch_chance),
		str(config.child_branch_chance),
		str(config.max_branch_count),
		str(config.chip_count_min),
		str(config.chip_count_max),
		str(config.chip_radius_min),
		str(config.chip_radius_max),
		str(config.chip_edge_noise),
		str(config.damaged_pixels_transparent),
		str(config.damaged_pixel_color),
		str(show_crack_layer),
		str(show_damage_layer),
		str(config.crack_start_damage),
		str(config.branch_start_damage),
		str(config.chip_start_damage),
		str(config.damaged_normal_transparent),
		str(config.flat_normal_color),
	])
