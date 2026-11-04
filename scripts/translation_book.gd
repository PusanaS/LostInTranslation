extends Control

# Code-drawn parchment book. Left page: glyphs morph into English in reading order
# with sparkle particles. Right page: tutorial illustration after translation finishes.
const GLYPH_SHEET: Texture2D = preload("res://assets/glyphs/hieroglyph_ref.png")
const GLYPH_COLS := 8
const GLYPH_ROWS := 5
var open_amount: float = 0.0:
	set(value):
		open_amount = clampf(value, 0.0, 1.0)
		queue_redraw()

## 0 = all glyphs, 1 = fully English. Drives in-place glyph→letter morph.
var translate_progress: float = 0.0:
	set(value):
		var previous := translate_progress
		translate_progress = clampf(value, 0.0, 1.0)
		_emit_translation_particles(previous)
		queue_redraw()

## Right-page illustration fade (start only after translate_progress == 1).
var image_reveal: float = 0.0:
	set(value):
		image_reveal = clampf(value, 0.0, 1.0)
		queue_redraw()

var page_title := ""
var page_body := ""
var illustration := ""
var art: Resource

var _slots: Array = [] # {ch, glyph_pos, latin_pos, title, size, cell}
var _layout_size := Vector2.ZERO
var _particles: Array = [] # {pos:Vector2, vel:Vector2, age:float, life:float, hue:float}
var _last_done := -1
## Sandstone background removed; only carved ink remains for parchment composite.
var _glyph_cutout: Texture2D
var _book_font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(900, 520)
	_prepare_glyph_cutout()
	_book_font = _make_book_font()
	set_process(true)
	queue_redraw()

func _make_book_font() -> Font:
	# Soft literary serif for the translated English page.
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman", "Cambria", "serif"])
	sf.font_italic = true
	return sf

func _font() -> Font:
	return _book_font if _book_font != null else ThemeDB.fallback_font

func _prepare_glyph_cutout() -> void:
	if GLYPH_SHEET == null: return
	var src: Image = GLYPH_SHEET.get_image()
	if src == null: return
	src = src.duplicate()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	for y in range(src.get_height()):
		for x in range(src.get_width()):
			var c := src.get_pixel(x, y)
			# Stone fill is bright tan; carved grooves are darker brown.
			var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			if lum >= 0.62:
				src.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				# Keep carving as warm ink with alpha from darkness.
				var ink_a := clampf((0.62 - lum) / 0.42, 0.0, 1.0)
				ink_a = pow(ink_a, 0.75)
				src.set_pixel(x, y, Color(0.30, 0.18, 0.10, ink_a))
	_glyph_cutout = ImageTexture.create_from_image(src)

func prepare(title: String, body: String, kind: String = "", textures: Resource = null) -> void:
	page_title = title
	page_body = body
	illustration = kind
	art = textures
	translate_progress = 0.0
	image_reveal = 0.0
	_slots.clear()
	_layout_size = Vector2.ZERO
	_particles.clear()
	_last_done = -1
	queue_redraw()

func readable_count() -> int:
	_ensure_layout()
	return _slots.size()

func _process(delta: float) -> void:
	if _particles.is_empty(): return
	var alive: Array = []
	for p in _particles:
		p.age += delta
		p.pos += p.vel * delta
		p.vel *= 0.94
		if p.age < p.life:
			alive.append(p)
	_particles = alive
	queue_redraw()

