class_name DungeonTutorialFlow
extends RefCounted

const STEPS := [
	{"id": "select_start", "event": "start_selected", "text": "시작 위치를 고르고 게임을 시작하세요."},
	{"id": "play_card", "event": "card_played", "text": "카드로 이동, 수색, 교전을 수행하세요."},
	{"id": "end_turn", "event": "turn_ended", "text": "적 의도를 확인하고 턴을 종료하세요."},
	{"id": "choose_reward", "event": "reward_chosen", "text": "전투와 이벤트 보상을 선택하거나 패스하세요."},
	{"id": "finish_run", "event": "run_completed", "text": "보스를 쓰러뜨려 런을 완료하세요."},
]

var step_index := 0
var enabled := true
var completed := false


func reset() -> void:
	step_index = 0
	enabled = true
	completed = false


func get_current_text() -> String:
	if not enabled:
		return ""
	if completed:
		return "튜토리얼 완료"
	return String(STEPS[step_index].get("text", ""))


func advance_on_event(event_name: String) -> bool:
	if not enabled or completed:
		return false
	if String(STEPS[step_index].get("event", "")) != event_name:
		return false
	step_index += 1
	if step_index >= STEPS.size():
		step_index = STEPS.size() - 1
		completed = true
	return true


func toggle_enabled() -> void:
	enabled = not enabled


func to_dict() -> Dictionary:
	return {
		"step_index": step_index,
		"enabled": enabled,
		"completed": completed,
	}


func from_dict(data: Dictionary) -> void:
	step_index = clampi(int(data.get("step_index", 0)), 0, STEPS.size() - 1)
	enabled = bool(data.get("enabled", true))
	completed = bool(data.get("completed", false))
