extends Node

enum ControlledLight {
	OMNI,
	DIRECTIONAL,
}

@export var camera: Camera3D
@export var omni_light: OmniLight3D
@export var directional_light: DirectionalLight3D
@export var status_label: Label
@export var controls_enabled := true
@export_range(1, 32, 1) var pixel_step := 1
@export_range(0.1, 100.0, 0.1) var omni_depth := 7.0
@export_range(-180.0, 180.0, 1.0) var directional_yaw_min := -80.0
@export_range(-180.0, 180.0, 1.0) var directional_yaw_max := 80.0
@export_range(-89.0, 89.0, 1.0) var directional_pitch_min := -75.0
@export_range(-89.0, 89.0, 1.0) var directional_pitch_max := 15.0

var controlled_light := ControlledLight.OMNI
var _mouse_position := Vector2.ZERO


func _ready() -> void:
	if camera == null or omni_light == null or directional_light == null:
		push_error("LightDirectionController: camera and both lights are required.")
		set_process_input(false)
		return

	_mouse_position = get_viewport().get_visible_rect().size * 0.5
	_update_status()
	_apply_mouse_control()


func _input(event: InputEvent) -> void:
	if not controls_enabled:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			controlled_light = ControlledLight.OMNI
			_update_status()
			_apply_mouse_control()
		elif event.keycode == KEY_2:
			controlled_light = ControlledLight.DIRECTIONAL
			directional_light.visible = true
			_update_status()
			_apply_mouse_control()
	elif event is InputEventMouseMotion:
		_mouse_position = event.position
		_apply_mouse_control()


func _apply_mouse_control() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	_mouse_position = _quantize_mouse_position(_mouse_position, viewport_size)

	if controlled_light == ControlledLight.OMNI:
		omni_light.global_position = camera.project_position(_mouse_position, omni_depth)
	else:
		var normalized := _mouse_position / viewport_size
		var yaw := lerpf(directional_yaw_min, directional_yaw_max, normalized.x)
		var pitch := lerpf(directional_pitch_min, directional_pitch_max, normalized.y)
		directional_light.rotation_degrees = Vector3(pitch, yaw, 0.0)


func _quantize_mouse_position(mouse_position: Vector2, viewport_size: Vector2) -> Vector2:
	var step := float(maxi(pixel_step, 1))
	var clamped := mouse_position.clamp(Vector2.ZERO, viewport_size)
	return (clamped / step).round() * step


func _update_status() -> void:
	if status_label == null:
		return

	var current := "OmniLight" if controlled_light == ControlledLight.OMNI else "DirectionalLight"
	status_label.text = "[1] Omni  [2] Directional | %s | Hard shadows | Step %d px" % [
		current,
		pixel_step,
	]
