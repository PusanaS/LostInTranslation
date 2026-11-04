extends Control
## Code-drawn tutorial / loss illustrations. Replace with painted PNG later if desired.
## kind: "river" | "seed" | "drowned" | "void"
var kind := "":
	set(value):
		kind = value
		queue_redraw()
var art: Resource
var reveal := 1.0:
	set(value):
		reveal = clampf(value, 0.0, 1.0)
		queue_redraw()

func setup(new_kind: String, new_art: Resource = null) -> void:
	kind = new_kind
	art = new_art
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0 or reveal <= 0.0: return
	match kind:
		"river":
			_draw_river_lesson()
		"seed":
			_draw_seed_lesson()
		"drowned":
			_draw_drowned_loss()
		"void":
			_draw_void_loss()

func _tex(texture: Texture2D, rect: Rect2, tint := Color.WHITE) -> void:
	if texture == null: return
	draw_texture_rect(texture, rect, false, Color(tint.r, tint.g, tint.b, tint.a * reveal))

func _angry_villager(feet: Vector2, spear: bool) -> void:
	var a := reveal
	# Prefer the hand-drawn soldier sprite; the code-drawn figure below is only a fallback.
	var soldier: Texture2D = art.get("soldier_texture") if art != null else null
	if soldier != null:
		var h := 70.0
		_tex(soldier, Rect2(feet + Vector2(-h * 0.5, -h), Vector2(h, h)))
		return
	var skin := Color("d7b08a", a)
	var cloth := Color("6b3030", a)
	var wood := Color("8a5a32", a)
	draw_circle(feet + Vector2(0, -40), 8.0, skin)
	draw_line(feet + Vector2(-6, -43), feet + Vector2(-1, -41), Color("3a2418", a), 1.6)
	draw_line(feet + Vector2(1, -41), feet + Vector2(6, -43), Color("3a2418", a), 1.6)
	draw_circle(feet + Vector2(0, -36), 2.2, Color("4a1c1c", a))
	draw_colored_polygon(PackedVector2Array([
		feet + Vector2(-7, -32), feet + Vector2(7, -32), feet + Vector2(10, -8), feet + Vector2(-10, -8)
	]), cloth)
	draw_line(feet + Vector2(-11, -24), feet + Vector2(-16, -6), skin, 2.4)
	draw_line(feet + Vector2(11, -24), feet + Vector2(18, -48), skin, 2.4)
	draw_line(feet + Vector2(-5, -8), feet + Vector2(-4, 0), cloth, 2.2)
	draw_line(feet + Vector2(5, -8), feet + Vector2(5, 0), cloth, 2.2)
	if spear:
		draw_line(feet + Vector2(16, -10), feet + Vector2(22, -58), wood, 2.4)
		draw_colored_polygon(PackedVector2Array([
			feet + Vector2(22, -62), feet + Vector2(17, -52), feet + Vector2(27, -52)
		]), Color("cfc7b0", a))
	else:
		draw_line(feet + Vector2(14, -20), feet + Vector2(20, -46), wood, 3.2)

