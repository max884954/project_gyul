class_name CardDungeonState
extends RefCounted

const DungeonCardDatabase := preload("res://scripts/cards/card_database.gd")
const DungeonDeckRuntime := preload("res://scripts/cards/deck_runtime.gd")

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
var event_log: Array[String] = []

var _rng := RandomNumberGenerator.new()
var _seed := 1205


func setup(cells: Array[Vector2i], start_cell: Vector2i, seed: int = 1205) -> void:
	_seed = seed
	_rng.seed = seed
	floor_cells.clear()
	hidden_points.clear()
	revealed_points.clear()
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
	deck.setup(DungeonCardDatabase.build_phase0_deck(), seed)
	start_turn()
	_log("카드 기반 던전 탐험을 시작했습니다. 시작 위치 (%d, %d)." % [party_cell.x, party_cell.y])


func start_turn() -> void:
	turn_number += 1
	block = 0
	deck.draw_cards(DRAW_PER_TURN)
	_log("던전 턴 %d 시작: 이동/수색 카드를 선택하세요." % turn_number)


func end_turn() -> void:
	_log("턴 종료: 던전 위험을 정리하고 다음 손패를 준비합니다.")
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
		"search":
			_search_area(card, target_cell)
		"block":
			block += int(card.get("block", 0))
			_log("%s: 현재 위치를 지키며 방어 +%d." % [card["name"], int(card.get("block", 0))])
		"shield":
			shield += int(card.get("shield", 0))
			_log("%s: 던전 위험 대비 보호막 +%d." % [card["name"], int(card.get("shield", 0))])
		_:
			_log("%s: 아직 Phase 0에서 처리하지 않는 카드입니다." % String(card.get("name", "카드")))
	return true


func is_valid_target(card: Dictionary, target_cell: Vector2i) -> bool:
	var target_mode := String(card.get("target_mode", ""))
	match target_mode:
		DungeonCardDatabase.TARGET_SELF:
			return true
		DungeonCardDatabase.TARGET_MOVE_CELL:
			return floor_cells.has(target_cell) and _distance(party_cell, target_cell) <= int(card.get("range", 0))
		DungeonCardDatabase.TARGET_SEARCH_CELL:
			return floor_cells.has(target_cell) and _distance(party_cell, target_cell) <= int(card.get("range", 0))
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
	return "턴 %d | 위치 (%d, %d) | %s | 숨김 %d" % [
		turn_number,
		party_cell.x,
		party_cell.y,
		deck.get_counts_text(),
		get_hidden_count(),
	]


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


func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _log(message: String) -> void:
	event_log.append(message)
	deck.append_log(message)
	if event_log.size() > 80:
		event_log.remove_at(0)
