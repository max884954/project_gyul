extends SceneTree

const CardDungeonState := preload("res://scripts/dungeon/card_dungeon_state.gd")
const SaveRuntimeScript := preload("res://scripts/system/dungeon_save_runtime.gd")
const TutorialFlowScript := preload("res://scripts/tutorial/dungeon_tutorial_flow.gd")

const DUNGEON_SCENE := "res://scenes/dungeon_grid_view.tscn"
const TEST_SAVE_PATH := "user://phase4_test_save.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_save_round_trip()
	_test_tutorial_flow()
	_test_release_preset()
	await _test_scene_loads()

	var save_runtime := SaveRuntimeScript.new()
	save_runtime.clear_save(TEST_SAVE_PATH)
	if _failures.is_empty():
		print("Phase 4 polish release smoke test passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_save_round_trip() -> void:
	var state := CardDungeonState.new()
	var save_runtime := SaveRuntimeScript.new()
	state.setup(_make_test_cells(), Vector2i(0, 0), 5305, CardDungeonState.PHASE_RUN)
	state.gold = 42
	state.party_units[0]["hp"] = 9
	state.reward_options = []
	var save_data := state.to_save_dict()

	var restored := CardDungeonState.new()
	restored.apply_save_dict(save_data)
	_expect(restored.gold == 42, "Save dict should preserve gold.")
	_expect(restored.party_units.size() == state.party_units.size(), "Save dict should preserve party units.")
	_expect(int(restored.party_units[0]["hp"]) == 9, "Save dict should preserve party HP.")
	_expect(restored.deck.get_total_count() == state.deck.get_total_count(), "Save dict should preserve deck card count.")

	_expect(save_runtime.save_state(state, TEST_SAVE_PATH), "Save runtime should write a JSON save file.")
	var loaded := CardDungeonState.new()
	_expect(save_runtime.load_state(loaded, TEST_SAVE_PATH), "Save runtime should load a JSON save file.")
	_expect(loaded.gold == 42, "Loaded save should preserve state values.")
	_expect(save_runtime.has_save(TEST_SAVE_PATH), "Save runtime should report the test save.")


func _test_tutorial_flow() -> void:
	var tutorial := TutorialFlowScript.new()
	tutorial.reset()
	_expect(tutorial.get_current_text().contains("시작 위치"), "Tutorial should begin with start selection guidance.")
	_expect(tutorial.advance_on_event("start_selected"), "Tutorial should advance on the matching event.")
	_expect(not tutorial.advance_on_event("reward_chosen"), "Tutorial should not skip ahead on the wrong event.")
	tutorial.advance_on_event("card_played")
	tutorial.advance_on_event("turn_ended")
	tutorial.advance_on_event("reward_chosen")
	_expect(tutorial.advance_on_event("run_completed"), "Tutorial should complete on the final event.")
	_expect(tutorial.completed, "Tutorial flow should mark completion.")


func _test_release_preset() -> void:
	_expect(FileAccess.file_exists("res://export_presets.cfg"), "Windows test export preset should exist.")
	var file := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	_expect(file != null, "Export preset should be readable.")
	if file == null:
		return
	var text := file.get_as_text()
	_expect(text.contains("Windows Desktop"), "Export preset should target Windows Desktop.")
	_expect(text.contains("GGeul_Windows_Test.exe"), "Export preset should define a test executable path.")


func _test_scene_loads() -> void:
	var scene := load(DUNGEON_SCENE) as PackedScene
	_expect(scene != null, "Dungeon grid scene should load with Phase 4 UI.")
	if scene == null:
		return
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame
	root.remove_child(instance)
	instance.queue_free()
	await process_frame


func _make_test_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(6):
		for x in range(7):
			cells.append(Vector2i(x, y))
	return cells


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
