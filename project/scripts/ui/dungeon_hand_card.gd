@tool
class_name DungeonHandCard
extends Control

signal card_pressed(hand_index: int)
signal card_hovered(hand_index: int)
signal card_unhovered(hand_index: int)
signal card_drag_started(hand_index: int)
signal card_drag_moved(hand_index: int)
signal card_drag_released(hand_index: int)
signal card_drag_cancelled(hand_index: int)

const DungeonCardDatabase := preload("res://scripts/cards/card_database.gd")
const CARD_CANVAS_SIZE := Vector2(1024.0, 1536.0)
const DRAG_SCALE_MULTIPLIER := 1.22
const DARK_TITLE_COLOR := Color(0.22, 0.15, 0.07, 1.0)
const DARK_TYPE_COLOR := Color(0.34, 0.22, 0.08, 1.0)
const DARK_DESCRIPTION_COLOR := Color(0.18, 0.12, 0.07, 1.0)
const LIGHT_TITLE_COLOR := Color(1.0, 0.95, 0.82, 1.0)
const LIGHT_TYPE_COLOR := Color(1.0, 0.9, 0.58, 1.0)
const LIGHT_DESCRIPTION_COLOR := Color(1.0, 0.96, 0.86, 1.0)

@export_group("Editor Preview")
@export_enum("warrior", "mage", "rogue", "cleric") var preview_job := DungeonCardDatabase.JOB_WARRIOR:
	set(value):
		preview_job = value
		_queue_editor_preview_update()
@export var preview_title_text := "Card Title":
	set(value):
		preview_title_text = value
		_queue_editor_preview_update()
@export var preview_type_text := "Card Type":
	set(value):
		preview_type_text = value
		_queue_editor_preview_update()
@export_multiline var preview_description_text := "Card description preview.":
	set(value):
		preview_description_text = value
		_queue_editor_preview_update()
@export_range(0.0, 1.0, 0.01) var card_background_alpha := 0.72:
	set(value):
		card_background_alpha = clampf(value, 0.0, 1.0)
		_queue_editor_preview_update()

@export_group("Warrior Skin")
@export var warrior_background_texture: Texture2D = preload("res://assets/art/ui/cards/content_backgrounds/warrior_move_bg.png"):
	set(value):
		warrior_background_texture = value
		_queue_editor_preview_update()
@export var warrior_border_texture: Texture2D = preload("res://assets/art/ui/cards/imagegen_warrior_card_border_only.png"):
	set(value):
		warrior_border_texture = value
		_queue_editor_preview_update()
@export var warrior_title_texture: Texture2D = preload("res://assets/art/ui/cards/imagegen_warrior_card_title_area.png"):
	set(value):
		warrior_title_texture = value
		_queue_editor_preview_update()
@export var warrior_type_texture: Texture2D = preload("res://assets/art/ui/cards/imagegen_warrior_card_type_area.png"):
	set(value):
		warrior_type_texture = value
		_queue_editor_preview_update()
@export var warrior_text_texture: Texture2D = preload("res://assets/art/ui/cards/imagegen_warrior_card_text_area.png"):
	set(value):
		warrior_text_texture = value
		_queue_editor_preview_update()

@export_group("Mage Skin")
@export var mage_background_texture: Texture2D = preload("res://assets/art/ui/cards/content_backgrounds/mage_blink_bg.png"):
	set(value):
		mage_background_texture = value
		_queue_editor_preview_update()
@export var mage_border_texture: Texture2D = preload("res://assets/art/ui/cards/imagegen_mage_card_border_only.png"):
	set(value):
		mage_border_texture = value
		_queue_editor_preview_update()
@export var mage_title_texture: Texture2D = preload("res://assets/art/ui/cards/imagegen_mage_card_title_area.png"):
	set(value):
		mage_title_texture = value
		_queue_editor_preview_update()
@export var mage_type_texture: Texture2D = preload("res://assets/art/ui/cards/imagegen_mage_card_type_area.png"):
	set(value):
		mage_type_texture = value
		_queue_editor_preview_update()
@export var mage_text_texture: Texture2D = preload("res://assets/art/ui/cards/imagegen_mage_card_text_area.png"):
	set(value):
		mage_text_texture = value
		_queue_editor_preview_update()

