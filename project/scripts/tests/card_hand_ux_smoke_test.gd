extends SceneTree

const DUNGEON_SCENE := "res://scenes/dungeon_grid_view.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_card_layer_assets()
	await _test_dungeon_hand_uses_fanned_card_scene()
	await _test_hand_card_drag_signals()
	await _test_drag_keeps_clicked_point_under_cursor()

	if _failures.is_empty():
		print("Card hand UX smoke test passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_card_layer_assets() -> void:
	for job in ["warrior", "mage", "rogue", "cleric"]:
		var border_path := "res://assets/art/ui/cards/imagegen_%s_card_border_only.png" % job
		var title_path := "res://assets/art/ui/cards/imagegen_%s_card_title_area.png" % job
		var text_path := "res://assets/art/ui/cards/imagegen_%s_card_text_area.png" % job
		_expect(FileAccess.file_exists(border_path), "%s card border asset should exist." % job)
		_expect(FileAccess.file_exists(title_path), "%s card title-area asset should exist." % job)
		_expect(FileAccess.file_exists(text_path), "%s card text-area asset should exist." % job)
		_expect(not FileAccess.file_exists("res://assets/art/ui/cards/%s_card_design.png" % job), "%s simple card design should be removed." % job)
		_expect(_image_matches_size(border_path, Vector2i(1024, 1536)), "%s card border should use the full card canvas." % job)
		_expect(_image_matches_size(title_path, Vector2i(720, 100)), "%s card title area should use the title panel canvas." % job)
		_expect(_image_matches_size(text_path, Vector2i(720, 400)), "%s card text area should use the text panel canvas." % job)

	var unique_art_paths := {}
	for card in DungeonCardDatabase.build_all_card_specs():
		var card_id := String(card.get("id", ""))
		var art_path := String(card.get("art_path", ""))
		_expect(not art_path.is_empty(), "%s should have a generated content background art path." % card_id)
		_expect(FileAccess.file_exists(art_path), "%s generated content background should exist: %s" % [card_id, art_path])
		_expect(_image_matches_size(art_path, Vector2i(720, 400)), "%s generated content background should be 720x400." % card_id)
		unique_art_paths[art_path] = true
	_expect(unique_art_paths.size() == 32, "Generated content backgrounds should cover 32 unique card ids.")

	var hand_card_scene := load("res://scenes/ui/dungeon_hand_card.tscn") as PackedScene
	_expect(hand_card_scene != null, "Hand card scene should load.")
	if hand_card_scene == null:
		return
	var hand_card := hand_card_scene.instantiate()
	root.add_child(hand_card)
	await process_frame
	var title_label := hand_card.get_node("%TitleLabel") as Label
	var type_label := hand_card.get_node("%TypeLabel") as Label
	var description_label := hand_card.get_node("%DescriptionLabel") as Label
	var background := hand_card.get_node("%CardBackground") as TextureRect
	var illustration := hand_card.get_node("%CardIllustration") as TextureRect
	var border := hand_card.get_node("%CardBorder") as TextureRect
	var title_area := hand_card.get_node("%CardTitleArea") as TextureRect
	var text_area := hand_card.get_node("%CardTextArea") as TextureRect
	_expect(background != null, "Hand card scene should expose a card background layer for optional art.")
	_expect(border != null, "Hand card scene should expose a card border layer.")
	_expect(title_area != null, "Hand card scene should expose a title-area layer.")
	_expect(text_area != null, "Hand card scene should expose a text-area layer.")
	_expect(border != null and border.texture != null, "Hand card scene should preload a visible default card border texture.")
	_expect(title_area != null and title_area.texture != null, "Hand card scene should preload a visible default title-area texture.")
	_expect(text_area != null and text_area.texture != null, "Hand card scene should preload a visible default text-area texture.")
	_expect(illustration != null, "Hand card scene should expose a card illustration slot.")
	_expect(background != null and background.position == illustration.position and background.size == illustration.size, "Card background should occupy the image slot.")
	_expect(background != null and background.modulate.a > 0.0 and background.modulate.a < 1.0, "Card background should render with alpha.")
	_expect(title_label != null and title_area != null and title_label.get_parent() == title_area, "Title label should be a child of the title-area layer.")
	_expect(type_label != null and type_label.get_parent() != null and type_label.get_parent().name == "CardTypeArea", "Type label should be a child of the type-area layer.")
	_expect(description_label != null and text_area != null and description_label.get_parent() == text_area, "Description label should be a child of the text-area layer.")
	_expect(_label_is_centered(title_label), "Title label text should be centered.")
	_expect(_label_is_centered(type_label), "Type label text should be centered.")
	_expect(_label_is_centered(description_label), "Description label text should be centered.")
	_expect(title_label != null and title_area != null and title_label.position.y >= 0.0 and title_label.position.y < title_area.size.y, "Title label should stay inside the title-area layer.")
	_expect(illustration != null and illustration.position.y >= 26.0 and illustration.size.y >= 44.0, "Illustration slot should stay between the title and text areas.")
	_expect(type_label != null and type_label.position.y >= 0.0, "Type label should stay inside the type-area layer.")
	_expect(description_label != null and text_area != null and description_label.position.y >= 0.0 and description_label.position.y < text_area.size.y, "Description label should stay inside the text-area layer.")
	_expect(_hand_card_applies_job_skins(hand_card, border, title_area, text_area), "Hand card should apply every job skin through scene-editable texture properties.")
	var sample_card := DungeonCardDatabase.build_all_card_specs()[0]
	hand_card.call("setup", sample_card, 0, false, false)
	_expect(background != null and _texture_ends_with(background.texture, "warrior_move_bg.png"), "Hand card should apply generated card art to the background layer.")
	_expect(illustration != null and illustration.texture == null, "Generated card art should not be duplicated in the foreground illustration slot.")
	root.remove_child(hand_card)
	hand_card.queue_free()


func _test_dungeon_hand_uses_fanned_card_scene() -> void:
	var scene := load(DUNGEON_SCENE) as PackedScene
	_expect(scene != null, "Dungeon scene should load for card hand UX test.")
	if scene == null:
		return

	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame

	var cells: Array = instance.call("_get_floor_cells_array")
	_expect(not cells.is_empty(), "Dungeon should generate floor cells before starting the run.")
	if cells.is_empty():
		root.remove_child(instance)
		instance.queue_free()
		return

	instance.call("_select_start_cell", cells[0])
	instance.call("_start_game")
	await create_timer(0.18).timeout

	var hand_container := instance.get_node("CanvasLayer/DungeonHandLayer") as Control
	_expect(hand_container != null, "Dungeon scene should expose an independent hand layer.")
	if hand_container == null:
		root.remove_child(instance)
		instance.queue_free()
		return
	_expect(hand_container.get_parent() == instance.get_node("CanvasLayer"), "Hand layer should be a CanvasLayer child, not a DungeonCardHud child.")
	_expect(is_equal_approx(hand_container.anchor_left, 0.0) and is_equal_approx(hand_container.anchor_right, 1.0), "Hand layer should span the viewport for exact bottom-center layout.")

	var card_layer := hand_container.get_node("%CardLayer") as Control
	_expect(card_layer != null, "Dungeon HUD should expose a scene-editable card layer.")
	if card_layer == null:
		root.remove_child(instance)
		instance.queue_free()
		return

	var cards := card_layer.get_children()
	_expect(cards.size() == 5, "Starting turn should render 5 card scene instances in hand.")
	if cards.size() >= 2:
		_expect(cards[0].rotation != cards[cards.size() - 1].rotation, "Hand cards should be fanned with different rotations.")
		_expect(cards[0].position.x < cards[cards.size() - 1].position.x, "Hand cards should be laid out horizontally.")

	var first_card := cards[0]
	var resting_scale: float = first_card.scale.x
	first_card.emit_signal("card_hovered", 0)
	await create_timer(0.18).timeout
	_expect(first_card.scale.x > resting_scale, "Hovered cards should enlarge.")

	first_card.emit_signal("card_unhovered", 0)
	await process_frame

	root.remove_child(instance)
	instance.queue_free()
	await process_frame


func _test_hand_card_drag_signals() -> void:
	var hand_card_scene := load("res://scenes/ui/dungeon_hand_card.tscn") as PackedScene
	_expect(hand_card_scene != null, "Hand card scene should load for drag input.")
	if hand_card_scene == null:
		return

	var hand_card := hand_card_scene.instantiate()
	root.add_child(hand_card)
	await process_frame

	var drag_flags := {"started": false, "moved": false, "released": false}
	hand_card.connect("card_drag_started", func(_hand_index: int) -> void: drag_flags["started"] = true)
	hand_card.connect("card_drag_moved", func(_hand_index: int) -> void: drag_flags["moved"] = true)
	hand_card.connect("card_drag_released", func(_hand_index: int) -> void: drag_flags["released"] = true)
	hand_card.call("setup", DungeonCardDatabase.build_all_card_specs()[0], 0, false, false)

	var press_area := hand_card.get_node("%PressArea") as Button
	_expect(press_area != null, "Hand card should expose a press area for drag input.")
	if press_area != null:
		hand_card.call("_begin_drag")
		await process_frame

		await process_frame

		hand_card.call("_finish_drag", true)
		await process_frame

	_expect(bool(drag_flags["started"]), "Pressing a hand card should start drag targeting.")
	_expect(bool(drag_flags["moved"]), "Dragging a hand card should emit target preview updates.")
	_expect(bool(drag_flags["released"]), "Releasing a hand card should emit use/cancel resolution.")

	root.remove_child(hand_card)
	hand_card.queue_free()
	await process_frame


func _test_drag_keeps_clicked_point_under_cursor() -> void:
	var hand_card_scene := load("res://scenes/ui/dungeon_hand_card.tscn") as PackedScene
	_expect(hand_card_scene != null, "Hand card scene should load for drag anchor test.")
	if hand_card_scene == null:
		return

	var hand_card := hand_card_scene.instantiate()
	root.add_child(hand_card)
	await process_frame

	var grab_local := Vector2(248.0, 392.0)
	var parent_mouse := Vector2(720.0, 360.0)
	hand_card.scale = Vector2(0.22, 0.22)
	hand_card.call("_begin_drag", grab_local)
	var drag_position := hand_card.call("_get_drag_position_for_mouse", parent_mouse) as Vector2
	var pivot: Vector2 = hand_card.pivot_offset
	var visual_grab_position: Vector2 = drag_position + pivot + (grab_local - pivot) * hand_card.scale
	_expect(visual_grab_position.distance_to(parent_mouse) <= 0.01, "Dragged card should keep the exact clicked point under the cursor.")

	hand_card.call("_finish_drag", false)
	root.remove_child(hand_card)
	hand_card.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _image_matches_size(texture_path: String, expected_size: Vector2i) -> bool:
	var image := Image.new()
	var file_path := ProjectSettings.globalize_path(texture_path)
	if image.load(file_path) != OK:
		return false
	return image.get_size() == expected_size


func _hand_card_applies_job_skins(hand_card: Node, border: TextureRect, title_area: TextureRect, text_area: TextureRect) -> bool:
	for job in ["warrior", "mage", "rogue", "cleric"]:
		hand_card.call("setup", {"job": job, "name": "Preview", "type": "Type", "description": "Text"}, 0, false, false)
		if not _texture_ends_with(border.texture, "imagegen_%s_card_border_only.png" % job):
			return false
		if not _texture_ends_with(title_area.texture, "imagegen_%s_card_title_area.png" % job):
			return false
		if not _texture_ends_with(text_area.texture, "imagegen_%s_card_text_area.png" % job):
			return false
	return true


func _texture_ends_with(texture: Texture2D, file_name: String) -> bool:
	return texture != null and String(texture.resource_path).ends_with(file_name)


func _label_is_centered(label: Label) -> bool:
	return label != null and label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER
