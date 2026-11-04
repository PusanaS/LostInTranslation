extends Control
const EngineScript = preload("res://scripts/puzzle_engine.gd")
const Loader = preload("res://scripts/level_loader.gd")
const Board = preload("res://scripts/board_view.gd")
const TranslationBook = preload("res://scripts/translation_book.gd")
const TutorialArt = preload("res://scripts/tutorial_art.gd")
const DialogueView = preload("res://scripts/dialogue_view.gd")
const BGM := {
	"player_room": "res://assets/handmade/audio/bgm/player_room.mp3",
	"main_city": "res://assets/handmade/audio/bgm/main_city.mp3",
	"library": "res://assets/handmade/audio/bgm/library.mp3",
	"graveyard": "res://assets/handmade/audio/bgm/graveyard.mp3",
	"storm_chasing": "res://assets/handmade/audio/bgm/storm_chasing.mp3",
}
const SFX := {
	"cube": "res://assets/handmade/audio/sfx/magic_gun.wav",
	"seal": "res://assets/handmade/audio/sfx/barrier.wav",
	"win": "res://assets/handmade/audio/sfx/ultimate_burst.wav",
}
const BGM_VOLUME_DB := -12.0
const SFX_VOLUME_DB := -6.0
# Dimensional-rift palette shared by the HUD panels.
const ROOM_BG := Color("15112a")
const ROOM_BORDER := Color("4b3a8a")
const PANEL_BG := Color("1b1436f5")
const PANEL_BORDER := Color("b79cff")
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
var dialogue: Control
var after_dialogue := Callable() # what to run when the current story scene ends
var level_select_panel: PanelContainer
var level_select_list: VBoxContainer
var bgm_player: AudioStreamPlayer
var bgm_tween: Tween
var current_bgm := ""
var sfx_players: Dictionary = {}
var sfx_tweens: Dictionary = {}

func _ready() -> void:
	_build_ui()
	resized.connect(_fit_boards)
	_load_library()
	get_window().files_dropped.connect(_files_dropped)
	if not library.is_empty():
		_select_level(0)
		_play_story_before(0)

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

func _build_ui() -> void:
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
	rooms.offset_top = 82; rooms.offset_bottom = -28
	rooms.add_theme_constant_override("separation",10)
	add_child(rooms)
	for _i in range(2):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = ROOM_BG
		panel_style.border_color = ROOM_BORDER
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
	var hud := HBoxContainer.new()
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = 28; hud.offset_right = -28
	hud.offset_top = 22; hud.offset_bottom = 66
	add_child(hud)
	replay_button = button_for("↻  Replay",_reset,hud)
	replay_button.tooltip_text = "Replay level · R"
	pause_button = button_for("Ⅱ  Pause",_toggle_pause,hud)
	pause_button.tooltip_text = "Pause · Esc"
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hud.add_child(spacer)
	var seeds := HBoxContainer.new(); seeds.add_theme_constant_override("separation",7); hud.add_child(seeds)
	seed_icon = TextureRect.new(); seed_icon.texture = art.seed_texture; seed_icon.custom_minimum_size = Vector2(28,28); seed_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; seed_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; seeds.add_child(seed_icon)
	seed_hud = label_for("0",22); seed_hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; seeds.add_child(seed_hud)
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
	_build_level_select()
	_build_loss_popup()
	dialogue = DialogueView.new()
	dialogue.art = art
	dialogue.finished.connect(_on_dialogue_finished)
	dialogue.music_requested.connect(_play_bgm)
	add_child(dialogue)
	bgm_player = AudioStreamPlayer.new()
	bgm_player.volume_db = BGM_VOLUME_DB
	add_child(bgm_player)

func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 14; style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14; style.corner_radius_bottom_right = 14
	style.content_margin_left = 16; style.content_margin_right = 16
	style.content_margin_top = 12; style.content_margin_bottom = 12
	return style

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
	style.bg_color = Color("231a44e8")
	style.border_color = PANEL_BORDER
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
	pause_panel.offset_top = -170; pause_panel.offset_bottom = 170
	pause_panel.visible = false
	pause_panel.add_theme_stylebox_override("panel",_panel_style(PANEL_BG,PANEL_BORDER))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",10)
	pause_panel.add_child(content)
	content.add_child(label_for("PAUSED",24))
	content.add_child(label_for("Settings & level options",14))
	button_for("Resume",_toggle_pause,content)
	button_for("Replay level",func(): _toggle_pause(); _reset(),content)
	if OS.is_debug_build():
		button_for("Level select (debug)",_show_level_select,content)
	button_for("Toggle fullscreen",func():
		get_window().mode = Window.MODE_FULLSCREEN if get_window().mode != Window.MODE_FULLSCREEN else Window.MODE_WINDOWED
	,content)
	button_for("Quit game",func(): get_tree().quit(),content)
	add_child(pause_panel)

