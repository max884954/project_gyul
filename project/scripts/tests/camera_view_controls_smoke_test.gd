extends SceneTree

const DUNGEON_SCENE := "res://scenes/dungeon_grid_view.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_wasd_camera_view_selection()

	if _failures.is_empty():
		print("Camera view controls smoke test passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_wasd_camera_view_selection() -> void:
	var scene := load(DUNGEON_SCENE) as PackedScene
	_expect(scene != null, "Dungeon scene should load for camera control test.")
	if scene == null:
		return

	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame

	_send_key(instance, KEY_W)
	_expect(int(instance.get("_camera_view_index")) == 2, "W should select the upper camera view.")
	_send_key(instance, KEY_A)
	_expect(int(instance.get("_camera_view_index")) == 1, "A should select the left camera view.")
	_send_key(instance, KEY_S)
	_expect(int(instance.get("_camera_view_index")) == 0, "S should select the lower camera view.")
	_send_key(instance, KEY_D)
	_expect(int(instance.get("_camera_view_index")) == 3, "D should select the right camera view.")
	_send_key(instance, KEY_Q)
	_expect(int(instance.get("_camera_view_index")) == 0, "Q should keep rotating counter-clockwise from direct views.")
	_send_key(instance, KEY_E)
	_expect(int(instance.get("_camera_view_index")) == 3, "E should keep rotating clockwise from direct views.")

	root.remove_child(instance)
	instance.queue_free()
	await process_frame


func _send_key(instance: Node, keycode: int) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	instance.call("_handle_key", event)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
