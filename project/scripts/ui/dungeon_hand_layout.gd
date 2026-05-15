class_name DungeonHandLayout
extends Control

signal card_pressed(hand_index: int)
signal card_hovered(hand_index: int)
signal card_unhovered(hand_index: int)
signal card_drag_started(hand_index: int)
signal card_drag_moved(hand_index: int)
signal card_drag_released(hand_index: int)
signal card_drag_cancelled(hand_index: int)

@export var hand_card_scene: PackedScene = preload("res://scenes/ui/dungeon_hand_card.tscn")
@export var slot_root_path: NodePath = NodePath("CardSlots")
@export var card_layer_path: NodePath = NodePath("CardLayer")
@export var selected_raise := 64.0
@export var hover_raise := 48.0
@export var selected_scale := 1.18
@export var hover_scale := 1.13
@export var locked_scale := 0.94
@export var max_card_slots := 10
@export var fan_width_ratio := 0.84
@export var slot_width := 126.0
@export var slot_height := 189.0
@export var max_fan_angle_degrees := 8.0

@onready var _slot_root: Control = get_node_or_null(slot_root_path) as Control
@onready var _card_layer: Control = get_node_or_null(card_layer_path) as Control

var _card_nodes: Array[Node] = []
var _selected_hand_index := -1
var _hovered_hand_index := -1
var _run_action_locked := false
var _dragging_hand_index := -1


func _ready() -> void:
	resized.connect(_layout_cards)


func set_cards(cards: Array, selected_hand_index: int, hovered_hand_index: int, run_action_locked: bool) -> void:
	_clear_cards()
	_selected_hand_index = selected_hand_index
	_hovered_hand_index = hovered_hand_index
	_run_action_locked = run_action_locked
	if _card_layer == null or hand_card_scene == null:
		return

	for i in range(cards.size()):
		var card_item := hand_card_scene.instantiate()
		if card_item == null:
			continue
		card_item.connect("card_pressed", Callable(self, "_on_card_pressed"))
		card_item.connect("card_hovered", Callable(self, "_on_card_hovered"))
		card_item.connect("card_unhovered", Callable(self, "_on_card_unhovered"))
		card_item.connect("card_drag_started", Callable(self, "_on_card_drag_started"))
		card_item.connect("card_drag_moved", Callable(self, "_on_card_drag_moved"))
		card_item.connect("card_drag_released", Callable(self, "_on_card_drag_released"))
		card_item.connect("card_drag_cancelled", Callable(self, "_on_card_drag_cancelled"))
		_card_layer.add_child(card_item)
		card_item.call("setup", cards[i], i, i == _selected_hand_index, _is_card_disabled(i))
		_card_nodes.append(card_item)

	_layout_cards()


func set_layout_state(selected_hand_index: int, hovered_hand_index: int, run_action_locked: bool) -> void:
	_selected_hand_index = selected_hand_index
	_hovered_hand_index = hovered_hand_index
	_run_action_locked = run_action_locked
	_layout_cards()


func _clear_cards() -> void:
	for card_node in _card_nodes:
		if is_instance_valid(card_node):
			if card_node.get_parent() == _card_layer:
				_card_layer.remove_child(card_node)
			card_node.queue_free()
	_card_nodes.clear()


func _layout_cards() -> void:
	if _card_nodes.is_empty():
		return

	for i in range(_card_nodes.size()):
		var card_node := _card_nodes[i] as Control
		if card_node == null:
			continue
		if i == _dragging_hand_index:
			continue
		var pose := _get_dynamic_card_pose(i, _card_nodes.size(), card_node)
		var target_position := pose["position"] as Vector2
		var target_rotation := float(pose["rotation"])
		var target_scale := pose["scale"] as Vector2
		card_node.z_index = i

		if i == _selected_hand_index:
			target_position.y -= selected_raise
			target_rotation = 0.0
			target_scale *= selected_scale
			card_node.z_index = 200
		elif i == _hovered_hand_index and not _run_action_locked:
			target_position.y -= hover_raise
			target_rotation = 0.0
			target_scale *= hover_scale
			card_node.z_index = 160
		elif _run_action_locked:
			target_scale *= locked_scale

		card_node.call("set_layout_pose", target_position, target_rotation, target_scale, i == _selected_hand_index, _is_card_disabled(i))


func _get_slots() -> Array[Control]:
	var slots: Array[Control] = []
	for child in _slot_root.get_children():
		var slot := child as Control
		if slot != null:
			slots.append(slot)
	return slots


func _get_dynamic_card_pose(index: int, card_count: int, card_node: Control) -> Dictionary:
	var available_width := maxf(size.x * fan_width_ratio, slot_width)
	var visible_count := maxi(card_count, 1)
	var spacing := slot_width if visible_count == 1 else minf(slot_width, available_width / float(visible_count - 1))
	var total_width := spacing * float(visible_count - 1)
	var center_x := size.x * 0.5
	var normalized := 0.0 if visible_count == 1 else (float(index) / float(visible_count - 1)) * 2.0 - 1.0
	var slot_position := Vector2(
		center_x - total_width * 0.5 + spacing * float(index) - card_node.pivot_offset.x,
		size.y - slot_height - card_node.pivot_offset.y + absf(normalized) * 18.0
	)
	var slot_scale := Vector2.ONE
	if card_node.size.x > 0.0 and card_node.size.y > 0.0:
		var scale_value := minf(slot_width / card_node.size.x, slot_height / card_node.size.y)
		slot_scale = Vector2.ONE * scale_value
	var angle := deg_to_rad(max_fan_angle_degrees) * normalized
	return {
		"position": slot_position,
		"rotation": angle,
		"scale": slot_scale,
	}


func _get_slot_card_scale(slot: Control, card_node: Control) -> Vector2:
	if slot.size.x <= 0.0 or slot.size.y <= 0.0 or card_node.size.x <= 0.0 or card_node.size.y <= 0.0:
		return slot.scale
	var uniform_scale := minf(slot.size.x / card_node.size.x, slot.size.y / card_node.size.y)
	return slot.scale * uniform_scale


func _get_slot_card_position(slot: Control, card_node: Control) -> Vector2:
	return slot.position + slot.size * 0.5 - card_node.pivot_offset


func _is_card_disabled(hand_index: int) -> bool:
	return _run_action_locked or (_selected_hand_index >= 0 and hand_index != _selected_hand_index)


func _on_card_pressed(hand_index: int) -> void:
	card_pressed.emit(hand_index)


func _on_card_hovered(hand_index: int) -> void:
	card_hovered.emit(hand_index)


func _on_card_unhovered(hand_index: int) -> void:
	card_unhovered.emit(hand_index)


func _on_card_drag_started(hand_index: int) -> void:
	_dragging_hand_index = hand_index
	card_drag_started.emit(hand_index)


func _on_card_drag_moved(hand_index: int) -> void:
	card_drag_moved.emit(hand_index)


func _on_card_drag_released(hand_index: int) -> void:
	_dragging_hand_index = -1
	card_drag_released.emit(hand_index)


func _on_card_drag_cancelled(hand_index: int) -> void:
	_dragging_hand_index = -1
	card_drag_cancelled.emit(hand_index)
	_layout_cards()
