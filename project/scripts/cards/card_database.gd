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


static func build_phase0_deck() -> Array[Dictionary]:
	return _expand_specs(PHASE0_CARDS)


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