func _ensure_layout() -> void:
	var area := get_rect().size
	if area.x <= 0.0 or area.y <= 0.0: return
	if not _slots.is_empty() and _layout_size == area: return
	_layout_size = area
	_slots.clear()
	# Layout against the fully-open page so glyph positions stay stable while the book opens.
	var metrics := _page_metrics(area, 1.0)
	var left: Rect2 = metrics.left_text
	# Latin is the source of truth so tutorial copy is never truncated by wide glyph cells.
	var title_latin := _layout_latin_block(page_title, left, true, 22.0, 28.0)
	var latin_body_top := left.position.y + 40.0
	if not title_latin.is_empty():
		latin_body_top = title_latin[title_latin.size() - 1].latin_pos.y + 30.0
	var latin_body_rect := Rect2(left.position.x, latin_body_top, left.size.x, left.end.y - latin_body_top)
	var body_latin := _layout_latin_block(page_body, latin_body_rect, false, 17.0, 23.0)
	# If body still overflows, retry once with a slightly tighter leading (font unchanged).
	if _count_chars(page_body) > body_latin.size():
		body_latin = _layout_latin_block(page_body, latin_body_rect, false, 16.0, 21.0)
	var title_glyphs := _layout_glyph_block(page_title, left, true, 20.0, 34.0, _fit_glyph_scale(page_title, left, 20.0, 34.0, 1.55))
	var glyph_body_top := left.position.y + 44.0
	if not title_glyphs.is_empty():
		glyph_body_top = title_glyphs[title_glyphs.size() - 1].glyph_pos.y + 36.0
	var glyph_body_rect := Rect2(left.position.x, glyph_body_top, left.size.x, left.end.y - glyph_body_top)
	var body_glyphs := _layout_glyph_block(page_body, glyph_body_rect, false, 16.0, 28.0, _fit_glyph_scale(page_body, glyph_body_rect, 16.0, 28.0, 1.45))
	_merge_dual_slots(title_glyphs, title_latin)
	_merge_dual_slots(body_glyphs, body_latin)

func _count_chars(text: String) -> int:
	var n := 0
	for c in text:
		if String(c) != " " and String(c) != "\n" and String(c) != "\r":
			n += 1
	return n

func _fit_glyph_scale(text: String, rect: Rect2, font_size: float, line_height: float, preferred: float) -> float:
	# Shrink glyph cells just enough so the full tutorial text still gets a glyph each.
	var scale := preferred
	while scale > 0.85:
		var laid := _layout_glyph_block(text, rect, false, font_size, maxf(line_height * (scale / preferred), font_size * 1.15), scale)
		if laid.size() >= _count_chars(text):
			return scale
		scale -= 0.08
	return 0.85

func _page_metrics(area: Vector2, open_override: float = -1.0) -> Dictionary:
	var open := open_amount if open_override < 0.0 else open_override
	var center := Vector2(area.x * 0.5, area.y * 0.54)
	var width := minf(area.x * 0.92, 980.0) * (0.78 + open * 0.22)
	var height := minf(area.y * 0.78, 470.0) * (0.85 + open * 0.15)
	var half := width * 0.5
	var top := center.y - height * 0.5
	var bottom := center.y + height * 0.5
	var spine := center.x
	var left_text := Rect2(spine - half + 52.0, top + 72.0, half - 84.0, bottom - top - 100.0)
	var right_art := Rect2(spine + 42.0, top + 78.0, half - 90.0, bottom - top - 120.0)
	return {
		"center": center, "half": half, "top": top, "bottom": bottom, "spine": spine,
		"left_text": left_text, "right_art": right_art
	}

func _layout_glyph_block(text: String, rect: Rect2, is_title: bool, font_size: float, line_height: float, cell_scale: float) -> Array:
	var out: Array = []
	if text.is_empty() or rect.size.y < line_height: return out
	var cell := font_size * cell_scale
	var space_w := cell * 0.55
	var x := rect.position.x
	var y := rect.position.y + font_size
	var max_x := rect.end.x
	var paragraphs := text.replace("\r", "").split("\n")
	for p_i in range(paragraphs.size()):
		if p_i > 0:
			x = rect.position.x
			y += line_height
		var paragraph: String = paragraphs[p_i]
		if paragraph.is_empty(): continue
		var parts := paragraph.split(" ")
		for w_i in range(parts.size()):
			var word: String = parts[w_i]
			var word_width := float(word.length()) * cell
			if x > rect.position.x and x + word_width > max_x:
				x = rect.position.x
				y += line_height
			if y > rect.end.y: return out
			for c in word:
				out.append({"ch": String(c), "glyph_pos": Vector2(x + cell * 0.5, y), "title": is_title, "size": font_size, "cell": cell})
				x += cell
			if w_i < parts.size() - 1:
				x += space_w
	return out

