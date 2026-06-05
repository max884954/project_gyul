extends SceneTree

const CardDungeonState := preload("res://scripts/dungeon/card_dungeon_state.gd")
const DungeonBalanceReport := preload("res://scripts/balance/dungeon_balance_report.gd")
const DungeonCardDatabase := preload("res://scripts/cards/card_database.gd")
const DungeonEnemyCatalog := preload("res://scripts/dungeon/enemy_catalog.gd")
const DungeonMetaProgress := preload("res://scripts/progression/meta_progress.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_balance_report()
	_test_meta_progress()
	_test_run_lp_result()

	if _failures.is_empty():
		print("Phase 3 growth balance smoke test passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_balance_report() -> void:
	var report := DungeonBalanceReport.build_phase3_report()
	_expect(int(report["starting_total"]) == 40, "Starting deck should remain 40 cards.")
	_expect(int(report["reward_total"]) >= 8, "Reward pool should include Phase 3 reward cards.")
	_expect(float(report["movement_ratio"]) >= 0.15, "Starting deck should preserve movement card density.")
	_expect(float(report["explore_ratio"]) >= 0.15, "Starting deck should preserve search card density.")
	_expect(float(report["combat_ratio"]) >= 0.45, "Starting deck should keep combat cards as the largest share.")
	_expect(int(report["enemy_count"]) >= 12, "Enemy catalog should include at least 12 regular enemies.")
	_expect(int(report["boss_count"]) >= 3, "Enemy catalog should include at least 3 bosses.")

	var reward_jobs: Dictionary = report["reward_job_counts"]
	for job in [DungeonCardDatabase.JOB_WARRIOR, DungeonCardDatabase.JOB_MAGE, DungeonCardDatabase.JOB_ROGUE, DungeonCardDatabase.JOB_CLERIC]:
		_expect(int(reward_jobs.get(job, 0)) >= 2, "Reward pool should include options for every job.")


func _test_meta_progress() -> void:
	var meta := DungeonMetaProgress.new()
	meta.setup_defaults()
	_expect(meta.unlocked_card_ids.size() == 4, "Meta progress should begin with one unlocked reward per job.")
	meta.grant_lp(12, "test")
	_expect(meta.can_unlock("mage_chain_lightning"), "Granted LP should unlock a card when enough LP is available.")
	_expect(meta.unlock_card("mage_chain_lightning"), "Unlock should spend LP and add the card.")

	var saved := meta.to_dict()
	var loaded := DungeonMetaProgress.new()
	loaded.from_dict(saved)
	_expect(loaded.unlocked_card_ids.has("mage_chain_lightning"), "Meta progress should serialize unlocked cards.")
	_expect(loaded.available_lp == meta.available_lp, "Meta progress should preserve available LP.")


func _test_run_lp_result() -> void:
	var state := CardDungeonState.new()
	state.setup(_make_test_cells(), Vector2i(0, 0), 4305, CardDungeonState.PHASE_RUN)
	var first_enemy_ids: Array[String] = []
	for enemy in state.enemies:
		first_enemy_ids.append(String(enemy["id"]))
	_expect(first_enemy_ids.size() == 2, "Catalog encounter should spawn two enemies for regular combat.")

	_complete_current_encounter(state)
	state.choose_reward(-1)
	state.choose_reward(-1)
	state.rest_heal_party()
	state.gold = 60
	state.shop_buy_card()
	_complete_current_encounter(state)
	state.choose_reward(-1)
	_expect(state.current_zone_type == CardDungeonState.ZONE_BOSS, "Phase 3 run should still reach the boss zone.")
	_expect(DungeonEnemyCatalog.get_boss_count() >= 3, "Boss catalog should be available to the run state.")
	_complete_current_encounter(state)
	state.choose_reward(-1)

	var result := state.get_run_result()
	_expect(bool(result["run_complete"]), "Run result should report completion.")
	_expect(int(result["earned_lp"]) > 0, "Completed run should grant LP.")
	_expect((result["completed_zones"] as Array).size() == CardDungeonState.ZONE_SEQUENCE.size(), "Run result should track completed zones.")


func _complete_current_encounter(state: CardDungeonState) -> void:
	for enemy in state.enemies:
		enemy["hp"] = 0
	state._remove_defeated_enemies()


func _make_test_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(8):
		for x in range(9):
			cells.append(Vector2i(x, y))
	return cells


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
