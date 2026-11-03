extends Control
const EngineScript = preload("res://scripts/puzzle_engine.gd")
const Loader = preload("res://scripts/level_loader.gd")
const Board = preload("res://scripts/board_view.gd")
const TranslationBook = preload("res://scripts/translation_book.gd")
const TutorialArt = preload("res://scripts/tutorial_art.gd")
const StarField = preload("res://scripts/star_field.gd")
@export var art: Resource
var engine: RefCounted
var state: Dictionary
var history: Array = []
var library: Array = []
var boards: Array = []
var picker: OptionButton
var status: Label
var title_label: Label
var seed_button: Button
var undo_button: Button
var next_button: Button
var replay_button: Button
var pause_button: Button
var seed_hud: Label
var seed_frame: PanelContainer
var seed_flash_tween: Tween
var file_dialog: FileDialog
var toast: PanelContainer
var toast_label: Label
var transition_overlay: ColorRect
var is_transitioning := false
var is_paused := false
var toast_tween: Tween
var pause_panel: PanelContainer
var loss_veil: ColorRect
var loss_panel: PanelContainer
var loss_art: Control
var loss_title: Label
var loss_hint: Label
var translation_panel: Control
var translation_book: Control
var translation_title: Label
var translation_body: Label
var translation_next: Button
var translation_full_text := ""
var is_translating := false
var board_hosts: Array = []
var seed_icon: TextureRect
var fx_layer: Control

func _ready() -> void:
	_build_ui()
	resized.connect(_fit_boards)
	_load_library()
	get_window().files_dropped.connect(_files_dropped)
	if not library.is_empty(): _select_level(0)

