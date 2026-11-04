extends Control
## Visual-novel style story overlay. Portraits and the textbox are full-screen
## 1920×1080 layers (character already placed on its side), so they are drawn
## "cover"-fitted to the window and the text is laid into the textbox region.
signal finished
signal music_requested(key: String)

const STORY_PATH := "res://story/dialogue.json"
const DESIGN_SIZE := Vector2(1920, 1080)
## Textbox paper area inside textbox.png, in design pixels.
const TEXT_REGION := Rect2(430, 820, 1120, 190)
const CHARS_PER_SECOND := 48.0
const BACKGROUNDS := {
	"bedroom": "res://assets/handmade/backgrounds/bedroom.png",
}

var art: Resource
var story: Dictionary = {}
var lines: Array = []
var line_index := 0
var visible_chars := 0.0
var background := ""
var active_speaker := ""
var side_speaker: Dictionary = {} # "left"/"right" -> speaker id currently standing there
var flipped: Array = [] # speakers mirrored onto the other side for this scene
var _textures: Dictionary = {}
var _time := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)
	var text := FileAccess.get_file_as_string(STORY_PATH)
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if parsed is Dictionary: story = parsed
	else: push_warning("Story file missing or invalid: " + STORY_PATH)

func is_playing() -> bool:
	return visible

func scene_for(trigger: String) -> String:
	return str(story.get("triggers",{}).get(trigger,""))

func music_for_level(level_key: String) -> String:
	return str(story.get("level_music",{}).get(level_key,""))

func play(scene_id: String) -> bool:
	var scene: Variant = story.get("scenes",{}).get(scene_id)
	if not scene is Dictionary or scene.get("lines",[]).is_empty(): return false
	lines = scene.lines
	line_index = 0
	background = str(scene.get("background","rift"))
	side_speaker.clear()
	flipped = scene.get("flip",[])
	if scene.has("bgm"): music_requested.emit(str(scene.bgm))
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self,"modulate:a",1.0,0.3)
	set_process(true)
	_enter_line()
	return true

func stop() -> void:
	if not visible: return
	visible = false
	set_process(false)
	finished.emit()

func advance() -> void:
	if not visible: return
	var full := str(lines[line_index].get("text","")).length()
	if visible_chars < full:
		visible_chars = full
		queue_redraw()
		return
	line_index += 1
	if line_index >= lines.size():
		stop()
		return
	_enter_line()

func _enter_line() -> void:
	var line: Dictionary = lines[line_index]
	visible_chars = 0.0
	if line.has("background"):
		background = str(line.background)
		side_speaker.clear()
	if line.has("bgm"): music_requested.emit(str(line.bgm))
	active_speaker = str(line.get("speaker","narrator"))
	if _portrait(active_speaker) != null:
		side_speaker[_side(active_speaker)] = active_speaker
	queue_redraw()

## Portrait art is painted on one side of the canvas; "flip" mirrors it to the other.
func _painted_side(speaker: String) -> String:
	return str(story.get("speakers",{}).get(speaker,{}).get("side","left"))

func _side(speaker: String) -> String:
	var side := _painted_side(speaker)
	if speaker in flipped: side = "right" if side == "left" else "left"
	return side

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_RIGHT, KEY_Z: advance()
		KEY_ESCAPE: stop() # skip the whole scene
		_: return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_time += delta
	if line_index < lines.size():
		visible_chars = minf(visible_chars + delta * CHARS_PER_SECOND, float(str(lines[line_index].get("text","")).length()))
	queue_redraw()

func _texture(path: String) -> Texture2D:
	if path.is_empty(): return null
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]

func _portrait(speaker: String) -> Texture2D:
	return _texture(str(story.get("speakers",{}).get(speaker,{}).get("portrait","")))

## Maps the 1920×1080 design canvas onto the window, cropping the overflow ("cover").
func _design_transform() -> Transform2D:
	var scale := maxf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var offset := (size - DESIGN_SIZE * scale) * 0.5
	return Transform2D(0.0, Vector2(scale, scale), 0.0, offset)