## Debug-only jump list: every level in the library plus every story scene.
func _build_level_select() -> void:
	level_select_panel = PanelContainer.new()
	level_select_panel.set_anchors_preset(Control.PRESET_CENTER)
	level_select_panel.offset_left = -300; level_select_panel.offset_right = 300
	level_select_panel.offset_top = -280; level_select_panel.offset_bottom = 280
	level_select_panel.visible = false
	level_select_panel.add_theme_stylebox_override("panel",_panel_style(PANEL_BG,PANEL_BORDER))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",8)
	level_select_panel.add_child(content)
	content.add_child(label_for("LEVEL SELECT · DEBUG",20))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	level_select_list = VBoxContainer.new()
	level_select_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_select_list.add_theme_constant_override("separation",6)
	scroll.add_child(level_select_list)
	button_for("Back · Esc",_hide_level_select,content)
	add_child(level_select_panel)

func _show_level_select() -> void:
	for child in level_select_list.get_children(): child.queue_free()
	level_select_list.add_child(label_for("Levels",14))
	for i in range(library.size()):
		var marker := "▶  " if i == picker.selected else "    "
		button_for("%s%d · %s" % [marker,i+1,library[i].level.name],_jump_to_level.bind(i),level_select_list)
	level_select_list.add_child(label_for("Story scenes",14))
	for scene_id in dialogue.story.get("scenes",{}).keys():
		button_for("    " + str(scene_id),_jump_to_scene.bind(str(scene_id)),level_select_list)
	pause_panel.visible = false
	level_select_panel.visible = true

func _hide_level_select() -> void:
	level_select_panel.visible = false
	pause_panel.visible = is_paused

func _jump_to_level(index: int) -> void:
	level_select_panel.visible = false
	if is_paused: _toggle_pause()
	_select_level(index)

func _jump_to_scene(scene_id: String) -> void:
	level_select_panel.visible = false
	if is_paused: _toggle_pause()
	dialogue.play(scene_id)

func _level_key(index: int) -> String:
	if index < 0 or index >= library.size(): return ""
	return str(library[index].path).get_file().get_basename()

func _play_story_before(index: int) -> void:
	var scene_id: String = dialogue.scene_for("before:" + _level_key(index))
	if not scene_id.is_empty(): dialogue.play(scene_id)

func _on_dialogue_finished() -> void:
	_play_level_music(picker.selected)
	var next := after_dialogue
	after_dialogue = Callable()
	if next.is_valid(): next.call()

func _play_level_music(index: int) -> void:
	# A level keeps the most recent track named at or before it in story/dialogue.json.
	for i in range(mini(index,library.size()-1),-1,-1):
		var key: String = dialogue.music_for_level(_level_key(i))
		if not key.is_empty():
			_play_bgm(key)
			return

func _play_bgm(key: String) -> void:
	if key == current_bgm or not BGM.has(key) or bgm_player == null: return
	current_bgm = key
	var stream: AudioStream = load(BGM[key])
	if stream == null: return
	if "loop" in stream: stream.loop = true
	if bgm_tween != null and bgm_tween.is_valid(): bgm_tween.kill()
	bgm_tween = create_tween()
	if bgm_player.playing: bgm_tween.tween_property(bgm_player,"volume_db",-40.0,0.6)
	bgm_tween.tween_callback(func():
		bgm_player.stream = stream
		bgm_player.volume_db = -40.0
		bgm_player.play()
	)
	bgm_tween.tween_property(bgm_player,"volume_db",BGM_VOLUME_DB,0.8)

