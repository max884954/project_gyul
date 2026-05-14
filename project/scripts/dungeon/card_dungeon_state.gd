class_name CardDungeonState
extends RefCounted

const DungeonCardDatabase := preload("res://scripts/cards/card_database.gd")
const DungeonDeckRuntime := preload("res://scripts/cards/deck_runtime.gd")

const PHASE_EXPLORE := 0
const PHASE_ENCOUNTER := 1
const DRAW_PER_TURN := 5
const INVALID_CELL := Vector2i(-9999, -9999)

var deck := DungeonDeckRuntime.new()
var floor_cells: Dictionary = {}
var party_cell := INVALID_CELL
var turn_number := 0
var block := 0
var shield := 0
var hidden_points: Dictionary = {}
var revealed_points: Dictionary = {}
var party_units: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var encounter_active := false
var event_log: Array[String] = []

var _rng := RandomNumberGenerator.new()
var _seed := 1205


func setup(cells: Array[Vector2i], start_cell: Vector2i, seed: int = 1205, phase: int = PHASE_EXPLORE) -> void:
	_seed = seed
	_rng.seed = seed
	floor_cells.clear()
	hidden_points.clear()
	revealed_points.clear()
	party_units.clear()
	enemies.clear()
	encounter_active = false
	event_log.clear()
	party_cell = start_cell
	turn_number = 0
	block = 0
	shield = 0

	for cell in cells:
		floor_cells[cell] = true

	if not floor_cells.has(party_cell):
		party_cell = _first_floor_cell()

	_build_hidden_points()
	deck.setup(DungeonCardDatabase.build_phase1_deck() if phase >= PHASE_ENCOUNTER else DungeonCardDatabase.build_phase0_deck(), seed)
	_build_party_units()
	if phase >= PHASE_ENCOUNTER:
		_spawn_test_encounter()
	start_turn()
	_log("카드 기반 던전 탐험을 시작했습니다. 시작 위치 (%d, %d)." % [party_cell.x, party_cell.y])


func start_turn() -> void:
	turn_number += 1
	block = 0
	deck.draw_cards(DRAW_PER_TURN)
	_log("던전 턴 %d 시작: 이동/수색 카드를 선택하세요." % turn_number)


func end_turn() -> void:
	_log("턴 종료: 공개된 적 행동과 던전 위험을 실행합니다.")
	if encounter_active:
		_execute_enemy_intents()
		_tick_statuses()
		_remove_defeated_enemies()
	start_turn()


func use_card(hand_index: int, target_cell: Vector2i) -> bool:
	if hand_index < 0 or hand_index >= deck.hand.size():
		_log("카드 사용 실패: 손패 인덱스가 올바르지 않습니다.")
		return false

	var card := deck.hand[hand_index]
	if not is_valid_target(card, target_cell):
		_log("%s 사용 실패: 대상 칸이 유효하지 않습니다." % String(card.get("name", "카드")))
		return false

	card = deck.play_card_at(hand_index)
	match String(card["effect"]):
		"move_party":
			_move_party(card, target_cell)
		"move_actor":
			_move_actor(card, target_cell)
		"search":
			_search_area(card, target_cell)
		"search_or_weaken":
			if encounter_active and not _get_enemy_at(target_cell).is_empty():
				_apply_status(_get_enemy_at(target_cell), "약화", int(card.get("weak", 1)))
				_log("%s: %s 약화 %d턴." % [card["name"], _get_enemy_at(target_cell)["name"], int(card.get("weak", 1))])
			else:
				_search_area(card, target_cell)
		"attack":
			_attack_enemy(card, target_cell)
		"attack_immobilize":
			_attack_enemy(card, target_cell)
			var target := _get_enemy_at(target_cell)
			if not target.is_empty() and _is_alive(target):
				_apply_status(target, "이동 불가", int(card.get("immobilize", 1)))
				_log("%s: %s 이동 불가 %d턴." % [card["name"], target["name"], int(card.get("immobilize", 1))])
		"sneak_attack":
			_sneak_attack(card, target_cell)
		"taunt":
			var taunt_actor := _get_actor_for_card(card)
			taunt_actor["block"] = int(taunt_actor["block"]) + int(card.get("block", 0))
			_apply_status(taunt_actor, "도발", int(card.get("taunt", 1)))
			_log("%s: %s 도발 %d턴." % [card["name"], taunt_actor["name"], int(card.get("taunt", 1))])
		"weaken":
			var weak_target := _get_enemy_at(target_cell)
			_apply_status(weak_target, "약화", int(card.get("weak", 1)))
			_log("%s: %s 약화 %d턴." % [card["name"], weak_target["name"], int(card.get("weak", 1))])
		"heal":
			_heal_ally(card, target_cell)
		"cleanse":
			_cleanse_ally(card, target_cell)
		"block":
			var block_actor := _get_actor_for_card(card)
			if block_actor.is_empty():
				block += int(card.get("block", 0))
			else:
				block_actor["block"] = int(block_actor["block"]) + int(card.get("block", 0))
			_log("%s: 현재 위치를 지키며 방어 +%d." % [card["name"], int(card.get("block", 0))])
		"shield":
			var shield_target := _get_ally_at(target_cell)
			if shield_target.is_empty():
				shield += int(card.get("shield", 0))
			else:
				shield_target["shield"] = int(shield_target["shield"]) + int(card.get("shield", 0))
			_log("%s: 던전 위험 대비 보호막 +%d." % [card["name"], int(card.get("shield", 0))])
		_:
			_log("%s: 아직 Phase 0에서 처리하지 않는 카드입니다." % String(card.get("name", "카드")))
	_remove_defeated_enemies()
	_plan_enemy_intents()
	return true