func _draw() -> void:
	if not visible: return
	_draw_background()
	var xf := _design_transform()
	var mirror := Transform2D(0.0, Vector2(-1, 1), 0.0, Vector2(DESIGN_SIZE.x, 0))
	for side in side_speaker:
		var speaker: String = side_speaker[side]
		var tint := Color.WHITE if speaker == active_speaker else Color(0.45, 0.42, 0.55, 1.0)
		draw_set_transform_matrix(xf * mirror if speaker in flipped else xf)
		draw_texture_rect(_portrait(speaker), Rect2(Vector2.ZERO, DESIGN_SIZE), false, tint)
	draw_set_transform_matrix(xf)
	var box: Texture2D = art.get("textbox_texture") if art != null else null
	if box != null: draw_texture_rect(box, Rect2(Vector2.ZERO, DESIGN_SIZE), false)
	else: draw_rect(TEXT_REGION.grow(30), Color("d3cbbf"), true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_text(xf)

func _draw_background() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if BACKGROUNDS.has(background):
		var tex := _texture(BACKGROUNDS[background])
		if tex != null:
			var tex_size := tex.get_size()
			var scale := maxf(size.x / tex_size.x, size.y / tex_size.y)
			var drawn := tex_size * scale
			draw_texture_rect(tex, Rect2((size - drawn) * 0.5, drawn), false)
			draw_rect(rect, Color(0.05, 0.03, 0.10, 0.25), true)
			return
	_draw_rift_backdrop(rect)
	if background == "rift_guards" and art != null and art.get("soldier_texture") != null:
		# Niran guards standing behind the Commander, between the two portraits.
		var guard: Texture2D = art.soldier_texture
		var h := size.y * 0.42
		for i in range(3):
			var x := size.x * (0.40 + i * 0.09)
			var r := Rect2(Vector2(x, size.y * 0.30 + (i % 2) * 14.0), Vector2(h, h))
			draw_texture_rect(guard, r, false, Color(0.62, 0.58, 0.72, 0.95))

func _draw_rift_backdrop(rect: Rect2) -> void:
	draw_rect(rect, Color("120c24"), true)
	for i in range(14):
		var t := float(i) / 13.0
		draw_rect(Rect2(0, rect.size.y * t, rect.size.x, rect.size.y / 13.0 + 1.0), Color(0.18 + 0.12 * t, 0.07, 0.30 + 0.10 * t, 0.35), true)
	# A slow-breathing crack across the sky.
	var pts := PackedVector2Array()
	for i in range(13):
		var x := rect.size.x * (0.05 + 0.075 * i)
		var y := rect.size.y * (0.22 + 0.05 * sin(i * 1.7)) + (16.0 if i % 2 == 0 else -14.0)
		pts.append(Vector2(x, y))
	var glow := 0.55 + 0.25 * sin(_time * 1.6)
	draw_polyline(pts, Color(0.62, 0.35, 1.0, 0.25 * glow), 22.0, true)
	draw_polyline(pts, Color(0.78, 0.55, 1.0, 0.65 * glow), 6.0, true)
	draw_polyline(pts, Color(0.95, 0.88, 1.0, 0.9), 1.6, true)
	for i in range(40):
		var p := Vector2(fmod(i * 197.0 + _time * 9.0 * (1 + i % 3), rect.size.x), fmod(i * 113.0, rect.size.y))
		draw_circle(p, 1.0 + (i % 3) * 0.6, Color(0.85, 0.75, 1.0, 0.25 + 0.2 * sin(_time * 2.0 + i)))

func _draw_text(xf: Transform2D) -> void:
	if line_index >= lines.size(): return
	var line: Dictionary = lines[line_index]
	var region := Rect2(xf * TEXT_REGION.position, TEXT_REGION.size * xf.get_scale())
	var font := ThemeDB.fallback_font
	var name := str(story.get("speakers",{}).get(active_speaker,{}).get("name",""))
	var font_size := int(clampf(region.size.y * 0.15, 14.0, 26.0))
	var y := region.position.y + font_size
	if not name.is_empty():
		draw_string(font, Vector2(region.position.x, y), name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size + 2, Color("5b2f8f"))
		y += font_size * 1.55
	var text := str(line.get("text","")).left(int(visible_chars))
	var ink := Color("3c2f2a") if not name.is_empty() else Color("4a3d5c")
	draw_multiline_string(font, Vector2(region.position.x, y), text, HORIZONTAL_ALIGNMENT_LEFT, region.size.x, font_size, -1, ink)
	if visible_chars >= str(line.get("text","")).length():
		var bob := sin(_time * 5.0) * 3.0
		var tip := Vector2(region.end.x - 6, region.end.y + bob)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-14, -12), tip + Vector2(14, -12)]), Color("5b2f8f"))
	draw_string(font, Vector2(16, size.y - 14), "Space / click: next   ·   Esc: skip scene", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.55))
