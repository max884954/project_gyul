extends Control

const DEBUG_MENU_SCENE := "res://scenes/debug_menu.tscn"
const CARD_SIZE := Vector2(260.0, 390.0)

const CARD_TEXTURES := [
	"res://assets/art/ui/cards/imagegen_warrior_card_ko.png",
	"res://assets/art/ui/cards/imagegen_mage_card_ko.png",
	"res://assets/art/ui/cards/imagegen_rogue_card_ko.png",
	"res://assets/art/ui/cards/imagegen_cleric_card_ko.png",
]

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

	for texture_path in CARD_TEXTURES:
		_card_grid.add_child(_create_card(texture_path))


func _create_card(texture_path: String) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.custom_minimum_size = CARD_SIZE
	texture_rect.texture = _load_png_texture(texture_path)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	return texture_rect


func _load_png_texture(texture_path: String) -> Texture2D:
	if not FileAccess.file_exists(texture_path):
		push_warning("Missing card image: %s" % texture_path)
		return null

	var file_bytes := FileAccess.get_file_as_bytes(texture_path)
	var image := Image.new()
	var error := image.load_png_from_buffer(file_bytes)
	if error != OK:
		push_warning("Failed to load card image: %s" % texture_path)
		return null

	return ImageTexture.create_from_image(image)