func _layout_latin_block(text: String, rect: Rect2, is_title: bool, font_size: float, line_height: float) -> Array:
	# Normal readable English spacing — independent from hieroglyph cell grid.
	var out: Array = []
	if text.is_empty() or rect.size.y < line_height: return out
	var font := _font()
	var x := rect.position.x
	var y := rect.position.y + font_size
	var max_x := rect.end.x
	var paragraphs := text.replace("\r", "").split("\n")
	for p_i in range(paragraphs.size()):
		if p_i > 0:
			x = rect.position.x
			y += line_height * 1.05
		var paragraph: String = paragraphs[p_i]
		if paragraph.is_empty(): continue
		var parts := paragraph.split(" ")
		for w_i in range(parts.size()):
			var word: String = parts[w_i]
			var token := word if w_i == parts.size() - 1 else word + " "
			var word_width := font.get_string_size(token, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size)).x
			if x > rect.position.x and x + word_width > max_x:
				x = rect.position.x
				y += line_height
			# Keep laying out past the soft bottom so tutorial copy is never silently dropped.
			for c in word:
				var ch := String(c)
				var advance := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size)).x
				out.append({"ch": ch, "latin_pos": Vector2(x, y), "title": is_title, "size": font_size})
				x += maxf(advance, font_size * 0.22)
			if w_i < parts.size() - 1:
				x += font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size)).x
	return out

func _merge_dual_slots(glyphs: Array, latins: Array) -> void:
	# Prefer full Latin copy; synthesize glyph positions if glyph layout still fell short.
	var n := latins.size()
	for i in range(n):
		var l: Dictionary = latins[i]
		var g: Dictionary = glyphs[i] if i < glyphs.size() else {}
		var glyph_pos: Vector2 = g.get("glyph_pos", l.latin_pos + Vector2(6, -4))
		var cell: float = float(g.get("cell", l.size * 1.2))
		_slots.append({
			"ch": l.ch,
			"glyph_pos": glyph_pos,
			"latin_pos": l.latin_pos,
			"title": l.title,
			"size": l.size,
			"cell": cell
		})

func _emit_translation_particles(previous_progress: float) -> void:
	_ensure_layout()
	if _slots.is_empty(): return
	var done := int(floor(translate_progress * float(_slots.size())))
	if done <= _last_done: return
	for i in range(_last_done + 1, mini(done + 1, _slots.size())):
		var slot: Dictionary = _slots[i]
		var origin: Vector2 = slot.latin_pos + Vector2(3, -8)
		for n in range(5):
			_particles.append({
				"pos": origin + Vector2(randf_range(-3, 3), randf_range(-4, 2)),
				"vel": Vector2(randf_range(-28, 28), randf_range(-70, -20)),
				"age": 0.0,
				"life": randf_range(0.28, 0.55),
				"hue": randf_range(0.08, 0.18)
			})
	_last_done = done

