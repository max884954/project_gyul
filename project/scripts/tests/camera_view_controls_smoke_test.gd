extends SceneTree

const DUNGEON_SCENE := "res://scenes/dungeon_grid_view.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_wasd_camera_ground_pan()

	if _failures.is_empty():
		print("Camera view controls smoke test passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_wasd_camera_ground_pan() -> void:
	var scene := load(DUNGEON_SCENE) as PackedScene
	_expect(scene != null, "Dungeon scene should load for camera control test.")
	if scene == null:
		return

	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame

	var initial_view := int(instance.get("_camera_view_index"))
	var initial_target := instance.get("_camera_target") as Vector3
	instance.call("_pan_camera", Vector2.UP, 0.5)
	var target_after_w := instance.get("_camera_target") as Vector3
	_expect(int(instance.get("_camera_view_index")) == initial_view, "Continuous W pan should not change the camera view.")
	_expect(not target_after_w.is_equal_approx(initial_target), "W should move the camera target on the ground plane.")
	_expect(is_equal_approx(target_after_w.y, initial_target.y), "W should keep camera panning parallel to the ground.")

	instance.call("_pan_camera", Vector2.LEFT, 0.5)
	var target_after_a := instance.get("_camera_target") as Vector3
	_expect(int(instance.get("_camera_view_index")) == initial_view, "Continuous A pan should not change the camera view.")
	_expect(not target_after_a.is_equal_approx(target_after_w), "A should move the camera target on the ground plane.")
	_expect(is_equal_approx(target_after_a.y, initial_target.y), "A should keep camera panning parallel to the ground.")

	instance.call("_pan_camera", Vector2.DOWN, 0.5)
	var target_after_s := instance.get("_camera_target") as Vector3
	_expect(int(instance.get("_camera_view_index")) == initial_view, "Continuous S pan should not change the camera view.")
	_expect(not target_after_s.is_equal_approx(target_after_a), "S should move the camera target on the ground plane.")
	_expect(is_equal_approx(target_after_s.y, initial_target.y), "S should keep camera panning parallel to the ground.")

	instance.call("_pan_camera", Vector2.RIGHT, 0.5)
	var target_after_d := instance.get("_camera_target") as Vector3
	_expect(int(instance.get("_camera_view_index")) == initial_view, "Continuous D pan should not change the camera view.")
	_expect(not target_after_d.is_equal_approx(target_after_s), "D should move the camera target on the ground plane.")
	_expect(is_equal_approx(target_after_d.y, initial_target.y), "D should keep camera panning parallel to the ground.")

	_send_key(instance, KEY_Q)
	_expect(int(instance.get("_camera_view_index")) == 1, "Q should keep rotating counter-clockwise.")
	_send_key(instance, KEY_E)
	_expect(int(instance.get("_camera_view_index")) == initial_view, "E should keep rotating clockwise.")

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
