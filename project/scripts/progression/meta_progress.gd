class_name DungeonMetaProgress
extends RefCounted

const DEFAULT_UNLOCKED_CARD_IDS := [
	"warrior_cleave",
	"mage_deep_scan",
	"rogue_shadow_step",
	"cleric_sanctuary",
]

const UNLOCK_COSTS := {
	"warrior_cover_advance": 8,
	"mage_chain_lightning": 10,
	"rogue_mark_weakness": 8,
	"cleric_group_heal": 10,
}

var lifetime_lp := 0
var available_lp := 0
var completed_runs := 0
var unlocked_card_ids: Array[String] = []


func setup_defaults() -> void:
	lifetime_lp = 0
	available_lp = 0
	completed_runs = 0
	unlocked_card_ids.clear()
	for card_id in DEFAULT_UNLOCKED_CARD_IDS:
		unlocked_card_ids.append(String(card_id))


func grant_lp(amount: int, reason: String = "") -> void:
	var gain := maxi(0, amount)
	lifetime_lp += gain
	available_lp += gain


func register_completed_run(lp_reward: int) -> void:
	completed_runs += 1
	grant_lp(lp_reward, "run_complete")


func can_unlock(card_id: String) -> bool:
	if unlocked_card_ids.has(card_id):
		return false
	return available_lp >= int(UNLOCK_COSTS.get(card_id, 9999))


func unlock_card(card_id: String) -> bool:
	if not can_unlock(card_id):
		return false
	available_lp -= int(UNLOCK_COSTS[card_id])
	unlocked_card_ids.append(card_id)
	return true


func to_dict() -> Dictionary:
	return {
		"lifetime_lp": lifetime_lp,
		"available_lp": available_lp,
		"completed_runs": completed_runs,
		"unlocked_card_ids": unlocked_card_ids.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	lifetime_lp = int(data.get("lifetime_lp", 0))
	available_lp = int(data.get("available_lp", 0))
	completed_runs = int(data.get("completed_runs", 0))
	unlocked_card_ids.clear()
	for card_id in data.get("unlocked_card_ids", DEFAULT_UNLOCKED_CARD_IDS):
		unlocked_card_ids.append(String(card_id))
