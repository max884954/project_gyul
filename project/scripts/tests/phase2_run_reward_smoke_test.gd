extends SceneTree

const CardDungeonState := preload("res://scripts/dungeon/card_dungeon_state.gd")

const DUNGEON_SCENE := "res://scenes/dungeon_grid_view.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_run_reward_rest_shop_and_boss_flow()
	await _test_scene_loads()

	if _failures.is_empty():
		print("Phase 2 dungeon run reward smoke test passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_run_reward_rest_shop_and_boss_flow() -> void:
	var state := CardDungeonState.new()
	state.setup(_make_test_cells(), Vector2i(0, 0), 3305, CardDungeonState.PHASE_RUN)
	_expect(state.current_zone_type == CardDungeonState.ZONE_COMBAT, "Run should begin with a combat zone.")
	_expect(state.run_state == CardDungeonState.RUN_STATE_ENCOUNTER, "Combat zone should use the dungeon grid encounter state.")
	_expect(state.encounter_active, "Phase 2 combat should happen on the current dungeon grid.")

	_defeat_all_enemies(state)
	_expect(state.run_state == CardDungeonState.RUN_STATE_REWARD, "Defeating combat enemies should open card reward selection.")
	_expect(state.reward_options.size() == 3, "Combat reward should offer three cards.")
	var deck_before_reward := state.deck.get_total_count()
	_expect(state.choose_reward(0), "Choosing a reward card should succeed.")
	_expect(state.deck.get_total_count() == deck_before_reward + 1, "Chosen reward card should be added to the run deck.")
	_expect(state.current_zone_type == CardDungeonState.ZONE_EVENT, "Run should advance to the event zone after combat reward.")
	_expect(state.run_state == CardDungeonState.RUN_STATE_REWARD, "Event zone should resolve into a reward choice without leaving the dungeon screen.")

	var gold_before_pass := state.gold
	_expect(state.choose_reward(-1), "Passing a reward should succeed.")
	_expect(state.gold == gold_before_pass + 10, "Passing a reward should grant gold.")
	_expect(state.current_zone_type == CardDungeonState.ZONE_REST, "Run should advance to rest after the event reward.")
	_expect(state.run_state == CardDungeonState.RUN_STATE_REST, "Rest zone should expose rest actions.")

	for ally in state.party_units:
		ally["hp"] = maxi(1, int(ally["hp"]) - 12)
	var hp_before_rest := int(state.party_units[0]["hp"])
	_expect(state.rest_heal_party(), "Rest heal should be selectable.")
	_expect(int(state.party_units[0]["hp"]) > hp_before_rest, "Rest heal should restore party HP.")
	_expect(state.current_zone_type == CardDungeonState.ZONE_SHOP, "Run should advance to shop after a rest action.")

	state.gold = 60
	var deck_before_shop := state.deck.get_total_count()
	_expect(state.shop_buy_card(), "Shop purchase should be selectable when gold is available.")
	_expect(state.deck.get_total_count() == deck_before_shop + 1, "Shop purchase should add a card to the run deck.")
	_expect(state.current_zone_type == CardDungeonState.ZONE_COMBAT, "Run should return to combat after the shop.")

	_defeat_all_enemies(state)
	_expect(state.choose_reward(-1), "Second combat reward can be passed.")
	_expect(state.current_zone_type == CardDungeonState.ZONE_BOSS, "Run should advance to boss after the second combat.")
	_expect(state.encounter_active, "Boss should also spawn on the dungeon grid.")

	_defeat_all_enemies(state)
	_expect(state.run_state == CardDungeonState.RUN_STATE_REWARD, "Boss defeat should still offer final rewards.")
	_expect(state.choose_reward(-1), "Boss reward can be passed to complete the run.")
	_expect(state.run_complete, "Boss reward resolution should complete the dungeon run.")
	_expect(state.run_state == CardDungeonState.RUN_STATE_COMPLETE, "Run state should mark completion.")


func _defeat_all_enemies(state: CardDungeonState) -> void:
	for enemy in state.enemies:
		enemy["hp"] = 0
	state._remove_defeated_enemies()


func _test_scene_loads() -> void:
	var scene := load(DUNGEON_SCENE) as PackedScene
	_expect(scene != null, "Dungeon grid scene should load with run reward UI.")
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
	for y in range(7):
		for x in range(8):
			cells.append(Vector2i(x, y))
	return cells


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
