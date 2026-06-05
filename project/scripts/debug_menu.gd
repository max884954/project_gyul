extends Control

const DUNGEON_TEST_SCENE := "res://scenes/dungeon_grid_view.tscn"
const CARD_TEST_SCENE := "res://scenes/card_test_view.tscn"

@onready var _dungeon_test_button: Button = %DungeonTestButton
@onready var _card_test_button: Button = %CardTestButton


func _ready() -> void:
	_dungeon_test_button.pressed.connect(_open_dungeon_test)
	_card_test_button.pressed.connect(_open_card_test)


func _open_dungeon_test() -> void:
	get_tree().change_scene_to_file(DUNGEON_TEST_SCENE)


func _open_card_test() -> void:
	get_tree().change_scene_to_file(CARD_TEST_SCENE)