func is_valid_target(card: Dictionary, target_cell: Vector2i) -> bool:
	var target_mode := String(card.get("target_mode", ""))
	match target_mode:
		DungeonCardDatabase.TARGET_SELF:
			return true
		DungeonCardDatabase.TARGET_MOVE_CELL:
			var actor := _get_actor_for_card(card)
			var origin: Vector2i = actor["cell"] if encounter_active and not actor.is_empty() else party_cell
			return floor_cells.has(target_cell) and _distance(origin, target_cell) <= int(card.get("range", 0)) and _get_enemy_at(target_cell).is_empty()
		DungeonCardDatabase.TARGET_SEARCH_CELL:
			return floor_cells.has(target_cell) and _distance(party_cell, target_cell) <= int(card.get("range", 0))
		DungeonCardDatabase.TARGET_ENEMY:
			var actor := _get_actor_for_card(card)
			var target := _get_enemy_at(target_cell)
			var actor_cell: Vector2i = actor.get("cell", INVALID_CELL)
			return not actor.is_empty() and not target.is_empty() and _is_alive(target) and _distance(actor_cell, target_cell) <= int(card.get("range", 0))
		DungeonCardDatabase.TARGET_ALLY:
			var actor := _get_actor_for_card(card)
			var ally := _get_ally_at(target_cell)
			var actor_cell: Vector2i = actor.get("cell", INVALID_CELL)
			return not actor.is_empty() and not ally.is_empty() and _distance(actor_cell, target_cell) <= int(card.get("range", 0))
		_:
			return false


func get_revealed_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in revealed_points.keys():
		result.append(cell)
	return result


func get_hidden_count() -> int:
	return hidden_points.size() - revealed_points.size()


func get_summary_text() -> String:
	var mode := "교전" if encounter_active else "탐험"
	return "턴 %d | %s | 위치 (%d, %d) | %s | 숨김 %d" % [
		turn_number,
		mode,
		party_cell.x,
		party_cell.y,
		deck.get_counts_text(),
		get_hidden_count(),
	]


func get_leader_cell() -> Vector2i:
	if party_units.is_empty():
		return party_cell
	return party_units[0]["cell"]


func get_enemy_intent_text() -> String:
	if not encounter_active:
		return "조우 없음"
	var lines: Array[String] = ["적 행동 공개"]
	for enemy in enemies:
		if _is_alive(enemy):
			lines.append("- %s: %s" % [enemy["name"], String(enemy.get("intent_label", "대기"))])
	return "\n".join(lines)


func _move_party(card: Dictionary, target_cell: Vector2i) -> void:
	var before := party_cell
	party_cell = target_cell
	block += int(card.get("block", 0))
	_log("%s: (%d, %d)에서 (%d, %d)로 이동." % [
		card["name"],
		before.x,
		before.y,
		target_cell.x,
		target_cell.y,
	])
	if int(card.get("block", 0)) > 0:
		_log("%s: 이동 후 방어 +%d." % [card["name"], int(card["block"])])


