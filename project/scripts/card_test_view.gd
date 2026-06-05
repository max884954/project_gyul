extends Control

const DEBUG_MENU_SCENE := "res://scenes/debug_menu.tscn"
const DungeonCardDatabase := preload("res://scripts/cards/card_database.gd")
const CARD_PREVIEW_ITEM_SCENE := preload("res://scenes/ui/card_preview_item.tscn")

@onready var _back_button: Button = %BackButton
@onready var _card_grid: GridContainer = %CardGrid


func _ready() -> void:
	_back_button.pressed.connect(_back_to_debug_menu)
	_build_cards()


func _back_to_debug_menu() -> void:
	get_tree().change_scene_to_file(DEBUG_MENU_SCENE)


func _build_cards() -> void:
	for child in _card_grid.get_children():
		child.queue_free()

	var cards := DungeonCardDatabase.build_all_card_specs()
	for card_index in range(cards.size()):
		_card_grid.add_child(_create_card(cards[card_index], card_index))


func _create_card(card: Dictionary, card_index: int) -> Control:
	var preview := CARD_PREVIEW_ITEM_SCENE.instantiate() as CardPreviewItem
	preview.setup(card, card_index)
	return preview