func _draw() -> void:
	var area := get_rect().size
	if area.x <= 0.0 or area.y <= 0.0: return
	_ensure_layout()
	var m := _page_metrics(area)
	var center: Vector2 = m.center
	var half: float = m.half
	var top: float = m.top
	var bottom: float = m.bottom
	var spine: float = m.spine
	draw_shadow_ellipse(Vector2(center.x, bottom + 20), Vector2(half * 0.82, 22), Color("120b10", 0.42))
	var cover := Color("57372a")
	draw_colored_polygon(PackedVector2Array([Vector2(spine - half, bottom - 9), Vector2(spine - half + 18, top + 25), Vector2(spine - 30, top + 10), Vector2(spine, bottom + 4)]), cover)
	draw_colored_polygon(PackedVector2Array([Vector2(spine, bottom + 4), Vector2(spine + 30, top + 10), Vector2(spine + half - 18, top + 25), Vector2(spine + half, bottom - 9)]), cover)
	for edge in range(6):
		var inset := 8.0 + edge * 6.0
		var shade := Color("b99a63").lerp(Color("6d4630"), float(edge) / 11.0)
		draw_arc(Vector2(spine - half * 0.52, bottom - inset), half * 0.43, 0.15, 2.96, 28, shade, 2.0)
		draw_arc(Vector2(spine + half * 0.52, bottom - inset), half * 0.43, 0.18, 2.99, 28, shade, 2.0)
	var page := Color("ead9a8")
	var page_shadow := Color("b99460", 0.8)
	var left := PackedVector2Array([Vector2(spine - 14, bottom - 15), Vector2(spine - half + 34, bottom - 31), Vector2(spine - half + 28, top + 45), Vector2(spine - half * 0.32, top + 16), Vector2(spine - 10, top + 44), Vector2(spine - 7, bottom - 22)])
	var right := PackedVector2Array([Vector2(spine + 14, bottom - 15), Vector2(spine + half - 34, bottom - 31), Vector2(spine + half - 28, top + 45), Vector2(spine + half * 0.32, top + 16), Vector2(spine + 10, top + 44), Vector2(spine + 7, bottom - 22)])
	draw_colored_polygon(left, page_shadow)
	draw_colored_polygon(right, page_shadow)
	draw_colored_polygon(left, page)
	draw_colored_polygon(right, page)
	draw_line(Vector2(spine, top + 40), Vector2(spine, bottom - 18), Color("785138"), 5.0)
	draw_line(Vector2(spine + 4, top + 43), Vector2(spine + 4, bottom - 23), Color("fff0bd", 0.55), 1.0)
	# Ruled lines on the left (text) page.
	for row in range(9):
		var y := top + 100 + row * 28
		draw_line(Vector2(spine - half + 50, y), Vector2(spine - 28, y), Color("b08955", 0.18), 1.0)
	_draw_left_translation()
	_draw_particles()
	if image_reveal > 0.001 and not illustration.is_empty():
		_draw_right_illustration(m.right_art)
	# Wax seal near spine top.
	var seal := Vector2(spine - 18, top + 58)
	draw_circle(seal, 16.0, Color("79504d", 0.76))
	draw_arc(seal, 11.0, 0.0, TAU, 20, Color("e7ce96", 0.68), 1.2)

func _draw_left_translation() -> void:
	if _slots.is_empty(): return
	var count := float(_slots.size())
	var cursor := translate_progress * count
	var font := _font()
	for i in range(_slots.size()):
		var slot: Dictionary = _slots[i]
		var font_size: float = slot.size
		var cell: float = float(slot.get("cell", font_size * 1.4))
		var local := cursor - float(i)
		var glyph_pos: Vector2 = slot.glyph_pos
		var letter_pos: Vector2 = slot.latin_pos
		var glyph_size := cell * 0.92
		var glyph_rect := Rect2(glyph_pos - Vector2(glyph_size * 0.5, glyph_size * 0.78), Vector2(glyph_size, glyph_size))
		if local < 0.0:
			_draw_glyph_art(glyph_rect, i)
		elif local >= 1.0:
			var ink := Color("4a3220") if slot.title else Color("5a4030")
			draw_string(font, letter_pos, slot.ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size), ink)
		else:
			# Morph: glyph fades in its grid; English appears with normal kerning.
			var glyph_a := 1.0 - local
			var letter_a := local
			_draw_glyph_art(glyph_rect, i, glyph_a)
			var ink2 := Color("4a3220", letter_a) if slot.title else Color("5a4030", letter_a)
			var pop := 1.0 + (1.0 - absf(local - 0.5) * 2.0) * 0.12
			draw_set_transform(letter_pos, 0.0, Vector2(pop, pop))
			draw_string(font, Vector2.ZERO, slot.ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size), ink2)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_particles() -> void:
	for p in _particles:
		var t: float = 1.0 - (p.age / p.life)
		var c := Color(1.0, 0.86 + p.hue, 0.45, 0.15 + 0.75 * t)
		draw_circle(p.pos, 1.4 + 2.2 * t, c)
		draw_circle(p.pos + Vector2(1.5, -1.0), 0.8 + t, Color(1, 1, 0.85, 0.35 * t))