func _move_actor(card: Dictionary, target_cell: Vector2i) -> void:
	var actor := _get_actor_for_card(card)
	if actor.is_empty() or not encounter_active:
		_move_party(card, target_cell)
		return
	var before: Vector2i = actor["cell"]
	actor["cell"] = target_cell
	if actor["id"] == "warrior":
		party_cell = target_cell
	_log("%s: %s가 (%d, %d)에서 (%d, %d)로 이동." % [
		card["name"],
		actor["name"],
		before.x,
		before.y,
		target_cell.x,
		target_cell.y,
	])


func _search_area(card: Dictionary, target_cell: Vector2i) -> void:
	var radius := int(card.get("search_radius", 1))
	var found: Array[String] = []
	for cell in hidden_points.keys():
		if revealed_points.has(cell):
			continue
		if _distance(target_cell, cell) <= radius:
			revealed_points[cell] = hidden_points[cell]
			found.append("%s (%d, %d)" % [String(hidden_points[cell]), cell.x, cell.y])

	if found.is_empty():
		_log("%s: 새로운 단서를 찾지 못했습니다." % card["name"])
	else:
		_log("%s: %s 발견." % [card["name"], ", ".join(found)])


func _attack_enemy(card: Dictionary, target_cell: Vector2i) -> void:
	var actor := _get_actor_for_card(card)
	var target := _get_enemy_at(target_cell)
	_deal_damage(target, int(card.get("damage", 0)), actor, card["name"])


func _sneak_attack(card: Dictionary, target_cell: Vector2i) -> void:
	var actor := _get_actor_for_card(card)
	var target := _get_enemy_at(target_cell)
	var is_flank := _is_flanking(actor, target)
	var damage := int(card.get("flank_damage", 0)) if is_flank else int(card.get("front_damage", 0))
	_deal_damage(target, damage, actor, card["name"])
	_log("%s: %s 판정." % [card["name"], "측후방" if is_flank else "정면"])


func _heal_ally(card: Dictionary, target_cell: Vector2i) -> void:
	var target := _get_ally_at(target_cell)
	if target.is_empty():
		return
	var heal := int(card.get("heal", 0))
	if int(target["hp"]) <= int(round(float(target["max_hp"]) * 0.3)):
		heal += int(card.get("low_hp_bonus", 0))
	var before := int(target["hp"])
	target["hp"] = mini(int(target["max_hp"]), int(target["hp"]) + heal)
	_log("%s: %s HP +%d." % [card["name"], target["name"], int(target["hp"]) - before])


func _cleanse_ally(card: Dictionary, target_cell: Vector2i) -> void:
	var target := _get_ally_at(target_cell)
	if target.is_empty():
		return
	var statuses: Dictionary = target["statuses"]
	for status_name in ["독", "약화", "이동 불가"]:
		if statuses.has(status_name):
			statuses.erase(status_name)
			target["shield"] = int(target["shield"]) + int(card.get("shield", 0))
			_log("%s: %s의 %s 제거, 보호막 +%d." % [card["name"], target["name"], status_name, int(card.get("shield", 0))])
			return
	_log("%s: 제거할 상태이상이 없습니다." % card["name"])


func _deal_damage(target: Dictionary, amount: int, source: Dictionary = {}, label: String = "피해") -> void:
	if target.is_empty() or not _is_alive(target):
		return
	if not source.is_empty() and _get_status_turns(source, "약화") > 0:
		amount = int(floor(float(amount) * 0.8))
	var block_used := mini(int(target.get("block", 0)), amount)
	target["block"] = int(target.get("block", 0)) - block_used
	amount -= block_used
	var shield_used := mini(int(target.get("shield", 0)), amount)
	target["shield"] = int(target.get("shield", 0)) - shield_used
	amount -= shield_used
	target["hp"] = maxi(0, int(target["hp"]) - amount)
	_log("%s: %s에게 %d 피해. HP %d/%d" % [label, target["name"], amount, int(target["hp"]), int(target["max_hp"])])


