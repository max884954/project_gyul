extends SceneTree

const DungeonCardDatabase := preload("res://scripts/cards/card_database.gd")
const CardDungeonState := preload("res://scripts/dungeon/card_dungeon_state.gd")

const DUNGEON_SCENE := "res://scenes/dungeon_grid_view.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_phase1_deck_counts()
	_test_integrated_encounter_rules()
	await _test_scene_loads()

	if _failures.is_empty():
		print("Phase 1 integrated encounter smoke test passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_phase1_deck_counts() -> void:
	var deck := DungeonCardDatabase.build_phase1_deck()
	_expect(deck.size() == 40, "Phase 1 starting deck should contain 40 cards.")
	_expect(_count_job(deck, DungeonCardDatabase.JOB_WARRIOR) == 10, "Warrior cards should total 10.")
	_expect(_count_job(deck, DungeonCardDatabase.JOB_MAGE) == 10, "Mage cards should total 10.")
	_expect(_count_job(deck, DungeonCardDatabase.JOB_ROGUE) == 10, "Rogue cards should total 10.")
	_expect(_count_job(deck, DungeonCardDatabase.JOB_CLERIC) == 10, "Cleric cards should total 10.")


func _test_integrated_encounter_rules() -> void:
	var state := CardDungeonState.new()
	state.setup(_make_test_cells(), Vector2i(0, 0), 2205, CardDungeonState.PHASE_ENCOUNTER)
	_expect(state.encounter_active, "Phase 1 should open encounter mode on the same dungeon grid.")
	_expect(state.party_units.size() == 4, "Encounter should place 4 party units.")
	_expect(state.enemies.size() == 2, "Encounter should place enemies in the dungeon grid.")
	_expect(state.deck.hand.size() == 5, "Encounter turn should still draw 5 cards.")
	_expect(state.get_enemy_intent_text().contains("적 행동 공개"), "Enemy intent text should be available before card play.")

	var warrior := _unit_by_id(state.party_units, "warrior")
	var skeleton := state.enemies[0]
	warrior["cell"] = Vector2i(1, 1)
	skeleton["cell"] = Vector2i(2, 1)
	state.deck.hand.append(_find_card("warrior_strike"))
	var hp_before := int(skeleton["hp"])
	_expect(state.use_card(state.deck.hand.size() - 1, skeleton["cell"]), "Attack card should be used on an enemy in the current dungeon grid.")
	_expect(int(skeleton["hp"]) < hp_before, "Attack card should damage the enemy without scene transition.")

	var rogue := _unit_by_id(state.party_units, "rogue")
	rogue["cell"] = Vector2i(1, 2)
	state.deck.hand.append(_find_card("rogue_move"))
	_expect(state.use_card(state.deck.hand.size() - 1, Vector2i(2, 2)), "Movement card should move a character during an encounter.")
	_expect(rogue["cell"] == Vector2i(2, 2), "Rogue movement card should update the rogue position.")

	var cleric := _unit_by_id(state.party_units, "cleric")
	warrior["hp"] = 8
	cleric["cell"] = Vector2i(1, 0)
	state.deck.hand.append(_find_card("cleric_heal"))
	_expect(state.use_card(state.deck.hand.size() - 1, warrior["cell"]), "Heal card should target an ally on the dungeon grid.")
	_expect(int(warrior["hp"]) > 8, "Heal card should restore ally HP.")

	var turn_before := state.turn_number
	skeleton["cell"] = Vector2i(1, 2)
	state._plan_enemy_intents()
	var hp_before_enemy_turn := int(warrior["hp"])
	state.end_turn()
	_expect(state.turn_number == turn_before + 1, "Ending an encounter turn should advance to the next dungeon turn.")
	_expect(int(warrior["hp"]) < hp_before_enemy_turn, "Enemy intent should execute on the same dungeon grid.")


func _test_scene_loads() -> void:
	var scene := load(DUNGEON_SCENE) as PackedScene
	_expect(scene != null, "Dungeon grid scene should load with integrated encounter code.")
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
	for y in range(5):
		for x in range(7):
			cells.append(Vector2i(x, y))
	return cells


func _find_card(card_id: String) -> Dictionary:
	for card in DungeonCardDatabase.build_phase1_deck():
		if card["id"] == card_id:
			return card
	return {}


func _unit_by_id(units: Array[Dictionary], unit_id: String) -> Dictionary:
	for unit in units:
		if unit["id"] == unit_id:
			return unit
	return {}


func _count_job(deck: Array[Dictionary], job: String) -> int:
	var count := 0
	for card in deck:
		if card["job"] == job:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