func _draw_right_illustration(rect: Rect2) -> void:
	var a := image_reveal
	draw_rect(rect, Color("d9c48f", 0.35 * a), true)
	draw_rect(rect, Color("8a6840", 0.45 * a), false, 1.6)
	match illustration:
		"river":
			_illust_river(rect, a)
		"seed":
			_illust_seed(rect, a)
		"plant_space":
			_illust_plant_space(rect, a)

func _illust_tex(texture: Texture2D, rect: Rect2, tint: Color) -> void:
	if texture == null: return
	draw_texture_rect(texture, rect, false, tint)

func _angry_villager(feet: Vector2, alpha: float, spear: bool) -> void:
	var skin := Color("d7b08a", alpha)
	var cloth := Color("6b3030", alpha)
	var wood := Color("8a5a32", alpha)
	draw_circle(feet + Vector2(0, -40), 8.0, skin) # head
	# angry brows
	draw_line(feet + Vector2(-6, -43), feet + Vector2(-1, -41), Color("3a2418", alpha), 1.6)
	draw_line(feet + Vector2(1, -41), feet + Vector2(6, -43), Color("3a2418", alpha), 1.6)
	# open shouting mouth
	draw_circle(feet + Vector2(0, -36), 2.2, Color("4a1c1c", alpha))
	draw_colored_polygon(PackedVector2Array([
		feet + Vector2(-7, -32), feet + Vector2(7, -32), feet + Vector2(10, -8), feet + Vector2(-10, -8)
	]), cloth) # torso
	draw_line(feet + Vector2(-11, -24), feet + Vector2(-16, -6), skin, 2.4) # arms raised
	draw_line(feet + Vector2(11, -24), feet + Vector2(18, -48), skin, 2.4)
	draw_line(feet + Vector2(-5, -8), feet + Vector2(-4, 0), cloth, 2.2)
	draw_line(feet + Vector2(5, -8), feet + Vector2(5, 0), cloth, 2.2)
	if spear:
		draw_line(feet + Vector2(16, -10), feet + Vector2(22, -58), wood, 2.4)
		draw_colored_polygon(PackedVector2Array([
			feet + Vector2(22, -62), feet + Vector2(17, -52), feet + Vector2(27, -52)
		]), Color("cfc7b0", alpha))
	else:
		draw_line(feet + Vector2(14, -20), feet + Vector2(20, -46), wood, 3.2)

func _illust_river(rect: Rect2, a: float) -> void:
	# Sky / far bank
	draw_rect(rect, Color("2a3340", 0.95 * a), true)
	draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * 0.28, rect.size.x, rect.size.y * 0.18), Color("3d4a3a", 0.95 * a), true)
	# Angry villagers on the bank
	for i in range(5):
		var feet := Vector2(rect.position.x + 24 + i * (rect.size.x - 40) / 4.0, rect.position.y + rect.size.y * 0.44)
		_angry_villager(feet, 0.95 * a, i != 2)
	# River body
	var water := Rect2(rect.position.x, rect.position.y + rect.size.y * 0.48, rect.size.x, rect.size.y * 0.52)
	draw_rect(water, Color("1a5563", 0.98 * a), true)
	for i in range(6):
		var y := water.position.y + 10 + i * 14.0
		draw_line(Vector2(water.position.x + 6, y), Vector2(water.end.x - 6, y + sin(i * 1.7) * 3.0), Color("7fd0c8", 0.28 * a), 1.4)
	# Drowning witch — large, tilted, half submerged, arms implied by offset layers
	var witch_size := Vector2(rect.size.x * 0.42, rect.size.y * 0.42)
	var witch_pos := Vector2(rect.position.x + rect.size.x * 0.30, water.position.y + water.size.y * 0.05)
	if art != null and art.witch_past_texture != null:
		_illust_tex(art.witch_past_texture, Rect2(witch_pos, witch_size), Color(0.55, 0.78, 1.0, 0.95 * a))
		_illust_tex(art.witch_past_texture, Rect2(witch_pos + Vector2(10, witch_size.y * 0.28), witch_size * Vector2(0.92, 0.72)), Color(0.25, 0.45, 0.7, 0.55 * a))
	# Splashes / bubbles
	for i in range(10):
		var p := witch_pos + Vector2(witch_size.x * 0.35, witch_size.y * 0.2) + Vector2(cos(i * 0.9) * 34.0, sin(i * 1.3) * 12.0)
		draw_circle(p, 2.0 + (i % 3), Color("e8fbff", (0.25 + (i % 3) * 0.1) * a))
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 10, rect.end.y - 10), "Thrown to the river", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e8d7a4", 0.9 * a))

