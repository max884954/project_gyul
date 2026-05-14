class_name DungeonBalanceReport
extends RefCounted

const DungeonCardDatabase := preload("res://scripts/cards/card_database.gd")
const DungeonEnemyCatalog := preload("res://scripts/dungeon/enemy_catalog.gd")


static func build_phase3_report() -> Dictionary:
	var starting_deck := DungeonCardDatabase.build_phase1_deck()
	var reward_pool := DungeonCardDatabase.build_reward_pool()
	var starting_types := count_cards_by_type(starting_deck)
	var reward_types := count_cards_by_type(reward_pool)
	return {
		"starting_total": starting_deck.size(),
		"reward_total": reward_pool.size(),
		"starting_type_counts": starting_types,
		"reward_type_counts": reward_types,
		"starting_job_counts": count_cards_by_job(starting_deck),
		"reward_job_counts": count_cards_by_job(reward_pool),
		"movement_ratio": _ratio(starting_types, DungeonCardDatabase.TYPE_MOVE, starting_deck.size()),
		"explore_ratio": _ratio(starting_types, DungeonCardDatabase.TYPE_EXPLORE, starting_deck.size()),
		"combat_ratio": _combat_ratio(starting_types, starting_deck.size()),
		"enemy_count": DungeonEnemyCatalog.get_enemy_count(),
		"boss_count": DungeonEnemyCatalog.get_boss_count(),
	}


static func count_cards_by_type(cards: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for card in cards:
		var card_type := String(card.get("type", "unknown"))
		result[card_type] = int(result.get(card_type, 0)) + 1
	return result


static func count_cards_by_job(cards: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for card in cards:
		var job := String(card.get("job", "unknown"))
		result[job] = int(result.get(job, 0)) + 1
	return result


static func _ratio(counts: Dictionary, key: String, total: int) -> float:
	if total <= 0:
		return 0.0
	return float(counts.get(key, 0)) / float(total)


static func _combat_ratio(counts: Dictionary, total: int) -> float:
	if total <= 0:
		return 0.0
	var combat_count := int(counts.get(DungeonCardDatabase.TYPE_ATTACK, 0))
	combat_count += int(counts.get(DungeonCardDatabase.TYPE_DEFENSE, 0))
	combat_count += int(counts.get(DungeonCardDatabase.TYPE_HEAL, 0))
	combat_count += int(counts.get(DungeonCardDatabase.TYPE_SKILL, 0))
	combat_count += int(counts.get("회피", 0))
	return float(combat_count) / float(total)
