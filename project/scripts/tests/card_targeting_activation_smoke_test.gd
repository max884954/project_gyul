extends SceneTree

const DUNGEON_SCENE := "res://scenes/dungeon_grid_view.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_card_release_arms_targeting_without_playing()

	if _failures.is_empty():
		print("Card targeting activation smoke test passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_card_release_arms_targeting_without_playing() -> void:
	var scene := load(DUNGEON_SCENE) as PackedScene
	_expect(scene != null, "Dungeon scene should load.")
	if scene == null:
		return

	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame

	var cells: Array = instance.call("_get_floor_cells_array")
	_expect(not cells.is_empty(), "Dungeon should generate floor cells.")
	if cells.is_empty():
		_cleanup(instance)
		return

	instance.call("_select_start_cell", cells[0])
	instance.call("_start_game")
	await create_timer(0.18).timeout

	var card_state = instance.get("_card_state")
	var initial_hand_size: int = card_state.deck.hand.size()
	_expect(initial_hand_size > 0, "Run should start with at least one card in hand.")
	if initial_hand_size <= 0:
		_cleanup(instance)
		return

	instance.call("_on_card_drag_started", 0)
	await process_frame
	var candidates: Dictionary = instance.get("_target_candidate_cells")
	_expect(bool(instance.get("_card_drag_active")), "Dragging a card should arm targeting mode.")
	_expect(int(instance.get("_selected_hand_index")) == 0, "Armed card should remain selected in hand.")
	_expect(not candidates.is_empty(), "Armed targeting should show selectable grid candidates.")

	instance.call("_on_card_drag_released", 0)
	await process_frame
	_expect(bool(instance.get("_card_drag_active")), "Releasing the card should keep targeting mode active.")
	_expect(card_state.deck.hand.size() == initial_hand_size, "Releasing a dragged card should not consume or play it.")

	var invalid_cell := Vector2i(-123, -123)
	instance.call("_confirm_active_card_target", invalid_cell)
	await process_frame
	_expect(bool(instance.get("_card_drag_active")), "Invalid target click should keep targeting mode active.")
	_expect(card_state.deck.hand.size() == initial_hand_size, "Invalid target click should not consume the card.")

	candidates = instance.get("_target_candidate_cells")
	var valid_cell: Vector2i = candidates.keys()[0]
	instance.call("_confirm_active_card_target", valid_cell)
	await process_frame
	_expect(not bool(instance.get("_card_drag_active")), "Clicking a highlighted tile should exit targeting mode.")
	_expect(card_state.deck.hand.size() == initial_hand_size - 1, "Clicking a highlighted tile should play exactly one card.")

	_cleanup(instance)


func _cleanup(instance: Node) -> void:
	root.remove_child(instance)
	instance.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
