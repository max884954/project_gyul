@tool
extends Node3D

const CardDungeonState := preload("res://scripts/dungeon/card_dungeon_state.gd")
const DungeonCardDatabase := preload("res://scripts/cards/card_database.gd")
const DungeonSaveRuntime := preload("res://scripts/system/dungeon_save_runtime.gd")
const DungeonTutorialFlow := preload("res://scripts/tutorial/dungeon_tutorial_flow.gd")

const MAP_SIZE := Vector2i(34, 26)
const ROOM_COUNT := 7
const ROOM_PLACEMENT_ATTEMPTS := 120
const ROOM_MIN_SIZE := Vector2i(3, 3)
const ROOM_MAX_SIZE := Vector2i(8, 6)
const MIN_ROOM_TILE_COUNT := 12
const ROOM_PADDING := 1
const INVALID_CELL := Vector2i(-9999, -9999)

const TILE_SIZE := 1.0
const TILE_STEP := 1.04
const TILE_BORDER_WIDTH := 0.035
const TILE_BORDER_HEIGHT := 0.018
const GENERATED_ROOT_NAME := "GeneratedFloor"
const CHARACTER_ROOT_NAME := "TestCharacter"
const UNIT_ROOT_NAME := "EncounterUnits"
const FLOOR_TEXTURE_PATH := "res://assets/art/tilesets/checker_floor.png"
const CHARACTER_TEXTURE_PATH := "res://assets/art/characters/test_side_character_imagegen_trimmed.png"

const CAMERA_TARGET := Vector3.ZERO
const CAMERA_DISTANCE := 14.0
const CAMERA_FIXED_PITCH := deg_to_rad(30.0)
const CAMERA_VIEW_YAWS := [
	deg_to_rad(45.0),
	deg_to_rad(315.0),
	deg_to_rad(225.0),
	deg_to_rad(135.0),
]
const CAMERA_TURN_SPEED := 7.0
const CAMERA_ZOOM_DRAG_SPEED := 0.025
const CAMERA_ZOOM_WHEEL_STEP := 0.55
const CAMERA_MIN_SIZE := 5.0
const CAMERA_MAX_SIZE := 18.0

const CHARACTER_WORLD_HEIGHT := TILE_SIZE * 2.2
const CHARACTER_FLOOR_OFFSET := 0.01
const CHARACTER_FACING_YAW := deg_to_rad(90.0)

@onready var _start_button: Button = %StartButton
@onready var _status_label: Label = %StatusLabel

var _rng := RandomNumberGenerator.new()
var _camera: Camera3D
var _camera_view_index := 0
var _camera_current_yaw := CAMERA_VIEW_YAWS[0]
var _camera_target_yaw := CAMERA_VIEW_YAWS[0]
var _map_center := Vector2.ZERO
var _room_rects: Array[Rect2i] = []
var _floor_cells: Dictionary = {}
var _tiles: Dictionary = {}
var _selected_start_cell := INVALID_CELL
var _hovered_cell := INVALID_CELL
var _game_started := false
var _is_zoom_dragging := false

var _floor_material: StandardMaterial3D
var _focus_material: StandardMaterial3D
var _start_material: StandardMaterial3D
var _revealed_material: StandardMaterial3D
var _border_material: StandardMaterial3D
var _character_material: StandardMaterial3D
var _character_texture: Texture2D
var _character_node: MeshInstance3D
var _ally_token_material: StandardMaterial3D
var _enemy_token_material: StandardMaterial3D
var _card_state := CardDungeonState.new()
var _save_runtime := DungeonSaveRuntime.new()
var _tutorial := DungeonTutorialFlow.new()
var _selected_hand_index := -1
var _deck_label: Label
var _card_help_label: Label
var _run_action_container: HBoxContainer
var _hand_container: HBoxContainer
var _save_button: Button
var _load_button: Button
var _tutorial_button: Button
var _end_turn_button: Button
var _log_view: RichTextLabel


func _ready() -> void:
	if Engine.is_editor_hint():
		_rng.seed = 1205
	else:
		_rng.randomize()

	_setup_ui()
	_setup_camera()
	_generate_dungeon()
	_rebuild_floor()
	set_process(true)