func _illust_seed(rect: Rect2, a: float) -> void:
	draw_rect(rect, Color("18241f", 0.96 * a), true)
	var mid := rect.position.x + rect.size.x * 0.5
	draw_line(Vector2(mid, rect.position.y + 12), Vector2(mid, rect.end.y - 14), Color("3d5a4c", 0.75 * a), 2.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 18), "PAST", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("9ed6bd", 0.95 * a))
	draw_string(ThemeDB.fallback_font, Vector2(mid + 14, rect.position.y + 18), "PRESENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("9ed6bd", 0.95 * a))
	# Ground lines
	draw_line(Vector2(rect.position.x + 12, rect.position.y + rect.size.y * 0.72), Vector2(mid - 12, rect.position.y + rect.size.y * 0.72), Color("4a6a55", 0.7 * a), 2.0)
	draw_line(Vector2(mid + 12, rect.position.y + rect.size.y * 0.72), Vector2(rect.end.x - 12, rect.position.y + rect.size.y * 0.72), Color("4a6a55", 0.7 * a), 2.0)
	if art != null:
		_illust_tex(art.witch_past_texture, Rect2(rect.position + Vector2(18, 34), rect.size * Vector2(0.30, 0.34)), Color(1, 1, 1, a))
		_illust_tex(art.seed_texture, Rect2(rect.position + Vector2(40, rect.size.y * 0.55), rect.size * Vector2(0.18, 0.18)), Color(1, 1, 1, a))
		_illust_tex(art.tree_texture, Rect2(Vector2(mid + 22, rect.position.y + 28), rect.size * Vector2(0.32, 0.48)), Color(1, 1, 1, a))
		_illust_tex(art.witch_future_texture, Rect2(Vector2(mid + 36, rect.position.y + rect.size.y * 0.52), rect.size * Vector2(0.26, 0.30)), Color(1, 1, 1, a))
	var ay := rect.position.y + rect.size.y * 0.48
	draw_line(Vector2(mid - 26, ay), Vector2(mid + 18, ay), Color("e6c984", 0.95 * a), 3.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(mid + 26, ay), Vector2(mid + 12, ay - 8), Vector2(mid + 12, ay + 8)
	]), Color("e6c984", 0.95 * a))
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 10, rect.end.y - 10), "Seed then → tree now", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e8d7a4", 0.9 * a))