func _draw_river_lesson() -> void:
	var area := size
	draw_rect(Rect2(Vector2.ZERO, area), Color("2a3340", 0.95 * reveal), true)
	draw_rect(Rect2(0, area.y * 0.28, area.x, area.y * 0.18), Color("3d4a3a", 0.95 * reveal), true)
	for i in range(5):
		var feet := Vector2(24 + i * (area.x - 40) / 4.0, area.y * 0.44)
		_angry_villager(feet, i != 2)
	var water := Rect2(0, area.y * 0.48, area.x, area.y * 0.52)
	draw_rect(water, Color("1a5563", 0.98 * reveal), true)
	for i in range(6):
		var y := water.position.y + 10 + i * 14.0
		draw_line(Vector2(6, y), Vector2(area.x - 6, y + sin(i * 1.7) * 3.0), Color("7fd0c8", 0.28 * reveal), 1.4)
	var witch := Rect2(area.x * 0.28, water.position.y + 4, area.x * 0.44, area.y * 0.40)
	if art != null and art.witch_past_texture != null:
		_tex(art.witch_past_texture, witch, Color(0.55, 0.78, 1.0, 0.95))
		_tex(art.witch_past_texture, Rect2(witch.position + Vector2(10, witch.size.y * 0.28), witch.size * Vector2(0.92, 0.72)), Color(0.25, 0.45, 0.7, 0.55))
	for i in range(10):
		var p := witch.get_center() + Vector2(cos(i * 0.9) * 34.0, sin(i * 1.3) * 12.0 - 8.0)
		draw_circle(p, 2.0 + (i % 3), Color("e8fbff", (0.25 + (i % 3) * 0.1) * reveal))
	draw_string(ThemeDB.fallback_font, Vector2(12, area.y - 10), "Thrown to the river", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e8d7a4", 0.9 * reveal))

func _draw_seed_lesson() -> void:
	var area := size
	draw_rect(Rect2(Vector2.ZERO, area), Color("18241f", 0.96 * reveal), true)
	var mid := area.x * 0.5
	draw_line(Vector2(mid, 12), Vector2(mid, area.y - 14), Color("3d5a4c", 0.75 * reveal), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(14, 18), "PAST", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("9ed6bd", 0.95 * reveal))
	draw_string(ThemeDB.fallback_font, Vector2(mid + 14, 18), "PRESENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("9ed6bd", 0.95 * reveal))
	if art != null:
		_tex(art.witch_past_texture, Rect2(18, 34, area.x * 0.30, area.y * 0.34))
		_tex(art.seed_texture, Rect2(40, area.y * 0.55, area.x * 0.18, area.y * 0.18))
		_tex(art.tree_texture, Rect2(mid + 22, 28, area.x * 0.32, area.y * 0.48))
		_tex(art.witch_future_texture, Rect2(mid + 36, area.y * 0.52, area.x * 0.26, area.y * 0.30))
	var ay := area.y * 0.48
	draw_line(Vector2(mid - 26, ay), Vector2(mid + 18, ay), Color("e6c984", 0.95 * reveal), 3.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(mid + 26, ay), Vector2(mid + 12, ay - 8), Vector2(mid + 12, ay + 8)
	]), Color("e6c984", 0.95 * reveal))
	draw_string(ThemeDB.fallback_font, Vector2(12, area.y - 10), "Seed then → tree now", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e8d7a4", 0.9 * reveal))

func _draw_drowned_loss() -> void:
	var area := size
	# The player slipping into an open dimension crack.
	draw_rect(Rect2(Vector2.ZERO, area), Color("120c24", 0.98 * reveal), true)
	var crack := Rect2(area.x * 0.18, area.y * 0.38, area.x * 0.64, area.y * 0.60)
	draw_circle(crack.get_center(), crack.size.y * 0.55, Color(0.55, 0.25, 1.0, 0.18 * reveal))
	if art != null and art.river_texture != null:
		_tex(art.river_texture, crack)
	var h := area.y * 0.55
	var player := Rect2(area.x * 0.5 - h * 0.5, area.y * 0.12, h, h)
	if art != null and art.witch_future_texture != null:
		_tex(art.witch_future_texture, player, Color(0.75, 0.6, 1.0, 0.7))
	for i in range(12):
		draw_circle(player.get_center() + Vector2(cos(i * 0.9) * 60.0, sin(i * 1.3) * 30.0 + 30.0), 1.6 + (i % 3), Color("e2ccff", (0.25 + (i % 3) * 0.12) * reveal))

func _draw_void_loss() -> void:
	var area := size
	draw_rect(Rect2(Vector2.ZERO, area), Color("0a0c12", 0.98 * reveal), true)
	var hole := area * 0.5
	for ring in range(5):
		var r := 18.0 + ring * 14.0
		draw_arc(hole, r, 0.0, TAU, 40, Color("2a1030", (0.55 - ring * 0.08) * reveal), 3.0, true)
	draw_circle(hole, 16.0, Color("050508", 0.95 * reveal))
	var witch := Rect2(hole - Vector2(36, 52), Vector2(72, 72))
	if art != null and art.witch_past_texture != null:
		_tex(art.witch_past_texture, witch, Color(1, 1, 1, 0.55))
	if art != null and art.hole_texture != null:
		_tex(art.hole_texture, Rect2(hole - Vector2(40, 40), Vector2(80, 80)), Color(1, 1, 1, 0.35))
