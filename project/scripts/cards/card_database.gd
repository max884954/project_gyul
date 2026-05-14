class_name DungeonCardDatabase
extends RefCounted

const JOB_WARRIOR := "warrior"
const JOB_MAGE := "mage"
const JOB_ROGUE := "rogue"
const JOB_CLERIC := "cleric"

const TYPE_MOVE := "이동"
const TYPE_EXPLORE := "탐험"
const TYPE_ATTACK := "공격"
const TYPE_DEFENSE := "방어"
const TYPE_SKILL := "스킬"
const TYPE_HEAL := "치유"

const TARGET_MOVE_CELL := "move_cell"
const TARGET_SEARCH_CELL := "search_cell"
const TARGET_SELF := "self"
const TARGET_ENEMY := "enemy"
const TARGET_ALLY := "ally"

const PHASE0_CARDS := [
	{
		"id": "warrior_move",
		"name": "전사 이동",
		"job": JOB_WARRIOR,
		"type": TYPE_MOVE,
		"effect": "move_party",
		"target_mode": TARGET_MOVE_CELL,
		"range": 3,
		"count": 4,
		"description": "파티를 던전 격자에서 3칸 이동합니다."
	},
	{
		"id": "warrior_guarded_step",
		"name": "방패 전진",
		"job": JOB_WARRIOR,
		"type": TYPE_MOVE,
		"effect": "move_party",
		"target_mode": TARGET_MOVE_CELL,
		"range": 2,
		"block": 4,
		"count": 2,
		"description": "파티를 2칸 이동하고 다음 위험에 대비합니다."
	},
	{
		"id": "warrior_hold_line",
		"name": "진형 유지",
		"job": JOB_WARRIOR,
		"type": TYPE_DEFENSE,
		"effect": "block",
		"target_mode": TARGET_SELF,
		"block": 6,
		"count": 2,
		"description": "현재 위치를 유지하고 방어 태세를 갖춥니다."
	},
	{
		"id": "warrior_scout_corridor",
		"name": "통로 경계",
		"job": JOB_WARRIOR,
		"type": TYPE_EXPLORE,
		"effect": "search",
		"target_mode": TARGET_SEARCH_CELL,
		"range": 2,
		"search_radius": 1,
		"count": 2,
		"description": "가까운 통로의 매복과 함정 징후를 확인합니다."
	},
	{
		"id": "mage_blink",
		"name": "점멸 이동",
		"job": JOB_MAGE,
		"type": TYPE_MOVE,
		"effect": "move_party",
		"target_mode": TARGET_MOVE_CELL,
		"range": 4,
		"count": 3,
		"description": "마법으로 파티를 4칸까지 이동시킵니다."
	},
	{
		"id": "mage_arcane_sight",
		"name": "비전 탐지",
		"job": JOB_MAGE,
		"type": TYPE_EXPLORE,
		"effect": "search",
		"target_mode": TARGET_SEARCH_CELL,
		"range": 5,
		"search_radius": 2,
		"count": 4,
		"description": "넓은 범위의 숨겨진 보상, 함정, 우회로를 드러냅니다."
	},
	{
		"id": "mage_barrier",
		"name": "마력 장벽",
		"job": JOB_MAGE,
		"type": TYPE_DEFENSE,
		"effect": "shield",
		"target_mode": TARGET_SELF,
		"shield": 8,
		"count": 2,
		"description": "던전 위험에 대비해 보호막을 준비합니다."
	},
	{
		"id": "mage_probe",
		"name": "마력 탐침",
		"job": JOB_MAGE,
		"type": TYPE_EXPLORE,
		"effect": "search",
		"target_mode": TARGET_SEARCH_CELL,
		"range": 4,
		"search_radius": 1,
		"count": 1,
		"description": "멀리 있는 의심 지점을 정밀 탐색합니다."
	},
]

