extends Node

@export var camera: Camera3D
@export var material: ShaderMaterial
@export var receiver_root: Node
@export var lock_camera_parameters := true
@export var apply_material_to_receivers := true
@export var configure_pixel_viewport := true
@export var projection_scale := Vector2.ONE
@export var projection_offset := Vector2.ZERO

var _initial_transform: Transform3D
var _initial_projection: Camera3D.ProjectionType
var _initial_size: float
var _initial_near: float
var _initial_far: float
var _initial_keep_aspect: Camera3D.KeepAspect
var _initial_h_offset: float
var _initial_v_offset: float
var _warned_changes: Dictionary = {}


func _ready() -> void:
	if camera == null:
		push_error("CameraMappingController: camera is missing.")
		set_process(false)
		return

	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		push_error("CameraMappingController requires an orthogonal Camera3D.")
		set_process(false)
		return

	_cache_camera_parameters()
	_sync_material_parameters()

	if apply_material_to_receivers:
		_apply_shared_material()

	if configure_pixel_viewport:
		_configure_viewport()


func _process(_delta: float) -> void:
	_sync_material_parameters()

	if not lock_camera_parameters:
		return

	_restore_camera_parameter("transform", camera.global_transform != _initial_transform)
	_restore_camera_parameter("projection", camera.projection != _initial_projection)
	_restore_camera_parameter("size", not is_equal_approx(camera.size, _initial_size))
	_restore_camera_parameter("near", not is_equal_approx(camera.near, _initial_near))
	_restore_camera_parameter("far", not is_equal_approx(camera.far, _initial_far))
	_restore_camera_parameter("keep_aspect", camera.keep_aspect != _initial_keep_aspect)
	_restore_camera_parameter("h_offset", not is_equal_approx(camera.h_offset, _initial_h_offset))
	_restore_camera_parameter("v_offset", not is_equal_approx(camera.v_offset, _initial_v_offset))


func _cache_camera_parameters() -> void:
	_initial_transform = camera.global_transform
	_initial_projection = camera.projection
	_initial_size = camera.size
	_initial_near = camera.near
	_initial_far = camera.far
	_initial_keep_aspect = camera.keep_aspect
	_initial_h_offset = camera.h_offset
	_initial_v_offset = camera.v_offset


func _sync_material_parameters() -> void:
	if material == null:
		return

	material.set_shader_parameter("projection_scale", projection_scale)
	material.set_shader_parameter("projection_offset", projection_offset)


func _apply_shared_material() -> void:
	if material == null:
		push_warning("CameraMappingController: material is missing.")
		return

	var root := receiver_root if receiver_root != null else get_parent()
	if root == null:
		return

	for node in root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = material


func _configure_viewport() -> void:
	var viewport := get_viewport()
	viewport.msaa_2d = Viewport.MSAA_DISABLED
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = false
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = 1.0


func _restore_camera_parameter(parameter: StringName, changed: bool) -> void:
	if not changed:
		return

	if not _warned_changes.has(parameter):
		push_warning("CameraMappingController: restored modified camera parameter '%s'." % parameter)
		_warned_changes[parameter] = true

	match parameter:
		"transform":
			camera.global_transform = _initial_transform
		"projection":
			camera.projection = _initial_projection
		"size":
			camera.size = _initial_size
		"near":
			camera.near = _initial_near
		"far":
			camera.far = _initial_far
		"keep_aspect":
			camera.keep_aspect = _initial_keep_aspect
		"h_offset":
			camera.h_offset = _initial_h_offset
		"v_offset":
			camera.v_offset = _initial_v_offset