func _build_party_units() -> void:
	var offsets := {
		DungeonCardDatabase.JOB_WARRIOR: Vector2i(0, 0),
		DungeonCardDatabase.JOB_MAGE: Vector2i(1, 0),
		DungeonCardDatabase.JOB_ROGUE: Vector2i(0, 1),
		DungeonCardDatabase.JOB_CLERIC: Vector2i(1, 1),
	}
	var specs := [
		["warrior", "전사", DungeonCardDatabase.JOB_WARRIOR, 34],
		["mage", "마법사", DungeonCardDatabase.JOB_MAGE, 24],
		["rogue", "도적", DungeonCardDatabase.JOB_ROGUE, 26],
		["cleric", "성직자", DungeonCardDatabase.JOB_CLERIC, 28],
	]
	for spec in specs:
		var cell := _nearest_floor_cell(party_cell + offsets[spec[2]])
		party_units.append(_make_unit(spec[0], spec[1], "ally", spec[2], cell, spec[3], 0, 1))


func _spawn_test_encounter() -> void:
	encounter_active = true
	var enemy_origin := _farthest_floor_cell(party_cell)
	enemies.append(_make_unit("skeleton", "해골 병사", "enemy", "", enemy_origin, 22, 6, 1))
	enemies.append(_make_unit("wraith", "망령", "enemy", "", _nearest_floor_cell(enemy_origin + Vector2i(0, 1)), 16, 5, 4))
	_plan_enemy_intents()
	_log("조우 발생: 현재 던전 격자에서 교전 UI를 엽니다.")


func _make_unit(id: String, display_name: String, team: String, job: String, cell: Vector2i, max_hp: int, attack: int, attack_range: int) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"team": team,
		"job": job,
		"cell": cell,
		"max_hp": max_hp,
		"hp": max_hp,
		"block": 0,
		"shield": 0,
		"attack": attack,
		"range": attack_range,
		"statuses": {},
		"intent_label": "대기",
		"intent_target_id": "",
	}


func _plan_enemy_intents() -> void:
	if not encounter_active:
		return
	for enemy in enemies:
		if not _is_alive(enemy):
			continue
		var target := _choose_enemy_target(enemy)
		if target.is_empty():
			enemy["intent_label"] = "대기"
			enemy["intent_target_id"] = ""
			continue
		enemy["intent_target_id"] = target["id"]
		var distance := _distance(enemy["cell"], target["cell"])
		if _get_status_turns(enemy, "이동 불가") > 0:
			enemy["intent_label"] = "이동 불가로 대기"
		elif distance <= int(enemy["range"]):
			var damage := int(enemy["attack"])
			if _get_status_turns(enemy, "약화") > 0:
				damage = int(floor(float(damage) * 0.8))
			enemy["intent_label"] = "%s 공격 %d" % [target["name"], damage]
		else:
			var destination := _enemy_step_toward(enemy, target)
			enemy["intent_label"] = "%s 추격 (%d, %d)" % [target["name"], destination.x, destination.y]
			enemy["intent_destination"] = destination


func _execute_enemy_intents() -> void:
	for enemy in enemies:
		if not _is_alive(enemy):
			continue
		var target := _get_ally_by_id(String(enemy.get("intent_target_id", "")))
		if target.is_empty() or not _is_alive(target):
			continue
		if String(enemy.get("intent_label", "")).contains("공격") and _distance(enemy["cell"], target["cell"]) <= int(enemy["range"]):
			_deal_damage(target, int(enemy["attack"]), enemy, "%s 공격" % enemy["name"])
		elif enemy.has("intent_destination") and _get_status_turns(enemy, "이동 불가") <= 0:
			var destination: Vector2i = enemy["intent_destination"]
			if floor_cells.has(destination) and _get_ally_at(destination).is_empty() and _get_enemy_at(destination).is_empty():
				enemy["cell"] = destination
				_log("%s가 (%d, %d)로 이동." % [enemy["name"], destination.x, destination.y])


func _choose_enemy_target(enemy: Dictionary) -> Dictionary:
	var alive_allies := _get_alive_allies()
	if alive_allies.is_empty():
		return {}
	var taunt_targets: Array[Dictionary] = []
	for ally in alive_allies:
		if _get_status_turns(ally, "도발") > 0:
			taunt_targets.append(ally)
	var candidates := taunt_targets if not taunt_targets.is_empty() else alive_allies
	var best_target := candidates[0]
	var best_distance := _distance(enemy["cell"], best_target["cell"])
	for candidate in candidates:
		var distance := _distance(enemy["cell"], candidate["cell"])
		if distance < best_distance:
			best_target = candidate
			best_distance = distance
	return best_target