const PHASE1_CARDS := [
	{"id": "warrior_strike", "name": "강타", "job": JOB_WARRIOR, "type": TYPE_ATTACK, "effect": "attack", "target_mode": TARGET_ENEMY, "range": 1, "damage": 8, "count": 3, "description": "인접 적 1명에게 8 피해."},
	{"id": "warrior_guard", "name": "방패 올리기", "job": JOB_WARRIOR, "type": TYPE_DEFENSE, "effect": "block", "target_mode": TARGET_SELF, "block": 8, "count": 2, "description": "전사가 방어 8을 얻습니다."},
	{"id": "warrior_taunt", "name": "도발", "job": JOB_WARRIOR, "type": TYPE_SKILL, "effect": "taunt", "target_mode": TARGET_SELF, "block": 3, "taunt": 2, "count": 1, "description": "전사가 방어 3과 도발 2턴을 얻습니다."},
	{"id": "warrior_move", "name": "전사 이동", "job": JOB_WARRIOR, "type": TYPE_MOVE, "effect": "move_actor", "target_mode": TARGET_MOVE_CELL, "range": 3, "count": 2, "description": "전사를 3칸 이동합니다."},
	{"id": "warrior_scout", "name": "통로 경계", "job": JOB_WARRIOR, "type": TYPE_EXPLORE, "effect": "search", "target_mode": TARGET_SEARCH_CELL, "range": 2, "search_radius": 1, "count": 2, "description": "근처 위험 정보를 드러냅니다."},

	{"id": "mage_fireball", "name": "화염구", "job": JOB_MAGE, "type": TYPE_ATTACK, "effect": "attack", "target_mode": TARGET_ENEMY, "range": 5, "damage": 10, "count": 2, "description": "사거리 5의 적 1명에게 10 피해."},
	{"id": "mage_frost_arrow", "name": "빙결 화살", "job": JOB_MAGE, "type": TYPE_ATTACK, "effect": "attack_immobilize", "target_mode": TARGET_ENEMY, "range": 5, "damage": 7, "immobilize": 1, "count": 2, "description": "7 피해와 이동 불가 1턴."},
	{"id": "mage_barrier", "name": "마력 장벽", "job": JOB_MAGE, "type": TYPE_DEFENSE, "effect": "shield", "target_mode": TARGET_ALLY, "range": 5, "shield": 10, "count": 2, "description": "아군 1명에게 보호막 10."},
	{"id": "mage_move", "name": "마법사 이동", "job": JOB_MAGE, "type": TYPE_MOVE, "effect": "move_actor", "target_mode": TARGET_MOVE_CELL, "range": 3, "count": 2, "description": "마법사를 3칸 이동합니다."},
	{"id": "mage_arcane_sight", "name": "비전 탐지", "job": JOB_MAGE, "type": TYPE_EXPLORE, "effect": "search", "target_mode": TARGET_SEARCH_CELL, "range": 5, "search_radius": 2, "count": 2, "description": "숨겨진 정보와 적 움직임을 읽습니다."},

	{"id": "rogue_sneak_attack", "name": "기습", "job": JOB_ROGUE, "type": TYPE_ATTACK, "effect": "sneak_attack", "target_mode": TARGET_ENEMY, "range": 1, "front_damage": 6, "flank_damage": 12, "count": 3, "description": "측후방이면 12 피해, 정면이면 6 피해."},
	{"id": "rogue_smoke", "name": "연막탄", "job": JOB_ROGUE, "type": "회피", "effect": "weaken", "target_mode": TARGET_ENEMY, "range": 3, "weak": 1, "count": 2, "description": "대상 적을 약화 1턴."},
	{"id": "rogue_search", "name": "수색", "job": JOB_ROGUE, "type": TYPE_EXPLORE, "effect": "search_or_weaken", "target_mode": TARGET_SEARCH_CELL, "range": 4, "search_radius": 1, "weak": 1, "count": 3, "description": "던전 정보 탐색. 적 대상이면 약화."},
	{"id": "rogue_move", "name": "도적 이동", "job": JOB_ROGUE, "type": TYPE_MOVE, "effect": "move_actor", "target_mode": TARGET_MOVE_CELL, "range": 5, "count": 2, "description": "도적을 5칸 이동합니다."},

	{"id": "cleric_heal", "name": "치유", "job": JOB_CLERIC, "type": TYPE_HEAL, "effect": "heal", "target_mode": TARGET_ALLY, "range": 5, "heal": 12, "low_hp_bonus": 6, "count": 3, "description": "아군 1명 HP 12 회복. 낮은 HP면 +6."},
	{"id": "cleric_prayer", "name": "기도", "job": JOB_CLERIC, "type": TYPE_DEFENSE, "effect": "block", "target_mode": TARGET_SELF, "block": 5, "count": 2, "description": "성직자가 방어 5를 얻습니다."},
	{"id": "cleric_cleanse", "name": "정화", "job": JOB_CLERIC, "type": TYPE_SKILL, "effect": "cleanse", "target_mode": TARGET_ALLY, "range": 5, "shield": 5, "count": 2, "description": "아군의 나쁜 상태 1개 제거, 성공 시 보호막 5."},
	{"id": "cleric_holy_burst", "name": "신성 폭발", "job": JOB_CLERIC, "type": TYPE_ATTACK, "effect": "attack", "target_mode": TARGET_ENEMY, "range": 2, "damage": 8, "count": 2, "description": "가까운 적에게 신성 피해 8."},
	{"id": "cleric_move", "name": "성직자 이동", "job": JOB_CLERIC, "type": TYPE_MOVE, "effect": "move_actor", "target_mode": TARGET_MOVE_CELL, "range": 3, "count": 1, "description": "성직자를 3칸 이동합니다."},
]


static func build_phase0_deck() -> Array[Dictionary]:
	return _expand_specs(PHASE0_CARDS)


static func build_phase1_deck() -> Array[Dictionary]:
	return _expand_specs(PHASE1_CARDS)


static func _expand_specs(specs: Array) -> Array[Dictionary]:
	var deck: Array[Dictionary] = []
	for spec in specs:
		var count := int(spec.get("count", 1))
		for copy_index in range(count):
			var card := (spec as Dictionary).duplicate(true)
			card["instance_id"] = "%s_%02d" % [String(card["id"]), copy_index + 1]
			deck.append(card)
	return deck


static func get_job_label(job: String) -> String:
	match job:
		JOB_WARRIOR:
			return "전사"
		JOB_MAGE:
			return "마법사"
		JOB_ROGUE:
			return "도적"
		JOB_CLERIC:
			return "성직자"
		_:
			return job