@export_group("Rogue Skin")
@export var rogue_background_texture: Texture2D = preload("res://assets/art/ui/cards/content_backgrounds/rogue_move_bg.png"):
	set(value):
		rogue_background_texture = value
		_queue_editor_preview_update()
@export var rogue_border_texture: Texture2D = preload("res://assets/art/ui/cards/imagegen_rogue_card_border_only.png"):
	set(value):
		rogue_border_texture = value
		_queue_editor_preview_update()
@export var rogue_title_texture: Texture2D = preload("res://assets/art/ui/cards/imagegen_rogue_card_title_area.png"):
	set(value):
		rogue_title_texture = value
		_queue_editor_preview_update()
@export var rogue_type_texture: Texture2D = preload("res://assets/art/ui/cards/imagegen_rogue_card_type_area.png"):
	set(value):
		rogue_type_texture = value
		_queue_editor_preview_update()
@export var rogue_text_texture: Texture2D = preload("res://assets/art/ui/cards/imagegen_rogue_card_text_area.png"):
	set(value):
		rogue_text_texture = value
		_queue_editor_preview_update()

@export_group("Cleric Skin")
@export var cleric_background_texture: Texture2D = preload("res://assets/art/ui/cards/content_backgrounds/cleric_heal_bg.png"):
	set(value):
		cleric_background_texture = value
		_queue_editor_preview_update()
@export var cleric_border_texture: Texture2D = preload("res://assets/art/ui/cards/imagegen_cleric_card_border_only.png"):
	set(value):
		cleric_border_texture = value
		_queue_editor_preview_update()
@export var cleric_title_texture: Texture2D = preload("res://assets/art/ui/cards/imagegen_cleric_card_title_area.png"):
	set(value):
		cleric_title_texture = value
		_queue_editor_preview_update()
@export var cleric_type_texture: Texture2D = preload("res://assets/art/ui/cards/imagegen_cleric_card_type_area.png"):
	set(value):
		cleric_type_texture = value
		_queue_editor_preview_update()
@export var cleric_text_texture: Texture2D = preload("res://assets/art/ui/cards/imagegen_cleric_card_text_area.png"):
	set(value):
		cleric_text_texture = value
		_queue_editor_preview_update()

@onready var _background: TextureRect = %CardBackground
@onready var _illustration: TextureRect = %CardIllustration
@onready var _title_area: TextureRect = %CardTitleArea
@onready var _type_area: TextureRect = %CardTypeArea
@onready var _text_area: TextureRect = %CardTextArea
@onready var _border: TextureRect = %CardBorder
@onready var _title_label: Label = %TitleLabel
@onready var _type_label: Label = %TypeLabel
@onready var _type_detail_label: Label = %TypeLabel2
@onready var _description_label: Label = %DescriptionLabel
@onready var _selected_frame: Panel = %SelectedFrame
@onready var _disabled_overlay: ColorRect = %DisabledOverlay
@onready var _press_area: Button = %PressArea

