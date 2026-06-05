extends SceneTree

const UI_SCENES := [
	"res://scenes/ui/card_preview_item.tscn",
	"res://scenes/ui/dungeon_action_button.tscn",
	"res://scenes/ui/dungeon_card_hud.tscn",
	"res://scenes/ui/dungeon_hand_card.tscn",
	"res://scenes/ui/dungeon_hand_layer.tscn",
]

const ROOT_SCENES := [
	"res://scenes/card_test_view.tscn",
	"res://scenes/dungeon_grid_view.tscn",
]

const AUDIT_FILES := [
	"res://scripts/card_test_view.gd",
	"res://scripts/dungeon_grid_view.gd",
]

const FORBIDDEN_UI_FACTORY_TYPES := [
	"Button",
	"Label",
	"PanelContainer",
	"HBoxContainer",
	"VBoxContainer",
	"MarginContainer",
	"RichTextLabel",
	"Control",
	"ColorRect",
	"TextureRect",
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_ui_scenes_load()
	_test_root_scenes_load()
	_test_no_dynamic_ui_factories()

	if _failures.is_empty():
		print("UI scene refactor smoke test passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_ui_scenes_load() -> void:
	for scene_path in UI_SCENES:
		var scene := load(scene_path) as PackedScene
		_expect(scene != null, "%s should load as a UI scene." % scene_path)
		if scene == null:
			continue
		var instance := scene.instantiate()
		_expect(instance != null, "%s should instantiate." % scene_path)
		instance.queue_free()


func _test_root_scenes_load() -> void:
	for scene_path in ROOT_SCENES:
		var scene := load(scene_path) as PackedScene
		_expect(scene != null, "%s should load." % scene_path)
		if scene == null:
			continue
		var instance := scene.instantiate()
		root.add_child(instance)
		root.remove_child(instance)
		instance.queue_free()


func _test_no_dynamic_ui_factories() -> void:
	for file_path in AUDIT_FILES:
		var file := FileAccess.open(file_path, FileAccess.READ)
		_expect(file != null, "%s should be readable for UI audit." % file_path)
		if file == null:
			continue
		var text := file.get_as_text()
		for type_name in FORBIDDEN_UI_FACTORY_TYPES:
			var pattern := "%s.new(" % type_name
			_expect(not text.contains(pattern), "%s should not dynamically create UI with %s." % [file_path, pattern])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
