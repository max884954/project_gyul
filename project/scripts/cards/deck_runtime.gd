class_name DungeonDeckRuntime
extends RefCounted

var draw_pile: Array[Dictionary] = []
var hand: Array[Dictionary] = []
var discard_pile: Array[Dictionary] = []
var event_log: Array[String] = []

var _rng := RandomNumberGenerator.new()


func setup(cards: Array[Dictionary], seed: int) -> void:
	draw_pile = cards.duplicate(true)
	hand.clear()
	discard_pile.clear()
	event_log.clear()
	_rng.seed = seed
	_shuffle(draw_pile)
	event_log.append("고정 시드 %d로 던전 카드 덱 %d장을 섞었습니다." % [seed, draw_pile.size()])


func draw_cards(count: int) -> int:
	var drawn := 0
	for _i in range(count):
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			_recycle_discard_into_draw()

		if draw_pile.is_empty():
			break

		hand.append(draw_pile.pop_back())
		drawn += 1

	event_log.append("드로우 %d장. 덱 %d / 손패 %d / 버림 %d" % [
		drawn,
		draw_pile.size(),
		hand.size(),
		discard_pile.size(),
	])
	return drawn


func play_card_at(hand_index: int) -> Dictionary:
	if hand_index < 0 or hand_index >= hand.size():
		return {}

	var card := hand[hand_index]
	hand.remove_at(hand_index)
	discard_pile.append(card)
	return card


func add_card_to_discard(card: Dictionary) -> void:
	var copy := card.duplicate(true)
	if not copy.has("instance_id") or String(copy["instance_id"]).is_empty():
		copy["instance_id"] = "%s_added_%03d" % [String(copy.get("id", "card")), get_total_count() + 1]
	discard_pile.append(copy)
	event_log.append("%s 카드가 버림 더미에 추가되었습니다." % String(copy.get("name", "보상")))


func remove_first_card_by_id(card_id: String) -> bool:
	return _remove_first_from_pile(hand, card_id) or _remove_first_from_pile(discard_pile, card_id) or _remove_first_from_pile(draw_pile, card_id)


func remove_first_matching(predicate: Callable) -> Dictionary:
	var removed := _remove_first_matching_from_pile(hand, predicate)
	if not removed.is_empty():
		return removed
	removed = _remove_first_matching_from_pile(discard_pile, predicate)
	if not removed.is_empty():
		return removed
	removed = _remove_first_matching_from_pile(draw_pile, predicate)
	if not removed.is_empty():
		return removed
	return {}


func upgrade_first_matching(predicate: Callable) -> Dictionary:
	var upgraded := _upgrade_first_matching_from_pile(hand, predicate)
	if not upgraded.is_empty():
		return upgraded
	upgraded = _upgrade_first_matching_from_pile(discard_pile, predicate)
	if not upgraded.is_empty():
		return upgraded
	upgraded = _upgrade_first_matching_from_pile(draw_pile, predicate)
	if not upgraded.is_empty():
		return upgraded
	return {}


func get_all_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append_array(draw_pile)
	result.append_array(hand)
	result.append_array(discard_pile)
	return result


func get_total_count() -> int:
	return draw_pile.size() + hand.size() + discard_pile.size()


func get_counts_text() -> String:
	return "덱 %d / 손패 %d / 버림 %d / 총합 %d" % [
		draw_pile.size(),
		hand.size(),
		discard_pile.size(),
		get_total_count(),
	]


func append_log(message: String) -> void:
	event_log.append(message)
	if event_log.size() > 80:
		event_log.remove_at(0)


func _recycle_discard_into_draw() -> void:
	draw_pile = discard_pile.duplicate(true)
	discard_pile.clear()
	_shuffle(draw_pile)
	event_log.append("덱이 비어 버림 더미를 섞어 새 덱으로 만들었습니다.")


func _shuffle(cards: Array[Dictionary]) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, i)
		var temp := cards[i]
		cards[i] = cards[swap_index]
		cards[swap_index] = temp


func _remove_first_from_pile(pile: Array[Dictionary], card_id: String) -> bool:
	for i in range(pile.size()):
		if String(pile[i].get("id", "")) == card_id:
			var card := pile[i]
			pile.remove_at(i)
			event_log.append("%s 카드가 덱에서 제거되었습니다." % String(card.get("name", "카드")))
			return true
	return false


func _remove_first_matching_from_pile(pile: Array[Dictionary], predicate: Callable) -> Dictionary:
	for i in range(pile.size()):
		if predicate.call(pile[i]):
			var card: Dictionary = pile[i]
			pile.remove_at(i)
			event_log.append("%s 카드가 덱에서 제거되었습니다." % String(card.get("name", "카드")))
			return card
	return {}


func _upgrade_first_matching_from_pile(pile: Array[Dictionary], predicate: Callable) -> Dictionary:
	for card in pile:
		if predicate.call(card):
			_upgrade_card(card)
			event_log.append("%s 카드가 강화되었습니다." % String(card.get("name", "카드")))
			return card
	return {}


func _upgrade_card(card: Dictionary) -> void:
	card["upgrade_level"] = int(card.get("upgrade_level", 0)) + 1
	if not String(card.get("name", "")).ends_with("+"):
		card["name"] = "%s+" % String(card.get("name", "카드"))
	for numeric_key in ["damage", "front_damage", "flank_damage", "block", "shield", "heal"]:
		if card.has(numeric_key):
			card[numeric_key] = int(card[numeric_key]) + 2
	if card.has("range") and String(card.get("type", "")) in ["이동", "탐험"]:
		card["range"] = int(card["range"]) + 1