func label_for(text: String, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	return label

func button_for(text: String, callback: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _icon_button(icon_text: String, callback: Callable, parent: Node, tip: String) -> Button:
	var button := Button.new()
	button.text = icon_text
	button.custom_minimum_size = Vector2(56, 56)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tip
	button.add_theme_font_size_override("font_size", 28)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("13232cf0")
	style.border_color = Color("3d6578")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 12; style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12; style.corner_radius_bottom_right = 12
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color("1a3542f0")
	hover.border_color = Color("7ec8c4")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _build_ui() -> void:
	# Starfield sits behind boards / HUD.
	var stars := StarField.new()
	add_child(stars)
	move_child(stars, 0)
	# Dev-only controls remain alive for JSON import/tests, but the play HUD stays clean.
	picker = OptionButton.new(); picker.visible = false; picker.item_selected.connect(_select_level); add_child(picker)
	title_label = label_for(""); title_label.visible = false; add_child(title_label)
	status = label_for(""); status.visible = false; add_child(status)
	seed_button = Button.new(); seed_button.visible = false; seed_button.pressed.connect(_act.bind(4)); add_child(seed_button)
	undo_button = Button.new(); undo_button.visible = false; undo_button.pressed.connect(_undo); add_child(undo_button)
	next_button = Button.new(); next_button.visible = false; add_child(next_button)
	var rooms := HBoxContainer.new()
	rooms.set_anchors_preset(Control.PRESET_FULL_RECT)
	rooms.offset_left = 28; rooms.offset_right = -28
	rooms.offset_top = 88; rooms.offset_bottom = -28
	rooms.add_theme_constant_override("separation",10)
	add_child(rooms)
	for _i in range(2):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color("101b25cc")
		panel_style.border_color = Color("29485b")
		panel_style.set_border_width_all(1)
		panel_style.corner_radius_top_left = 12; panel_style.corner_radius_top_right = 12
		panel_style.corner_radius_bottom_left = 12; panel_style.corner_radius_bottom_right = 12
		panel.add_theme_stylebox_override("panel",panel_style)
		rooms.add_child(panel)
		var host := CenterContainer.new()
		host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_child(host)
		var board := Board.new()
		board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(board)
		boards.append(board); board_hosts.append(host)
	fx_layer = Control.new()
	fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	var hud := HBoxContainer.new()
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = 28; hud.offset_right = -28
	hud.offset_top = 16; hud.offset_bottom = 76
	hud.add_theme_constant_override("separation", 12)
	add_child(hud)
	replay_button = _icon_button("↻", _reset, hud, "Replay · R")
	pause_button = _icon_button("⏸", _toggle_pause, hud, "Pause · Esc")
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hud.add_child(spacer)
	seed_frame = PanelContainer.new()
	seed_frame.pivot_offset = Vector2(54, 28)
	var seed_style := StyleBoxFlat.new()
	seed_style.bg_color = Color("152820f2")
	seed_style.border_color = Color("d6b56a")
	seed_style.set_border_width_all(2)
	seed_style.corner_radius_top_left = 14; seed_style.corner_radius_top_right = 14
	seed_style.corner_radius_bottom_left = 14; seed_style.corner_radius_bottom_right = 14
	seed_style.content_margin_left = 14; seed_style.content_margin_right = 16
	seed_style.content_margin_top = 8; seed_style.content_margin_bottom = 8
	seed_frame.add_theme_stylebox_override("panel", seed_style)
	hud.add_child(seed_frame)
	var seeds := HBoxContainer.new(); seeds.add_theme_constant_override("separation",10)
	seed_frame.add_child(seeds)
	seed_icon = TextureRect.new()
	seed_icon.texture = art.seed_texture if art != null else null
	seed_icon.custom_minimum_size = Vector2(40,40)
	seed_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seed_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seeds.add_child(seed_icon)
	seed_hud = label_for("0", 28)
	seed_hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seed_hud.add_theme_color_override("font_color", Color("f3e7c0"))
	seeds.add_child(seed_hud)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.json ; Lost in Translation level"])
	file_dialog.file_selected.connect(_import_file)
	add_child(file_dialog)
	_build_toast()
	_build_transition_overlay()
	_build_translation_screen()
	_build_pause_menu()
	_build_loss_popup()

func _build_toast() -> void:
	toast = PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.offset_left = -220
	toast.offset_right = 220
	toast.offset_top = -72
	toast.offset_bottom = -18
	toast.modulate.a = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color("183735e8")
	style.border_color = Color("9ed6bd")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 18
	style.content_margin_right = 18
	toast.add_theme_stylebox_override("panel",style)
	toast_label = label_for("",15)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_child(toast_label)
	add_child(toast)

func _build_transition_overlay() -> void:
	transition_overlay = ColorRect.new()
	transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/book_transition.gdshader")
	transition_overlay.material = material
	transition_overlay.visible = false
	add_child(transition_overlay)

func _build_translation_screen() -> void:
	translation_panel = Control.new()
	translation_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	translation_panel.visible = false
	translation_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.color = Color("080d16",0.93)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	translation_panel.add_child(veil)
	var heading := label_for("THE TRANSLATION",14)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.set_anchors_preset(Control.PRESET_CENTER_TOP)
	heading.offset_left = -260; heading.offset_right = 260
	heading.offset_top = 24; heading.offset_bottom = 52
	heading.add_theme_color_override("font_color",Color("e6c984"))
	translation_panel.add_child(heading)
	translation_book = TranslationBook.new()
	translation_book.set_anchors_preset(Control.PRESET_CENTER)
	translation_book.offset_left = -510; translation_book.offset_right = 510
	translation_book.offset_top = -270; translation_book.offset_bottom = 250
	translation_panel.add_child(translation_book)
	# Title/body are drawn inside the book (left page). Keep labels only as unused holders.
	translation_title = label_for("",20)
	translation_title.visible = false
	translation_panel.add_child(translation_title)
	translation_body = label_for("",16)
	translation_body.visible = false
	translation_panel.add_child(translation_body)
	translation_next = Button.new()
	translation_next.text = "Space / →  Turn the page"
	translation_next.focus_mode = Control.FOCUS_ALL
	translation_next.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	translation_next.offset_left = -110; translation_next.offset_right = 110
	translation_next.offset_top = -66; translation_next.offset_bottom = -22
	translation_next.visible = false
	translation_next.pressed.connect(_continue_after_translation)
	translation_panel.add_child(translation_next)
	add_child(translation_panel)

func _build_pause_menu() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -180; pause_panel.offset_right = 180
	pause_panel.offset_top = -150; pause_panel.offset_bottom = 150
	pause_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102421f5")
	style.border_color = Color("b4dec4")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 14; style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14; style.corner_radius_bottom_right = 14
	pause_panel.add_theme_stylebox_override("panel",style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",10)
	pause_panel.add_child(content)
	content.add_child(label_for("PAUSED",24))
	content.add_child(label_for("Settings & level options",14))
	button_for("Resume",_toggle_pause,content)
	button_for("Replay level",func(): _toggle_pause(); _reset(),content)
	button_for("Open level editor",func(): get_tree().change_scene_to_file("res://scenes/level_editor.tscn"),content)
	button_for("Toggle fullscreen",func():
		get_window().mode = Window.MODE_FULLSCREEN if get_window().mode != Window.MODE_FULLSCREEN else Window.MODE_WINDOWED
	,content)
	button_for("Quit game",func(): get_tree().quit(),content)
	add_child(pause_panel)

func _build_loss_popup() -> void:
	loss_veil = ColorRect.new()
	loss_veil.color = Color("080d16",0.78)
	loss_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loss_veil.visible = false
	loss_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(loss_veil)
	loss_panel = PanelContainer.new()
	loss_panel.set_anchors_preset(Control.PRESET_CENTER)
	loss_panel.offset_left = -250; loss_panel.offset_right = 250
	loss_panel.offset_top = -210; loss_panel.offset_bottom = 210
	loss_panel.visible = false
	loss_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("121c24f2")
	style.border_color = Color("7a3a3a")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 16; style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16; style.corner_radius_bottom_right = 16
	style.content_margin_left = 24; style.content_margin_right = 24
	style.content_margin_top = 20; style.content_margin_bottom = 20
	loss_panel.add_theme_stylebox_override("panel",style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",14)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	loss_panel.add_child(content)
	loss_art = TutorialArt.new()
	loss_art.custom_minimum_size = Vector2(420, 180)
	content.add_child(loss_art)
	loss_title = label_for("Your witch drowned",20)
	loss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loss_title.add_theme_color_override("font_color",Color("f0c9c9"))
	content.add_child(loss_title)
	loss_hint = label_for("Restart with R",16)
	loss_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loss_hint.add_theme_color_override("font_color",Color("e8d7a4"))
	content.add_child(loss_hint)
	add_child(loss_panel)

func _loss_was_river() -> bool:
	if engine == null or state.is_empty(): return false
	for i in range(2):
		if state.get("dead",[false,false])[i] and engine.tile(i,state.p[i][0],state.p[i][1]) == "W":
			return true
	return false

func _show_loss_popup() -> void:
	var drowned := _loss_was_river()
	loss_title.text = "Your witch drowned" if drowned else "Your witch fell into the void"
	loss_art.setup("drowned" if drowned else "void", art)
	loss_veil.visible = true
	loss_panel.visible = true
	loss_panel.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(loss_panel,"modulate:a",1.0,0.22)

func _hide_loss_popup() -> void:
	if loss_veil != null: loss_veil.visible = false
	if loss_panel != null: loss_panel.visible = false

func _toast(message: String, duration := 2.4) -> void:
	if toast_tween != null and toast_tween.is_valid(): toast_tween.kill()
	toast_label.text = message
	toast.offset_top = -72
	toast.offset_bottom = -18
	toast.modulate.a = 0.0
	toast.show()
	toast_tween = create_tween()
	toast_tween.tween_property(toast,"offset_top",24.0,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	toast_tween.parallel().tween_property(toast,"offset_bottom",78.0,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	toast_tween.parallel().tween_property(toast,"modulate:a",1.0,0.14)
	toast_tween.tween_interval(duration)
	toast_tween.tween_property(toast,"offset_top",-48.0,0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	toast_tween.parallel().tween_property(toast,"offset_bottom",6.0,0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	toast_tween.parallel().tween_property(toast,"modulate:a",0.0,0.18)

func _clamp_to_right_map(x: int, y: int) -> Array:
	var map: Array = engine.level.maps[1]
	var width: int = map[0].length()
	var height: int = map.size()
	return [clampi(x,0,maxi(0,width-1)), clampi(y,0,maxi(0,height-1))]

func _flash_right_tile(x: int, y: int) -> void:
	if boards.size() < 2: return
	boards[1].flash_tile(x, y)

func _flash_seed_hud() -> void:
	if seed_frame == null: return
	if seed_flash_tween != null and seed_flash_tween.is_valid(): seed_flash_tween.kill()
	seed_frame.modulate = Color.WHITE
	seed_hud.modulate = Color.WHITE
	seed_flash_tween = create_tween()
	for _i in range(2):
		seed_flash_tween.tween_property(seed_frame, "modulate", Color(1.0, 0.25, 0.28, 1.0), 0.12)
		seed_flash_tween.parallel().tween_property(seed_hud, "modulate", Color(1.0, 0.35, 0.35, 1.0), 0.12)
		seed_flash_tween.tween_property(seed_frame, "modulate", Color.WHITE, 0.12)
		seed_flash_tween.parallel().tween_property(seed_hud, "modulate", Color.WHITE, 0.12)

func _handle_plant_blocked(reason: String) -> void:
	if reason.contains("hết hạt"):
		_flash_seed_hud()
		return
	if reason.contains("đang đứng") or reason.contains("cùng tọa độ"):
		_toast("Cannot plant while both witches share the same tile.")
		return
	var p: Array = state.p[0]
	var x := int(p[0])
	var y := int(p[1])
	if reason.contains("đích"):
		var goal: Array = engine.level.goal[1]
		x = int(goal[0]); y = int(goal[1])
	elif reason.contains("tường") or reason.contains("ngoài"):
		var clamped := _clamp_to_right_map(x, y)
		x = int(clamped[0]); y = int(clamped[1])
	_flash_right_tile(x, y)

func _load_library() -> void:
	DirAccess.make_dir_recursive_absolute("user://levels")
	for directory in ["res://levels","user://levels"]:
		var files := DirAccess.get_files_at(directory)
		files.sort()
		for filename in files:
			if not filename.ends_with(".json"): continue
			var path: String = directory.path_join(filename)
			var parsed := Loader.read(path)
			if parsed.has("error"):
				push_warning(path+": "+parsed.error)
				continue
			library.append({"level":parsed.level,"path":path})
			picker.add_item(parsed.level.name)

func _select_level(index: int) -> void:
	if index < 0 or index >= library.size(): return
	picker.select(index)
	engine = EngineScript.new(library[index].level)
	_reset()

func _import_file(path: String) -> void:
	var parsed := Loader.read(path)
	if parsed.has("error"):
		_toast("Could not open this level file. Check that it is a valid Lost in Translation JSON level.")
		return
	var destination := "user://levels/import-%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(destination,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(parsed.level,"\t"))
		file.close()
	library.append({"level":parsed.level,"path":destination})
	picker.add_item(parsed.level.name)
	_select_level(library.size()-1)
	_toast("Level imported and saved to this device." if file != null else "Level opened, but could not be saved to this device.")

func _files_dropped(paths: PackedStringArray) -> void:
	for path in paths:
		if path.get_extension().to_lower() == "json": _import_file(path)

func _reset() -> void:
	if engine == null or is_transitioning: return
	_hide_loss_popup()
	state = engine.initial()
	history.clear()
	_render()

func _act(action: int) -> void:
	if engine == null or is_transitioning or is_paused or engine.won(state) or engine.lost(state): return
	var recalling := false
	var recall_cell: Array = []
	if action == 4:
		var reason: String = engine.plant_reason(state)
		if not reason.is_empty():
			_handle_plant_blocked(reason)
			return
		recall_cell = state.p[0].duplicate()
		recalling = engine.coord(recall_cell) in state.trees
	var next: Dictionary = engine.advance(state,action)
	if next == state:
		if action < 4:
			for board in boards: board.bump()
		return
	if action < 4:
		for i in range(2):
			if next.p[i] == state.p[i]: boards[i].bump()
	history.append(state.duplicate(true))
	state = next
	_render()
	if recalling:
		_play_seed_recall(recall_cell)
	if engine.lost(state): _show_loss_popup()
	elif engine.won(state): _begin_book_transition()

func _seed_hud_center() -> Vector2:
	if seed_frame == null: return get_viewport_rect().size * Vector2(0.9, 0.08)
	return seed_frame.get_global_rect().get_center()

func _play_seed_recall(cell: Array) -> void:
	if art == null or fx_layer == null or boards.is_empty(): return
	var start: Vector2 = boards[0].seed_screen_center(cell)
	var target := _seed_hud_center()
	var flyer := TextureRect.new()
	flyer.texture = art.seed_texture
	flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flyer.custom_minimum_size = Vector2(36, 36)
	flyer.size = Vector2(36, 36)
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.global_position = start - flyer.size * 0.5
	fx_layer.add_child(flyer)
	var flight := create_tween()
	flight.tween_property(flyer, "global_position", target - flyer.size * 0.5, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	flight.parallel().tween_property(flyer, "scale", Vector2(0.65, 0.65), 0.42)
	flight.tween_callback(func():
		flyer.queue_free()
		_burst_seed_hud()
	)

func _burst_seed_hud() -> void:
	if seed_frame == null: return
	seed_frame.scale = Vector2(1.12, 1.12)
	var pop := create_tween()
	pop.tween_property(seed_frame, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var center := _seed_hud_center()
	for i in range(10):
		var spark := ColorRect.new()
		spark.color = Color("e6c984", 0.95)
		spark.size = Vector2(4, 4)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.global_position = center
		fx_layer.add_child(spark)
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / 10.0) * randf_range(28.0, 54.0)
		var tw := create_tween()
		tw.tween_property(spark, "global_position", center + dir, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(spark, "modulate:a", 0.0, 0.35)
		tw.tween_callback(spark.queue_free)

func _undo() -> void:
	if is_transitioning or is_paused or history.is_empty(): return
	_hide_loss_popup()
	state = history.pop_back()
	_render()

func _next() -> void:
	if not library.is_empty() and not is_transitioning: _select_level((picker.selected+1)%library.size())

func _toggle_pause() -> void:
	if is_transitioning: return
	is_paused = not is_paused
	pause_panel.visible = is_paused
	pause_button.text = "▶" if is_paused else "⏸"

func _book_origin(room: int) -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or room < 0 or room >= boards.size(): return Vector2(0.5,0.5)
	return boards[room].book_screen_center() / viewport_size

func _set_transition_veil(origin: Vector2, radius: float, mode: float) -> void:
	var material := transition_overlay.material as ShaderMaterial
	material.set_shader_parameter("origin",origin)
	material.set_shader_parameter("radius",radius)
	material.set_shader_parameter("mode",mode)

func _begin_book_transition() -> void:
	if is_transitioning: return
	is_transitioning = true
	transition_overlay.visible = true
	_set_transition_veil(_book_origin(0),0.0,0.0)
	var out := create_tween()
	out.tween_method(func(value: float): _set_transition_veil(_book_origin(0),value,0.0),0.0,1.65,0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	out.tween_callback(_show_translation)

func _translation_copy() -> Dictionary:
	var fallback := [
		{"title":"Two hands, one sentence","body":"A spell survives only when two worlds read it together. Seeds placed in the past reshape the future.","illustration":""},
		{"title":"The future can be held","body":"A living tree may become a boundary, a bridge, or the hand that keeps an old mechanism awake.","illustration":""},
		{"title":"Water remembers","body":"A seed cast into a future river becomes a lily. Step lightly: unmarked water still takes a witch beneath it.","illustration":""},
		{"title":"The archive opens","body":"Every translated page returns one lost fragment of magic to the people who first wrote it.","illustration":""}
	]
	var custom: Variant = engine.level.get("translation",{})
	if custom is Dictionary and not str(custom.get("body","")).is_empty(): return custom
	return fallback[picker.selected % fallback.size()]

func _show_translation() -> void:
	transition_overlay.visible = false
	is_translating = true
	translation_panel.visible = true
	translation_panel.modulate.a = 0.0
	translation_next.visible = false
	var copy := _translation_copy()
	var title := str(copy.get("title","A page translated"))
	translation_full_text = str(copy.get("body","The book keeps its next secret for you."))
	translation_title.text = title
	translation_body.text = translation_full_text
	translation_book.prepare(title, translation_full_text, str(copy.get("illustration","")), art)
	translation_book.open_amount = 0.0
	translation_book.translate_progress = 0.0
	translation_book.image_reveal = 0.0
	call_deferred("_play_translation_reveal", str(copy.get("illustration","")))

func _play_translation_reveal(illustration_kind: String) -> void:
	if not is_translating or translation_book == null: return
	var char_count: int = maxi(translation_book.readable_count(), 1)
	var translate_seconds := clampf(float(char_count) * 0.0385, 2.2, 8.5) # ~10% slower pacing
	var reveal := create_tween()
	reveal.tween_property(translation_panel,"modulate:a",1.0,0.242)
	reveal.parallel().tween_property(translation_book,"open_amount",1.0,0.792).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Left page: glyphs morph into English in reading order with sparkles.
	reveal.tween_property(translation_book,"translate_progress",1.0,translate_seconds).set_trans(Tween.TRANS_LINEAR)
	# Right page image only after the English page is complete.
	if not illustration_kind.is_empty():
		reveal.tween_property(translation_book,"image_reveal",1.0,0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal.tween_callback(func():
		if is_translating:
			translation_next.visible = true
			translation_next.grab_focus()
	)

func _continue_after_translation() -> void:
	if not is_translating: return
	is_translating = false
	translation_panel.visible = false
	transition_overlay.visible = true
	_swap_to_next_level()

func _swap_to_next_level() -> void:
	if library.is_empty():
		is_transitioning = false
		transition_overlay.visible = false
		return
	var next_index := (picker.selected+1) % library.size()
	picker.select(next_index)
	engine = EngineScript.new(library[next_index].level)
	state = engine.initial()
	history.clear()
	_render()
	_set_transition_veil(_book_origin(0),1.65,1.0)
	var incoming := create_tween()
	incoming.tween_method(func(value: float): _set_transition_veil(_book_origin(0),value,1.0),0.0,1.65,0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	incoming.tween_callback(func():
		transition_overlay.visible = false
		is_transitioning = false
	)

func _render() -> void:
	title_label.text = engine.level.name
	for i in range(2): boards[i].update_board(engine,state,i,art)
	var remaining: int = engine.remaining(state)
	status.text = ""
	seed_button.disabled = engine.won(state) or engine.lost(state) or not engine.plant_reason(state).is_empty()
	seed_button.tooltip_text = ""
	undo_button.disabled = history.is_empty()
	replay_button.disabled = is_transitioning
	seed_hud.text = "∞" if remaining < 0 else str(remaining)
	next_button.visible = false
	if not engine.lost(state): _hide_loss_popup()
	call_deferred("_fit_boards")

func _fit_boards() -> void:
	for i in range(mini(boards.size(),board_hosts.size())):
		var host: Control = board_hosts[i]
		if host.size.x > 0.0 and host.size.y > 0.0:
			boards[i].fit_to_space(host.size - Vector2(34,34))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or file_dialog.visible: return
	if is_translating:
		if translation_next.visible and event.keycode in [KEY_SPACE, KEY_RIGHT]:
			_continue_after_translation()
			get_viewport().set_input_as_handled()
		return
	if is_transitioning: return
	match event.keycode:
		KEY_ESCAPE: _toggle_pause()
		KEY_UP: _act(0)
		KEY_RIGHT: _act(1)
		KEY_DOWN: _act(2)
		KEY_LEFT: _act(3)
		KEY_SPACE: _act(4)
		KEY_Z: _undo()
		KEY_R: _reset()
		_: return
	get_viewport().set_input_as_handled()