func _setup_ui() -> void:
	if _start_button != null:
		_start_button.disabled = true
		_start_button.pressed.connect(_start_game)

	_update_status("시작 위치를 선택하세요.")
	_build_card_ui()


func _setup_camera() -> void:
	_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		return

	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 13.0
	_camera.current = true
	_apply_camera_transform()


func _process(delta: float) -> void:
	_update_camera_motion(delta)
	_update_hovered_tile()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventKey:
		_handle_key(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := _get_mouse_grid_cell()
		if _game_started:
			_use_selected_card_on_cell(cell)
		else:
			_select_start_cell(cell)
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		_is_zoom_dragging = event.pressed
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_camera(-CAMERA_ZOOM_WHEEL_STEP)
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_camera(CAMERA_ZOOM_WHEEL_STEP)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _is_zoom_dragging:
		_zoom_camera(event.relative.y * CAMERA_ZOOM_DRAG_SPEED)


func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_E:
		_rotate_camera_view(-1)
	elif event.keycode == KEY_Q:
		_rotate_camera_view(1)


func _rotate_camera_view(direction: int) -> void:
	_camera_view_index = wrapi(_camera_view_index + direction, 0, CAMERA_VIEW_YAWS.size())
	_camera_target_yaw = CAMERA_VIEW_YAWS[_camera_view_index]


func _update_camera_motion(delta: float) -> void:
	var yaw_difference := wrapf(_camera_target_yaw - _camera_current_yaw, -PI, PI)
	if absf(yaw_difference) <= 0.001:
		_camera_current_yaw = _camera_target_yaw
		return

	var interpolation_weight := 1.0 - exp(-CAMERA_TURN_SPEED * delta)
	_camera_current_yaw += yaw_difference * interpolation_weight
	_apply_camera_transform()


func _apply_camera_transform() -> void:
	if _camera == null:
		return

	var horizontal_distance := cos(CAMERA_FIXED_PITCH) * CAMERA_DISTANCE
	_camera.position = CAMERA_TARGET + Vector3(
		sin(_camera_current_yaw) * horizontal_distance,
		sin(CAMERA_FIXED_PITCH) * CAMERA_DISTANCE,
		cos(_camera_current_yaw) * horizontal_distance
	)
	_camera.look_at(CAMERA_TARGET, Vector3.UP)


func _zoom_camera(amount: float) -> void:
	if _camera == null:
		return

	_camera.size = clampf(_camera.size + amount, CAMERA_MIN_SIZE, CAMERA_MAX_SIZE)
	_update_hovered_tile()


func _generate_dungeon() -> void:
	_floor_cells.clear()
	_room_rects.clear()
	_selected_start_cell = INVALID_CELL
	_game_started = false

	for _room_index in ROOM_COUNT:
		_try_place_room()

	if _room_rects.is_empty():
		_room_rects.append(Rect2i(Vector2i(2, 2), Vector2i(4, 4)))

	_room_rects.sort_custom(_sort_rooms_by_position)
	for room in _room_rects:
		_carve_room(room)

	for i in range(1, _room_rects.size()):
		_carve_corridor(_room_center(_room_rects[i - 1]), _room_center(_room_rects[i]))

	_update_map_center()


func _try_place_room() -> void:
	for _attempt in ROOM_PLACEMENT_ATTEMPTS:
		var room_size := _random_room_size()
		var max_x := MAP_SIZE.x - room_size.x - 2
		var max_y := MAP_SIZE.y - room_size.y - 2
		if max_x <= 1 or max_y <= 1:
			return

		var room := Rect2i(
			Vector2i(_rng.randi_range(1, max_x), _rng.randi_range(1, max_y)),
			room_size
		)
		if _can_place_room(room):
			_room_rects.append(room)
			return


func _random_room_size() -> Vector2i:
	for _attempt in 20:
		var size := Vector2i(
			_rng.randi_range(ROOM_MIN_SIZE.x, ROOM_MAX_SIZE.x),
			_rng.randi_range(ROOM_MIN_SIZE.y, ROOM_MAX_SIZE.y)
		)
		if size.x * size.y >= MIN_ROOM_TILE_COUNT:
			return size

	return Vector2i(4, 3)


func _can_place_room(room: Rect2i) -> bool:
	for existing_room in _room_rects:
		if _rooms_overlap(room, existing_room, ROOM_PADDING):
			return false
	return true


func _rooms_overlap(a: Rect2i, b: Rect2i, padding: int) -> bool:
	return (
		a.position.x - padding < b.position.x + b.size.x + padding
		and a.position.x + a.size.x + padding > b.position.x - padding
		and a.position.y - padding < b.position.y + b.size.y + padding
		and a.position.y + a.size.y + padding > b.position.y - padding
	)


func _sort_rooms_by_position(a: Rect2i, b: Rect2i) -> bool:
	var a_center := _room_center(a)
	var b_center := _room_center(b)
	return a_center.x < b_center.x if a_center.x != b_center.x else a_center.y < b_center.y


func _carve_room(room: Rect2i) -> void:
	for y in range(room.position.y, room.position.y + room.size.y):
		for x in range(room.position.x, room.position.x + room.size.x):
			_floor_cells[Vector2i(x, y)] = true


func _carve_corridor(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if _rng.randi_range(0, 1) == 0:
		_carve_horizontal_corridor(from_cell.x, to_cell.x, from_cell.y)
		_carve_vertical_corridor(from_cell.y, to_cell.y, to_cell.x)
	else:
		_carve_vertical_corridor(from_cell.y, to_cell.y, from_cell.x)
		_carve_horizontal_corridor(from_cell.x, to_cell.x, to_cell.y)


func _carve_horizontal_corridor(from_x: int, to_x: int, y: int) -> void:
	for x in range(mini(from_x, to_x), maxi(from_x, to_x) + 1):
		_floor_cells[Vector2i(x, y)] = true


func _carve_vertical_corridor(from_y: int, to_y: int, x: int) -> void:
	for y in range(mini(from_y, to_y), maxi(from_y, to_y) + 1):
		_floor_cells[Vector2i(x, y)] = true


func _room_center(room: Rect2i) -> Vector2i:
	return room.position + Vector2i(room.size.x / 2, room.size.y / 2)


func _update_map_center() -> void:
	var min_cell := Vector2i(99999, 99999)
	var max_cell := Vector2i(-99999, -99999)
	for cell in _floor_cells.keys():
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)

	_map_center = Vector2(
		(float(min_cell.x) + float(max_cell.x)) * 0.5,
		(float(min_cell.y) + float(max_cell.y)) * 0.5
	)


func _rebuild_floor() -> void:
	var previous := get_node_or_null(GENERATED_ROOT_NAME)
	if previous != null:
		remove_child(previous)
		previous.free()

	_remove_character()
	_tiles.clear()
	_hovered_cell = INVALID_CELL

	var root := Node3D.new()
	root.name = GENERATED_ROOT_NAME
	add_child(root)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(TILE_SIZE, TILE_SIZE)

	var horizontal_border_mesh := BoxMesh.new()
	horizontal_border_mesh.size = Vector3(TILE_SIZE + TILE_BORDER_WIDTH, TILE_BORDER_HEIGHT, TILE_BORDER_WIDTH)

	var vertical_border_mesh := BoxMesh.new()
	vertical_border_mesh.size = Vector3(TILE_BORDER_WIDTH, TILE_BORDER_HEIGHT, TILE_SIZE + TILE_BORDER_WIDTH)

	for cell in _floor_cells.keys():
		var tile_position := _get_tile_position(cell)
		var tile := MeshInstance3D.new()
		tile.name = "Floor_%02d_%02d" % [cell.x, cell.y]
		tile.mesh = floor_mesh
		tile.material_override = _get_floor_material()
		tile.position = tile_position
		root.add_child(tile)
		_add_tile_border(root, cell, tile_position, horizontal_border_mesh, vertical_border_mesh)
		_tiles[cell] = tile


func _select_start_cell(cell: Vector2i) -> void:
	if _game_started or not _tiles.has(cell):
		return

	var previous_start := _selected_start_cell
	_selected_start_cell = cell
	_set_tile_focused(previous_start, false)
	_set_tile_focused(_selected_start_cell, false)
	_place_character(cell)

	if _start_button != null:
		_start_button.disabled = false
	_update_status("시작 위치: (%d, %d)" % [cell.x, cell.y])


func _start_game() -> void:
	if _selected_start_cell == INVALID_CELL:
		return

	_game_started = true
	_selected_hand_index = -1
	_card_state.setup(_get_floor_cells_array(), _selected_start_cell, 1205, CardDungeonState.PHASE_RUN)
	if _start_button != null:
		_start_button.disabled = true
		_start_button.text = "게임 시작됨"
	_update_status("카드 기반 탐험 시작 - 이동/수색 카드를 선택하세요.")
	_tutorial.advance_on_event("start_selected")
	_place_character(_card_state.get_leader_cell())
	_sync_unit_tokens()
	_refresh_card_ui()


func _place_character(cell: Vector2i) -> void:
	_remove_character()

	var root := Node3D.new()
	root.name = CHARACTER_ROOT_NAME
	root.position = _get_tile_position(cell)
	root.rotation = Vector3(0.0, CHARACTER_FACING_YAW, 0.0)
	add_child(root)

	var mesh := QuadMesh.new()
	var character_size := _get_character_quad_size()
	mesh.size = character_size

	_character_node = MeshInstance3D.new()
	_character_node.name = "Sprite"
	_character_node.mesh = mesh
	_character_node.material_override = _get_character_material()
	_character_node.position = Vector3(0.0, character_size.y * 0.5 + CHARACTER_FLOOR_OFFSET, 0.0)
	_character_node.rotation = Vector3.ZERO
	root.add_child(_character_node)


func _remove_character() -> void:
	var previous := get_node_or_null(CHARACTER_ROOT_NAME)
	if previous != null:
		remove_child(previous)
		previous.free()
	_character_node = null


func _update_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func _get_floor_material() -> StandardMaterial3D:
	if _floor_material != null:
		return _floor_material

	_floor_material = StandardMaterial3D.new()
	_floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_floor_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_floor_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_floor_material.albedo_color = Color.WHITE
	_floor_material.albedo_texture = _load_floor_texture()
	return _floor_material


func _get_focus_material() -> StandardMaterial3D:
	if _focus_material != null:
		return _focus_material

	_focus_material = StandardMaterial3D.new()
	_focus_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_focus_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_focus_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_focus_material.albedo_color = Color(1.0, 0.86, 0.32, 1.0)
	_focus_material.albedo_texture = _load_floor_texture()
	return _focus_material


func _get_start_material() -> StandardMaterial3D:
	if _start_material != null:
		return _start_material

	_start_material = StandardMaterial3D.new()
	_start_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_start_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_start_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_start_material.albedo_color = Color(0.35, 1.0, 0.55, 1.0)
	_start_material.albedo_texture = _load_floor_texture()
	return _start_material


func _get_revealed_material() -> StandardMaterial3D:
	if _revealed_material != null:
		return _revealed_material

	_revealed_material = StandardMaterial3D.new()
	_revealed_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_revealed_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_revealed_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_revealed_material.albedo_color = Color(0.35, 0.62, 1.0, 1.0)
	_revealed_material.albedo_texture = _load_floor_texture()
	return _revealed_material


func _get_border_material() -> StandardMaterial3D:
	if _border_material != null:
		return _border_material

	_border_material = StandardMaterial3D.new()
	_border_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_border_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_border_material.albedo_color = Color(0.45, 0.45, 0.45, 1.0)
	return _border_material


func _get_character_material() -> StandardMaterial3D:
	if _character_material != null:
		return _character_material

	_character_material = StandardMaterial3D.new()
	_character_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_character_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_character_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_character_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_character_material.albedo_color = Color.WHITE
	_character_material.albedo_texture = _get_character_texture()
	return _character_material


func _get_ally_token_material() -> StandardMaterial3D:
	if _ally_token_material != null:
		return _ally_token_material

	_ally_token_material = StandardMaterial3D.new()
	_ally_token_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ally_token_material.albedo_color = Color(0.2, 0.75, 1.0, 1.0)
	return _ally_token_material


func _get_enemy_token_material() -> StandardMaterial3D:
	if _enemy_token_material != null:
		return _enemy_token_material

	_enemy_token_material = StandardMaterial3D.new()
	_enemy_token_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_enemy_token_material.albedo_color = Color(1.0, 0.25, 0.22, 1.0)
	return _enemy_token_material


func _get_character_texture() -> Texture2D:
	if _character_texture == null:
		_character_texture = _load_texture(CHARACTER_TEXTURE_PATH)
	return _character_texture


func _get_character_quad_size() -> Vector2:
	var texture := _get_character_texture()
	if texture == null or texture.get_height() <= 0:
		return Vector2(CHARACTER_WORLD_HEIGHT * 0.5, CHARACTER_WORLD_HEIGHT)

	var aspect_ratio := float(texture.get_width()) / float(texture.get_height())
	return Vector2(CHARACTER_WORLD_HEIGHT * aspect_ratio, CHARACTER_WORLD_HEIGHT)


func _load_floor_texture() -> Texture2D:
	return _load_texture(FLOOR_TEXTURE_PATH)


func _load_texture(path: String) -> Texture2D:
	if FileAccess.file_exists("%s.import" % path):
		var imported_texture := load(path) as Texture2D
		if imported_texture != null:
			return imported_texture

	var image := Image.new()
	if image.load(path) != OK:
		return null

	return ImageTexture.create_from_image(image)


func _update_hovered_tile() -> void:
	var hovered_cell := _get_mouse_grid_cell()
	if hovered_cell == _hovered_cell:
		return

	_set_tile_focused(_hovered_cell, false)
	_hovered_cell = hovered_cell
	_set_tile_focused(_hovered_cell, true)


func _get_mouse_grid_cell() -> Vector2i:
	if _camera == null:
		return INVALID_CELL

	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := _camera.project_ray_origin(mouse_position)
	var ray_direction := _camera.project_ray_normal(mouse_position)
	if absf(ray_direction.y) < 0.0001:
		return INVALID_CELL

	var distance_to_floor := -ray_origin.y / ray_direction.y
	if distance_to_floor < 0.0:
		return INVALID_CELL

	var hit_position := ray_origin + ray_direction * distance_to_floor
	var x := int(round(hit_position.x / TILE_STEP + _map_center.x))
	var y := int(round(hit_position.z / TILE_STEP + _map_center.y))
	var cell := Vector2i(x, y)
	if not _tiles.has(cell):
		return INVALID_CELL

	var tile_position := _get_tile_position(cell)
	if absf(hit_position.x - tile_position.x) > TILE_SIZE * 0.5:
		return INVALID_CELL
	if absf(hit_position.z - tile_position.z) > TILE_SIZE * 0.5:
		return INVALID_CELL

	return cell


func _set_tile_focused(cell: Vector2i, focused: bool) -> void:
	var tile := _tiles.get(cell) as MeshInstance3D
	if tile == null:
		return

	if cell == _selected_start_cell:
		tile.material_override = _get_start_material()
		tile.position = _get_tile_position(cell) + Vector3.UP * 0.06
	elif focused:
		tile.material_override = _get_focus_material()
		tile.position = _get_tile_position(cell) + Vector3.UP * 0.04
	elif _game_started and _card_state.revealed_points.has(cell):
		tile.material_override = _get_revealed_material()
		tile.position = _get_tile_position(cell) + Vector3.UP * 0.02
	else:
		tile.material_override = _get_floor_material()
		tile.position = _get_tile_position(cell)
	tile.scale = Vector3.ONE


func _build_card_ui() -> void:
	var canvas := get_node_or_null("CanvasLayer") as CanvasLayer
	if canvas == null or Engine.is_editor_hint():
		return

	var panel := PanelContainer.new()
	panel.name = "CardPanel"
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 24.0
	panel.offset_top = -230.0
	panel.offset_right = -24.0
	panel.offset_bottom = -24.0
	canvas.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	_deck_label = Label.new()
	root.add_child(_deck_label)

	_card_help_label = Label.new()
	_card_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_card_help_label)

	_run_action_container = HBoxContainer.new()
	_run_action_container.add_theme_constant_override("separation", 8)
	root.add_child(_run_action_container)

	_hand_container = HBoxContainer.new()
	_hand_container.add_theme_constant_override("separation", 8)
	root.add_child(_hand_container)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)

	_save_button = Button.new()
	_save_button.text = "저장"
	_save_button.disabled = true
	_save_button.pressed.connect(_on_save_pressed)
	bottom.add_child(_save_button)

	_load_button = Button.new()
	_load_button.text = "불러오기"
	_load_button.pressed.connect(_on_load_pressed)
	bottom.add_child(_load_button)

	_tutorial_button = Button.new()
	_tutorial_button.text = "가이드"
	_tutorial_button.pressed.connect(_on_tutorial_pressed)
	bottom.add_child(_tutorial_button)

	_end_turn_button = Button.new()
	_end_turn_button.text = "턴 종료"
	_end_turn_button.disabled = true
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	bottom.add_child(_end_turn_button)

	_log_view = RichTextLabel.new()
	_log_view.custom_minimum_size = Vector2(520.0, 76.0)
	_log_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_view.scroll_following = true
	bottom.add_child(_log_view)
	_refresh_card_ui()


func _refresh_card_ui() -> void:
	if _deck_label == null or _hand_container == null:
		return

	for child in _hand_container.get_children():
		child.queue_free()
	if _run_action_container != null:
		for child in _run_action_container.get_children():
			child.queue_free()

	if not _game_started:
		_deck_label.text = "카드 덱: 게임 시작 후 표시"
		_card_help_label.text = _tutorial.get_current_text()
		if _save_button != null:
			_save_button.disabled = true
		if _load_button != null:
			_load_button.disabled = not _save_runtime.has_save()
		if _end_turn_button != null:
			_end_turn_button.disabled = true
		return

	var run_action_locked := _card_state.run_state in [
		CardDungeonState.RUN_STATE_REWARD,
		CardDungeonState.RUN_STATE_REST,
		CardDungeonState.RUN_STATE_SHOP,
		CardDungeonState.RUN_STATE_COMPLETE,
	]
	_deck_label.text = "%s | %s" % [_card_state.get_summary_text(), _card_state.get_run_action_text().replace("\n", " / ")]
	_card_help_label.text = _card_state.get_run_action_text() if run_action_locked else "카드를 고른 뒤 던전 타일을 클릭하세요. 이동, 탐색, 교전 모두 카드로만 진행됩니다."
	if _tutorial.enabled:
		_card_help_label.text = "%s\n%s" % [_tutorial.get_current_text(), _card_help_label.text]
	if _selected_hand_index >= 0 and _selected_hand_index < _card_state.deck.hand.size():
		var selected_card := _card_state.deck.hand[_selected_hand_index]
		_card_help_label.text = "%s 대상 선택 중: %s" % [selected_card["name"], selected_card["description"]]

	_build_run_action_buttons()

	for i in range(_card_state.deck.hand.size()):
		var card := _card_state.deck.hand[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(150.0, 70.0)
		button.text = "%s\n%s / %s" % [
			String(card["name"]),
			String(card["type"]),
			DungeonCardDatabase.get_job_label(String(card["job"])),
		]
		button.tooltip_text = String(card["description"])
		button.disabled = run_action_locked or i == _selected_hand_index
		button.pressed.connect(_on_card_button_pressed.bind(i))
		_hand_container.add_child(button)

	if _end_turn_button != null:
		_end_turn_button.disabled = run_action_locked
	if _save_button != null:
		_save_button.disabled = false
	if _load_button != null:
		_load_button.disabled = not _save_runtime.has_save()
	if _tutorial_button != null:
		_tutorial_button.text = "가이드 끄기" if _tutorial.enabled else "가이드 켜기"
	if _log_view != null:
		_log_view.text = "\n".join(_card_state.event_log.slice(maxi(0, _card_state.event_log.size() - 5), _card_state.event_log.size()))


func _build_run_action_buttons() -> void:
	if _run_action_container == null:
		return

	match _card_state.run_state:
		CardDungeonState.RUN_STATE_REWARD:
			for i in range(_card_state.reward_options.size()):
				var reward := _card_state.reward_options[i]
				_add_run_action_button(
					"%s\n%s" % [String(reward.get("name", "보상")), DungeonCardDatabase.get_job_label(String(reward.get("job", "")))],
					_on_reward_button_pressed.bind(i)
				)
			_add_run_action_button("패스\n+10G", _on_reward_button_pressed.bind(-1))
		CardDungeonState.RUN_STATE_REST:
			_add_run_action_button("회복", _on_rest_heal_pressed)
			_add_run_action_button("강화", _on_rest_upgrade_pressed)
			_add_run_action_button("제거", _on_rest_remove_pressed)
		CardDungeonState.RUN_STATE_SHOP:
			_add_run_action_button("구매\n30G", _on_shop_buy_pressed, _card_state.gold < 30)
			_add_run_action_button("강화\n20G", _on_shop_upgrade_pressed, _card_state.gold < 20)
			_add_run_action_button("나가기", _on_shop_leave_pressed)
		CardDungeonState.RUN_STATE_COMPLETE:
			_add_run_action_button("런 완료", _on_run_complete_pressed, true)


func _add_run_action_button(label: String, callback: Callable, disabled: bool = false) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(118.0, 54.0)
	button.text = label
	button.disabled = disabled
	button.pressed.connect(callback)
	_run_action_container.add_child(button)


func _on_save_pressed() -> void:
	if not _game_started:
		return
	if _save_runtime.save_state(_card_state):
		_update_status("던전 런을 저장했습니다.")
	else:
		_update_status("던전 런 저장에 실패했습니다.")
	_refresh_card_ui()


func _on_load_pressed() -> void:
	if not _save_runtime.load_state(_card_state):
		_update_status("불러올 던전 런이 없습니다.")
		return
	_game_started = true
	_selected_hand_index = -1
	_selected_start_cell = _card_state.get_leader_cell()
	if _start_button != null:
		_start_button.disabled = true
		_start_button.text = "게임 시작됨"
	_place_character(_card_state.get_leader_cell())
	_sync_unit_tokens()
	_refresh_revealed_tiles()
	_update_status("저장된 던전 런을 불러왔습니다.")
	_refresh_card_ui()


func _on_tutorial_pressed() -> void:
	_tutorial.toggle_enabled()
	_refresh_card_ui()


func _on_reward_button_pressed(option_index: int) -> void:
	_card_state.choose_reward(option_index)
	_tutorial.advance_on_event("reward_chosen")
	if _card_state.run_complete:
		_tutorial.advance_on_event("run_completed")
	_after_run_action()


func _on_rest_heal_pressed() -> void:
	_card_state.rest_heal_party()
	_after_run_action()


func _on_rest_upgrade_pressed() -> void:
	_card_state.rest_upgrade_first_card()
	_after_run_action()


func _on_rest_remove_pressed() -> void:
	_card_state.rest_remove_first_basic_card()
	_after_run_action()


func _on_shop_buy_pressed() -> void:
	_card_state.shop_buy_card()
	_after_run_action()


func _on_shop_upgrade_pressed() -> void:
	_card_state.shop_upgrade_first_card()
	_after_run_action()


func _on_shop_leave_pressed() -> void:
	_card_state.leave_shop()
	_after_run_action()


func _on_run_complete_pressed() -> void:
	_after_run_action()


func _after_run_action() -> void:
	_selected_hand_index = -1
	_selected_start_cell = _card_state.get_leader_cell()
	_place_character(_card_state.get_leader_cell())
	_sync_unit_tokens()
	_refresh_revealed_tiles()
	_update_status(_card_state.get_summary_text())
	_refresh_card_ui()


func _on_card_button_pressed(hand_index: int) -> void:
	if not _game_started or hand_index < 0 or hand_index >= _card_state.deck.hand.size():
		return

	var card := _card_state.deck.hand[hand_index]
	if String(card.get("target_mode", "")) == DungeonCardDatabase.TARGET_SELF:
		_card_state.use_card(hand_index, _card_state.party_cell)
		_tutorial.advance_on_event("card_played")
		_selected_hand_index = -1
	else:
		_selected_hand_index = hand_index
	_refresh_card_ui()


func _use_selected_card_on_cell(cell: Vector2i) -> void:
	if _selected_hand_index < 0:
		_update_status("먼저 이동 또는 수색 카드를 선택하세요.")
		return
	if cell == INVALID_CELL:
		_update_status("카드 대상이 될 던전 타일을 선택하세요.")
		return

	var did_play := _card_state.use_card(_selected_hand_index, cell)
	if did_play:
		_tutorial.advance_on_event("card_played")
		_selected_hand_index = -1
		_selected_start_cell = _card_state.get_leader_cell()
		_place_character(_card_state.get_leader_cell())
		_sync_unit_tokens()
		_refresh_revealed_tiles()
	_update_status(_card_state.get_summary_text())
	_refresh_card_ui()


func _on_end_turn_pressed() -> void:
	if not _game_started:
		return

	_selected_hand_index = -1
	_card_state.end_turn()
	_tutorial.advance_on_event("turn_ended")
	_place_character(_card_state.get_leader_cell())
	_sync_unit_tokens()
	_update_status(_card_state.get_summary_text())
	_refresh_card_ui()


func _refresh_revealed_tiles() -> void:
	for cell in _card_state.get_revealed_cells():
		_set_tile_focused(cell, cell == _hovered_cell)


func _get_floor_cells_array() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _floor_cells.keys():
		result.append(cell)
	return result


func _sync_unit_tokens() -> void:
	var previous := get_node_or_null(UNIT_ROOT_NAME)
	if previous != null:
		remove_child(previous)
		previous.free()
	if not _game_started:
		return

	var root := Node3D.new()
	root.name = UNIT_ROOT_NAME
	add_child(root)

	var ally_mesh := BoxMesh.new()
	ally_mesh.size = Vector3(0.38, 0.38, 0.38)
	var enemy_mesh := CylinderMesh.new()
	enemy_mesh.top_radius = 0.28
	enemy_mesh.bottom_radius = 0.28
	enemy_mesh.height = 0.55

	for ally in _card_state.party_units:
		if int(ally.get("hp", 0)) <= 0 or String(ally["id"]) == "warrior":
			continue
		_add_unit_token(root, ally_mesh, _get_ally_token_material(), ally["cell"], String(ally["name"]))

	for enemy in _card_state.enemies:
		if int(enemy.get("hp", 0)) <= 0:
			continue
		_add_unit_token(root, enemy_mesh, _get_enemy_token_material(), enemy["cell"], String(enemy["name"]))


func _add_unit_token(root: Node3D, mesh: Mesh, material: Material, cell: Vector2i, token_name: String) -> void:
	var token := MeshInstance3D.new()
	token.name = token_name
	token.mesh = mesh
	token.material_override = material
	token.position = _get_tile_position(cell) + Vector3(0.0, 0.32, 0.0)
	root.add_child(token)


func _get_tile_position(cell: Vector2i) -> Vector3:
	return Vector3(
		(float(cell.x) - _map_center.x) * TILE_STEP,
		0.0,
		(float(cell.y) - _map_center.y) * TILE_STEP
	)


func _add_tile_border(
	root: Node3D,
	cell: Vector2i,
	tile_position: Vector3,
	horizontal_mesh: BoxMesh,
	vertical_mesh: BoxMesh
) -> void:
	var y_position := TILE_BORDER_HEIGHT * 0.5 + 0.006
	_add_border_piece(
		root,
		"Border_N_%02d_%02d" % [cell.x, cell.y],
		horizontal_mesh,
		tile_position + Vector3(0.0, y_position, -TILE_SIZE * 0.5)
	)
	_add_border_piece(
		root,
		"Border_S_%02d_%02d" % [cell.x, cell.y],
		horizontal_mesh,
		tile_position + Vector3(0.0, y_position, TILE_SIZE * 0.5)
	)
	_add_border_piece(
		root,
		"Border_W_%02d_%02d" % [cell.x, cell.y],
		vertical_mesh,
		tile_position + Vector3(-TILE_SIZE * 0.5, y_position, 0.0)
	)
	_add_border_piece(
		root,
		"Border_E_%02d_%02d" % [cell.x, cell.y],
		vertical_mesh,
		tile_position + Vector3(TILE_SIZE * 0.5, y_position, 0.0)
	)


func _add_border_piece(root: Node3D, piece_name: String, mesh: BoxMesh, position: Vector3) -> void:
	var border := MeshInstance3D.new()
	border.name = piece_name
	border.mesh = mesh
	border.material_override = _get_border_material()
	border.position = position
	root.add_child(border)