var _hand_index := -1
var _pending_card: Dictionary = {}
var _pending_selected := false
var _pending_disabled := false
var _target_position := Vector2.ZERO
var _target_rotation := 0.0
var _target_scale := Vector2.ONE
var _pose_pending := false
var _layout_tween: Tween
var _is_dragging := false
var _drag_origin_position := Vector2.ZERO
var _drag_origin_rotation := 0.0
var _drag_origin_scale := Vector2.ONE
var _drag_grab_local_position := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = CARD_CANVAS_SIZE
	size = CARD_CANVAS_SIZE
	pivot_offset = CARD_CANVAS_SIZE * 0.5
	set_process(false)
	if Engine.is_editor_hint():
		_apply_editor_preview()
	else:
		_connect_input_signals()
	if not _pending_card.is_empty():
		_apply_setup()
	if _pose_pending:
		_apply_layout_pose(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5


func _connect_input_signals() -> void:
	if not _press_area.pressed.is_connected(_on_press_area_pressed):
		_press_area.pressed.connect(_on_press_area_pressed)
	if not _press_area.gui_input.is_connected(_on_press_area_gui_input):
		_press_area.gui_input.connect(_on_press_area_gui_input)
	if not _press_area.mouse_entered.is_connected(_on_press_area_mouse_entered):
		_press_area.mouse_entered.connect(_on_press_area_mouse_entered)
	if not _press_area.mouse_exited.is_connected(_on_press_area_mouse_exited):
		_press_area.mouse_exited.connect(_on_press_area_mouse_exited)


func setup(card: Dictionary, hand_index: int, selected: bool, disabled: bool) -> void:
	_hand_index = hand_index
	_pending_card = card
	_pending_selected = selected
	_pending_disabled = disabled
	if is_node_ready():
		_apply_setup()


func set_layout_pose(target_position: Vector2, target_rotation: float, target_scale: Vector2, selected: bool, disabled: bool) -> void:
	if _is_dragging:
		_pending_selected = selected
		_pending_disabled = disabled
		return
	_target_position = target_position
	_target_rotation = target_rotation
	_target_scale = target_scale
	_pending_selected = selected
	_pending_disabled = disabled
	_pose_pending = true
	if is_node_ready():
		_apply_setup()
		_apply_layout_pose(true)


func _apply_setup() -> void:
	var job := String(_pending_card.get("job", preview_job))
	var art_path := String(_pending_card.get("art_path", _pending_card.get("image_path", "")))
	_apply_job_skin(job)
	_apply_text_colors(job)
	_apply_card_background_path(art_path)
	_illustration.texture = null
	_title_label.text = String(_pending_card.get("name", "카드"))
	_type_label.text = String(_pending_card.get("type", ""))
	_description_label.text = String(_pending_card.get("description", ""))
	_selected_frame.visible = _pending_selected
	_disabled_overlay.visible = _pending_disabled
	_press_area.disabled = _pending_disabled
	_press_area.tooltip_text = _description_label.text


func _queue_editor_preview_update() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		call_deferred("_apply_editor_preview")


func _apply_editor_preview() -> void:
	if not is_node_ready():
		return
	_apply_job_skin(preview_job)
	_apply_text_colors(preview_job)
	_title_label.text = preview_title_text
	_type_label.text = preview_type_text
	_description_label.text = preview_description_text
	_selected_frame.visible = false
	_disabled_overlay.visible = false


func _apply_job_skin(job: String) -> void:
	var skin := _get_job_skin(job)
	_apply_background_texture(skin["background"] as Texture2D)
	_border.texture = skin["border"] as Texture2D
	_title_area.texture = skin["title"] as Texture2D
	_type_area.texture = skin["type"] as Texture2D
	_text_area.texture = skin["text"] as Texture2D


func _apply_text_colors(job: String) -> void:
	var uses_dark_text := job == DungeonCardDatabase.JOB_CLERIC
	_title_label.add_theme_color_override("font_color", DARK_TITLE_COLOR if uses_dark_text else LIGHT_TITLE_COLOR)
	_type_label.add_theme_color_override("font_color", DARK_TYPE_COLOR if uses_dark_text else LIGHT_TYPE_COLOR)
	_type_detail_label.add_theme_color_override("font_color", DARK_TYPE_COLOR if uses_dark_text else LIGHT_TYPE_COLOR)
	_description_label.add_theme_color_override("font_color", DARK_DESCRIPTION_COLOR if uses_dark_text else LIGHT_DESCRIPTION_COLOR)


func _apply_background_texture(texture: Texture2D) -> void:
	_background.texture = texture
	_background.visible = texture != null
	_background.modulate = Color(1.0, 1.0, 1.0, card_background_alpha)


func _apply_card_background_path(texture_path: String) -> void:
	if texture_path.is_empty():
		return
	var texture := _load_card_texture(texture_path)
	if texture != null:
		_apply_background_texture(texture)


func _get_job_skin(job: String) -> Dictionary:
	match job:
		DungeonCardDatabase.JOB_MAGE:
			return {
				"background": mage_background_texture,
				"border": mage_border_texture,
				"title": mage_title_texture,
				"type": mage_type_texture,
				"text": mage_text_texture,
			}
		DungeonCardDatabase.JOB_ROGUE:
			return {
				"background": rogue_background_texture,
				"border": rogue_border_texture,
				"title": rogue_title_texture,
				"type": rogue_type_texture,
				"text": rogue_text_texture,
			}
		DungeonCardDatabase.JOB_CLERIC:
			return {
				"background": cleric_background_texture,
				"border": cleric_border_texture,
				"title": cleric_title_texture,
				"type": cleric_type_texture,
				"text": cleric_text_texture,
			}
		_:
			return {
				"background": warrior_background_texture,
				"border": warrior_border_texture,
				"title": warrior_title_texture,
				"type": warrior_type_texture,
				"text": warrior_text_texture,
			}


func _load_card_texture(texture_path: String) -> Texture2D:
	if FileAccess.file_exists("%s.import" % texture_path):
		var imported_texture := load(texture_path) as Texture2D
		if imported_texture != null:
			return imported_texture

	var image := Image.new()
	if image.load(texture_path) != OK:
		push_warning("Failed to load card background: %s" % texture_path)
		return null
	return ImageTexture.create_from_image(image)


func _apply_layout_pose(animated: bool) -> void:
	if _is_dragging:
		return
	if _layout_tween != null:
		_layout_tween.kill()
	z_index = 100 if _pending_selected else z_index
	if not animated:
		position = _target_position
		rotation = _target_rotation
		scale = _target_scale
		return

	_layout_tween = create_tween()
	_layout_tween.set_parallel(true)
	_layout_tween.set_trans(Tween.TRANS_CUBIC)
	_layout_tween.set_ease(Tween.EASE_OUT)
	_layout_tween.tween_property(self, "position", _target_position, 0.14)
	_layout_tween.tween_property(self, "rotation", _target_rotation, 0.14)
	_layout_tween.tween_property(self, "scale", _target_scale, 0.14)


func _process(_delta: float) -> void:
	if not _is_dragging:
		return
	_update_drag_pose()
	card_drag_moved.emit(_hand_index)


func cancel_drag() -> void:
	if not _is_dragging:
		_return_to_layout_pose()
		return
	_finish_drag(false)


func _on_press_area_pressed() -> void:
	pass


func _on_press_area_gui_input(event: InputEvent) -> void:
	if _pending_disabled:
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_begin_drag(mouse_button.position)
			elif _is_dragging:
				_finish_drag(true)
				accept_event()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_RIGHT and _is_dragging:
			_finish_drag(false)
			accept_event()
	elif event is InputEventMouseMotion and _is_dragging:
		_update_drag_pose()
		card_drag_moved.emit(_hand_index)
		accept_event()


func _begin_drag(grab_local_position: Vector2 = Vector2.INF) -> void:
	if _is_dragging:
		return
	_is_dragging = true
	_drag_origin_position = position
	_drag_origin_rotation = rotation
	_drag_origin_scale = scale
	_drag_grab_local_position = grab_local_position
	if not _drag_grab_local_position.is_finite():
		_drag_grab_local_position = _press_area.get_local_mouse_position()
	if _layout_tween != null:
		_layout_tween.kill()
	z_index = 400
	rotation = 0.0
	scale = _drag_origin_scale * DRAG_SCALE_MULTIPLIER
	_selected_frame.visible = true
	_disabled_overlay.visible = false
	set_process(true)
	_update_drag_pose()
	card_drag_started.emit(_hand_index)


func _finish_drag(released: bool) -> void:
	_is_dragging = false
	set_process(false)
	if released:
		card_drag_released.emit(_hand_index)
	else:
		card_drag_cancelled.emit(_hand_index)
	_return_to_layout_pose()


func _return_to_layout_pose() -> void:
	_target_position = _drag_origin_position
	_target_rotation = _drag_origin_rotation
	_target_scale = _drag_origin_scale
	_apply_layout_pose(true)


func _update_drag_pose() -> void:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return
	var local_mouse := parent_control.get_local_mouse_position()
	position = _get_drag_position_for_mouse(local_mouse)


func _get_drag_position_for_mouse(local_mouse: Vector2) -> Vector2:
	var scaled_grab_offset := pivot_offset + (_drag_grab_local_position - pivot_offset) * scale
	return local_mouse - scaled_grab_offset


func _on_press_area_mouse_entered() -> void:
	if not _pending_disabled:
		card_hovered.emit(_hand_index)


func _on_press_area_mouse_exited() -> void:
	card_unhovered.emit(_hand_index)