func _enemy_step_toward(enemy: Dictionary, target: Dictionary) -> Vector2i:
	var origin: Vector2i = enemy["cell"]
	var delta: Vector2i = target["cell"] - origin
	var steps: Array[Vector2i] = []
	if abs(delta.x) >= abs(delta.y) and delta.x != 0:
		steps.append(Vector2i(signi(delta.x), 0))
	if delta.y != 0:
		steps.append(Vector2i(0, signi(delta.y)))
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not steps.has(step):
			steps.append(step)
	for step in steps:
		var candidate := origin + step
		if floor_cells.has(candidate) and _get_ally_at(candidate).is_empty() and _get_enemy_at(candidate).is_empty():
			return candidate
	return origin


func _tick_statuses() -> void:
	for unit in party_units + enemies:
		var statuses: Dictionary = unit["statuses"]
		for status_name in statuses.keys():
			statuses[status_name] = int(statuses[status_name]) - 1
			if int(statuses[status_name]) <= 0:
				statuses.erase(status_name)


func _get_actor_for_card(card: Dictionary) -> Dictionary:
	var job := String(card.get("job", ""))
	for unit in party_units:
		if unit["job"] == job and _is_alive(unit):
			return unit
	return {}


func _get_enemy_at(cell: Vector2i) -> Dictionary:
	for enemy in enemies:
		if enemy["cell"] == cell and _is_alive(enemy):
			return enemy
	return {}


func _get_ally_at(cell: Vector2i) -> Dictionary:
	for ally in party_units:
		if ally["cell"] == cell and _is_alive(ally):
			return ally
	return {}


func _get_ally_by_id(unit_id: String) -> Dictionary:
	for ally in party_units:
		if ally["id"] == unit_id:
			return ally
	return {}


func _get_alive_allies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ally in party_units:
		if _is_alive(ally):
			result.append(ally)
	return result


func _remove_defeated_enemies() -> void:
	var alive: Array[Dictionary] = []
	for enemy in enemies:
		if _is_alive(enemy):
			alive.append(enemy)
		else:
			_log("%s 조우 해결." % enemy["name"])
	enemies = alive
	if encounter_active and enemies.is_empty():
		encounter_active = false
		_log("조우 종료: 보상 접근 가능 상태가 되었습니다.")


func _is_flanking(actor: Dictionary, target: Dictionary) -> bool:
	if actor.is_empty() or target.is_empty():
		return false
	var closest_ally := _choose_enemy_target(target)
	if closest_ally.is_empty():
		return false
	return closest_ally["id"] != actor["id"]


func _apply_status(unit: Dictionary, status_name: String, turns: int) -> void:
	if unit.is_empty():
		return
	var statuses: Dictionary = unit["statuses"]
	statuses[status_name] = maxi(int(statuses.get(status_name, 0)), turns)


func _get_status_turns(unit: Dictionary, status_name: String) -> int:
	if unit.is_empty():
		return 0
	var statuses: Dictionary = unit["statuses"]
	return int(statuses.get(status_name, 0))


func _is_alive(unit: Dictionary) -> bool:
	return not unit.is_empty() and int(unit.get("hp", 0)) > 0


func _build_hidden_points() -> void:
	var cells: Array[Vector2i] = []
	for cell in floor_cells.keys():
		if cell != party_cell:
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.x != b.x else a.y < b.y
	)
	var labels := ["숨겨진 보상", "함정 징후", "우회로", "매복 정보"]
	var step := maxi(1, cells.size() / labels.size())
	for i in range(labels.size()):
		if cells.is_empty():
			return
		var index := mini(cells.size() - 1, i * step)
		hidden_points[cells[index]] = labels[i]


func _first_floor_cell() -> Vector2i:
	for cell in floor_cells.keys():
		return cell
	return Vector2i.ZERO


func _nearest_floor_cell(origin: Vector2i) -> Vector2i:
	if floor_cells.has(origin):
		return origin
	var best := _first_floor_cell()
	var best_distance := _distance(origin, best)
	for cell in floor_cells.keys():
		var distance := _distance(origin, cell)
		if distance < best_distance:
			best = cell
			best_distance = distance
	return best


func _farthest_floor_cell(origin: Vector2i) -> Vector2i:
	var best := _first_floor_cell()
	var best_distance := -1
	for cell in floor_cells.keys():
		var distance := _distance(origin, cell)
		if distance > best_distance:
			best = cell
			best_distance = distance
	return best


func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _log(message: String) -> void:
	event_log.append(message)
	deck.append_log(message)
	if event_log.size() > 80:
		event_log.remove_at(0)