func _illust_plant_space(rect: Rect2, a: float) -> void:
	# Clear Space-to-plant tutorial for unlocking seeds on the next level.
	draw_rect(rect, Color("141f28", 0.97 * a), true)
	var pad := 14.0
	var top := Rect2(rect.position + Vector2(pad, pad), Vector2(rect.size.x - pad * 2.0, rect.size.y * 0.42))
	draw_rect(top, Color("1c2c36", 0.95 * a), true)
	draw_rect(top, Color("7ec8c4", 0.35 * a), false, 2.0)
	# Past witch plants a seed.
	if art != null:
		_illust_tex(art.witch_past_texture, Rect2(top.position + Vector2(18, 18), Vector2(top.size.y * 0.72, top.size.y * 0.72)), Color(1, 1, 1, a))
		_illust_tex(art.seed_texture, Rect2(top.position + Vector2(top.size.x * 0.38, top.size.y * 0.42), Vector2(44, 44)), Color(1, 1, 1, a))
		_illust_tex(art.tree_texture, Rect2(top.position + Vector2(top.size.x * 0.62, 10), Vector2(top.size.y * 0.78, top.size.y * 0.78)), Color(1, 1, 1, a))
	draw_string(ThemeDB.fallback_font, top.position + Vector2(18, 16), "PAST", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("9ed6bd", a))
	draw_string(ThemeDB.fallback_font, top.position + Vector2(top.size.x * 0.62, 16), "PRESENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("9ed6bd", a))
	# Arrow past -> present
	var ay := top.position.y + top.size.y * 0.55
	var ax0 := top.position.x + top.size.x * 0.50
	draw_line(Vector2(ax0 - 18, ay), Vector2(ax0 + 18, ay), Color("e6c984", 0.95 * a), 3.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(ax0 + 24, ay), Vector2(ax0 + 12, ay - 8), Vector2(ax0 + 12, ay + 8)
	]), Color("e6c984", 0.95 * a))
	# Giant SPACE key
	var key := Rect2(rect.position.x + rect.size.x * 0.18, rect.position.y + rect.size.y * 0.52, rect.size.x * 0.64, rect.size.y * 0.28)
	var key_bg := Color("243844", 0.98 * a)
	var key_edge := Color("e6c984", 0.95 * a)
	draw_rect(key, key_bg, true)
	draw_rect(key, key_edge, false, 3.0)
	draw_rect(Rect2(key.position + Vector2(6, 6), key.size - Vector2(12, 12)), Color("1a2830", 0.9 * a), true)
	var label := "SPACE"
	var font := ThemeDB.fallback_font
	var fs := 34
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(key.get_center().x - tw * 0.5, key.get_center().y + 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f3e7c0", a))
	draw_string(font, Vector2(rect.position.x + 16, rect.end.y - 12), "Press SPACE to plant a seed", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e8d7a4", 0.95 * a))

func _glyph_src_rect(index: int) -> Rect2:
	var sheet: Texture2D = _glyph_cutout if _glyph_cutout != null else GLYPH_SHEET
	var i := index % (GLYPH_COLS * GLYPH_ROWS)
	var col := i % GLYPH_COLS
	var row := int(i / GLYPH_COLS)
	var tw := float(sheet.get_width())
	var th := float(sheet.get_height())
	var gw := tw / float(GLYPH_COLS)
	var gh := th / float(GLYPH_ROWS)
	# Inset each cell so we crop a single carved symbol rather than the grid gutters.
	return Rect2(col * gw + gw * 0.10, row * gh + gh * 0.12, gw * 0.80, gh * 0.76)

func _draw_glyph_art(dest: Rect2, index: int, alpha: float = 1.0) -> void:
	var sheet: Texture2D = _glyph_cutout if _glyph_cutout != null else GLYPH_SHEET
	if sheet == null:
		_draw_glyph_fallback(dest.get_center(), index, alpha)
		return
	# Transparent cutout only — sits on parchment with no sandstone plate behind it.
	draw_texture_rect_region(sheet, dest, _glyph_src_rect(index), Color(1, 1, 1, 0.95 * alpha))

func _draw_glyph_fallback(pos: Vector2, index: int, alpha: float = 0.78) -> void:
	var ink := Color("604433", alpha)
	match index % 5:
		0:
			draw_circle(pos, 8.0, Color(ink.r, ink.g, ink.b, 0.16 * alpha), false, 1.4)
			draw_line(pos + Vector2(-9, 7), pos + Vector2(9, -7), ink, 1.8)
		1:
			draw_line(pos + Vector2(-9, -8), pos + Vector2(0, 9), ink, 1.7)
			draw_line(pos + Vector2(0, 9), pos + Vector2(9, -8), ink, 1.7)
		2:
			draw_arc(pos, 9.0, -1.2, 1.5, 12, ink, 1.7)
		3:
			draw_line(pos + Vector2(0, -10), pos + Vector2(0, 10), ink, 1.7)
		4:
			draw_arc(pos, 8.5, 0.2, 5.8, 8, ink, 1.5)

func draw_shadow_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(33):
		var angle := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
