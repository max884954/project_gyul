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
