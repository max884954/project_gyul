extends SceneTree

const DungeonCardDatabase := preload("res://scripts/cards/card_database.gd")
const CardDungeonState := preload("res://scripts/dungeon/card_dungeon_state.gd")

const DUNGEON_SCENE := "res://scenes/dungeon_grid_view.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_phase0_deck()
	_test_card_based_movement_and_search()
	await _test_scene_loads()

	if _failures.is_empty():
		print("Phase 0 card dungeon smoke test passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_phase0_deck() -> void:
	var deck := DungeonCardDatabase.build_phase0_deck()
	_expect(deck.size() == 20, "Phase 0 deck should contain 20 cards.")
	_expect(_count_type(deck, DungeonCardDatabase.TYPE_MOVE) >= 9, "Phase 0 deck should prioritize movement cards.")
	_expect(_count_type(deck, DungeonCardDatabase.TYPE_EXPLORE) >= 7, "Phase 0 deck should include search cards.")


func _test_card_based_movement_and_search() -> void:
	var state := CardDungeonState.new()
	state.setup(_make_test_cells(), Vector2i(0, 0), 1205)
	_expect(state.deck.hand.size() == 5, "Dungeon turn should draw 5 cards.")
	_expect(state.deck.get_total_count() == 20, "Deck, hand, and discard should conserve card count.")

	var move_card := _find_card("warrior_move")
	state.deck.hand.append(move_card)
	var move_index := state.deck.hand.size() - 1
	_expect(state.use_card(move_index, Vector2i(2, 0)), "Movement card should be playable on a reachable dungeon tile.")
	_expect(state.party_cell == Vector2i(2, 0), "Movement card should update dungeon party coordinates.")
	_expect(state.deck.discard_pile.back()["id"] == "warrior_move", "Used movement card should move to discard pile.")

	var first_hidden := _first_hidden_cell(state)
	var search_card := _find_card("mage_arcane_sight")
	state.deck.hand.append(search_card)
	var search_index := state.deck.hand.size() - 1
	_expect(state.use_card(search_index, first_hidden), "Search card should be playable on a reachable search target.")
	_expect(state.revealed_points.has(first_hidden), "Search card should reveal hidden dungeon information.")

	state.deck.draw_pile.clear()
	state.deck.discard_pile = [move_card.duplicate(true), search_card.duplicate(true)]
	var hand_before := state.deck.hand.size()
	var drawn := state.deck.draw_cards(2)
	_expect(drawn == 2, "Deck should recycle discard pile when draw pile is empty.")
	_expect(state.deck.hand.size() == hand_before + 2, "Recycled cards should enter the hand.")


func _test_scene_loads() -> void:
	var scene := load(DUNGEON_SCENE) as PackedScene
	_expect(scene != null, "Dungeon grid scene should load.")
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
	for y in range(4):
		for x in range(6):
			cells.append(Vector2i(x, y))
	return cells


func _find_card(card_id: String) -> Dictionary:
	for card in DungeonCardDatabase.build_phase0_deck():
		if card["id"] == card_id:
			return card
	return {}


func _first_hidden_cell(state: CardDungeonState) -> Vector2i:
	for cell in state.hidden_points.keys():
		return cell
	return Vector2i.ZERO


func _count_type(deck: Array[Dictionary], card_type: String) -> int:
	var count := 0
	for card in deck:
		if card["type"] == card_type:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
