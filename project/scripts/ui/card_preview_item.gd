class_name CardPreviewItem
extends Control

const CARD_SIZE := Vector2(256.0, 384.0)
const PREVIEW_CARD_SCALE := CARD_SIZE / DungeonHandCard.CARD_CANVAS_SIZE

@onready var _preview_card: DungeonHandCard = %PreviewCard

var _pending_card: Dictionary = {}
var _pending_card_index := -1


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	_preview_card.scale = PREVIEW_CARD_SCALE
	_preview_card.position = -_preview_card.pivot_offset * (Vector2.ONE - PREVIEW_CARD_SCALE)
	if not _pending_card.is_empty():
		_apply_card()


func setup(card: Dictionary, card_index: int) -> void:
	_pending_card = card
	_pending_card_index = card_index
	if is_node_ready():
		_apply_card()


func _apply_card() -> void:
	_preview_card.setup(_pending_card, _pending_card_index, false, false)