## The source SFX are long takes, so each one is faded out after `seconds`.
func _play_sfx(key: String, seconds: float) -> void:
	if not SFX.has(key): return
	if not sfx_players.has(key):
		var player := AudioStreamPlayer.new()
		player.stream = load(SFX[key])
		add_child(player)
		sfx_players[key] = player
	var player: AudioStreamPlayer = sfx_players[key]
	if player.stream == null: return
	if sfx_tweens.has(key) and sfx_tweens[key].is_valid(): sfx_tweens[key].kill()
	player.volume_db = SFX_VOLUME_DB
	player.play()
	var fade := create_tween()
	fade.tween_interval(seconds)
	fade.tween_property(player,"volume_db",-40.0,0.35)
	fade.tween_callback(player.stop)
	sfx_tweens[key] = fade

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
	style.bg_color = Color("1a1230f2")
	style.border_color = Color("8a4a9a")
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
	loss_title = label_for("Swallowed by a crack in time",20)
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
	loss_title.text = "Swallowed by a crack in time" if drowned else "Lost in the void between times"
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

func _handle_plant_blocked(reason: String) -> void:
	if reason.contains("hết hạt"):
		_toast("No cubes left. Press Space on a cube to take it back.")
		return
	if reason.contains("đang đứng") or reason.contains("cùng tọa độ"):
		_toast("You are standing where the cube would appear.")
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
	# A direct jump (debug select, import, tests) abandons any story scene in progress.
	after_dialogue = Callable()
	if dialogue != null: dialogue.stop()
	picker.select(index)
	engine = EngineScript.new(library[index].level)
	_reset()
	_play_level_music(index)

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
	if engine == null or is_transitioning or is_paused or dialogue.is_playing() or engine.won(state) or engine.lost(state): return
	if action == 4:
		var reason: String = engine.plant_reason(state)
		if not reason.is_empty():
			_handle_plant_blocked(reason)
			return
	var next: Dictionary = engine.advance(state,action)
	if next == state:
		if action < 4:
			for board in boards: board.bump()
		return
	if action < 4:
		for i in range(2):
			if next.p[i] == state.p[i]: boards[i].bump()
	if action == 4:
		var p: Array = state.p[0]
		var summoned: bool = next.trees.size() > state.trees.size()
		if summoned and engine.tile(1,p[0],p[1]) == "W": _play_sfx("seal",1.4)
		else: _play_sfx("cube",0.9 if summoned else 0.45)
	history.append(state.duplicate(true))
	state = next
	_render()
	if engine.lost(state): _show_loss_popup()
	elif engine.won(state):
		_play_sfx("win",2.6)
		_begin_book_transition()

func _undo() -> void:
	if is_transitioning or is_paused or dialogue.is_playing() or history.is_empty(): return
	_hide_loss_popup()
	state = history.pop_back()
	_render()

func _next() -> void:
	if not library.is_empty() and not is_transitioning: _select_level((picker.selected+1)%library.size())

func _toggle_pause() -> void:
	if is_transitioning: return
	is_paused = not is_paused
	pause_panel.visible = is_paused
	pause_button.text = "Resume · Esc" if is_paused else "Pause · Esc"

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
		{"title":"Two hands, one sentence","body":"A spell survives only when two times read it together. What is set down in the past is still standing in the present.","illustration":""},
		{"title":"The weight of a cube","body":"A summoned cube may become a wall, a key, or the hand that keeps an old mechanism pressed and awake.","illustration":""},
		{"title":"Stitching the rift","body":"A crack in the present can be sealed by a cube left there in the past. Step lightly: an open crack still takes whoever walks into it.","illustration":""},
		{"title":"Written in Niran","body":"This page was copied by a Niran hand three hundred years ago. It has not been read aloud in Nira since the ships came.","illustration":""},
		{"title":"Those who would forget","body":"An empire that takes a people's books does not need to burn them. It only needs someone at home to agree that they were dangerous.","illustration":""},
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
	var after_scene: String = dialogue.scene_for("after:" + _level_key(picker.selected))
	if not after_scene.is_empty() and dialogue.play(after_scene):
		after_dialogue = _swap_to_next_level
		return
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
	_play_level_music(next_index)
	_set_transition_veil(_book_origin(0),1.65,1.0)
	var incoming := create_tween()
	incoming.tween_method(func(value: float): _set_transition_veil(_book_origin(0),value,1.0),0.0,1.65,0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	incoming.tween_callback(func():
		transition_overlay.visible = false
		is_transitioning = false
		_play_story_before(next_index)
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
	if dialogue.is_playing(): return
	if level_select_panel.visible:
		if event.keycode == KEY_ESCAPE:
			_hide_level_select()
			get_viewport().set_input_as_handled()
		return
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
