class_name DungeonEnemyCatalog
extends RefCounted

const ZONE_COMBAT := "combat"
const ZONE_BOSS := "boss"

const COMBAT_ENEMIES := [
	{"id": "skeleton", "name": "해골 병사", "max_hp": 22, "attack": 6, "range": 1, "role": "front"},
	{"id": "wraith", "name": "망령", "max_hp": 16, "attack": 5, "range": 4, "role": "ranged"},
	{"id": "goblin_raider", "name": "소형 습격자", "max_hp": 18, "attack": 7, "range": 1, "role": "front"},
	{"id": "cult_archer", "name": "광신 궁수", "max_hp": 17, "attack": 6, "range": 4, "role": "ranged"},
	{"id": "stone_guard", "name": "석상 파수꾼", "max_hp": 30, "attack": 5, "range": 1, "role": "tank"},
	{"id": "venom_bat", "name": "독 박쥐", "max_hp": 14, "attack": 5, "range": 1, "role": "debuff"},
	{"id": "ember_imp", "name": "불씨 임프", "max_hp": 15, "attack": 8, "range": 3, "role": "ranged"},
	{"id": "grave_hound", "name": "묘지 사냥견", "max_hp": 20, "attack": 7, "range": 1, "role": "front"},
	{"id": "mirror_slime", "name": "거울 슬라임", "max_hp": 24, "attack": 4, "range": 1, "role": "tank"},
	{"id": "hex_mender", "name": "저주 치유사", "max_hp": 19, "attack": 4, "range": 3, "role": "support"},
	{"id": "blade_dancer", "name": "칼날 무희", "max_hp": 21, "attack": 8, "range": 1, "role": "front"},
	{"id": "void_seer", "name": "공허 예언자", "max_hp": 18, "attack": 7, "range": 5, "role": "ranged"},
]

const BOSS_ENEMIES := [
	{"id": "gatekeeper_knight", "name": "문지기 기사", "max_hp": 54, "attack": 9, "range": 1, "role": "boss"},
	{"id": "mirror_lord", "name": "거울 군주", "max_hp": 48, "attack": 8, "range": 4, "role": "boss"},
	{"id": "plague_oracle", "name": "역병 예언자", "max_hp": 46, "attack": 10, "range": 3, "role": "boss"},
]

const BOSS_SUPPORTS := [
	{"id": "boss_orb", "name": "저주 보주", "max_hp": 24, "attack": 7, "range": 4, "role": "support"},
	{"id": "bone_guard", "name": "뼈 파수꾼", "max_hp": 26, "attack": 6, "range": 1, "role": "front"},
	{"id": "ritual_flame", "name": "의식 불꽃", "max_hp": 20, "attack": 8, "range": 5, "role": "ranged"},
]


static func build_encounter(zone_type: String, floor_number: int, zone_index: int, seed: int) -> Array[Dictionary]:
	if zone_type == ZONE_BOSS:
		return _build_boss_encounter(floor_number, zone_index, seed)
	return _build_combat_encounter(floor_number, zone_index, seed)


static func get_enemy_count() -> int:
	return COMBAT_ENEMIES.size()


static func get_boss_count() -> int:
	return BOSS_ENEMIES.size()


static func _build_combat_encounter(floor_number: int, zone_index: int, seed: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start_index: int = abs(seed + floor_number * 17 + zone_index * 5) % COMBAT_ENEMIES.size()
	for i in range(2):
		var spec := (COMBAT_ENEMIES[(start_index + i * 3) % COMBAT_ENEMIES.size()] as Dictionary).duplicate(true)
		spec["max_hp"] = int(spec["max_hp"]) + (floor_number - 1) * 4
		spec["attack"] = int(spec["attack"]) + maxi(0, floor_number - 1)
		result.append(spec)
	return result


static func _build_boss_encounter(floor_number: int, zone_index: int, seed: int) -> Array[Dictionary]:
	var boss_index: int = abs(seed + floor_number + zone_index) % BOSS_ENEMIES.size()
	var support_index: int = abs(seed + zone_index * 2) % BOSS_SUPPORTS.size()
	var boss := (BOSS_ENEMIES[boss_index] as Dictionary).duplicate(true)
	var support := (BOSS_SUPPORTS[support_index] as Dictionary).duplicate(true)
	boss["max_hp"] = int(boss["max_hp"]) + (floor_number - 1) * 8
	boss["attack"] = int(boss["attack"]) + floor_number - 1
	support["max_hp"] = int(support["max_hp"]) + (floor_number - 1) * 4
	support["attack"] = int(support["attack"]) + maxi(0, floor_number - 1)
	return [boss, support]
