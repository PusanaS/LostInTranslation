extends Control
## Soft drifting starfield behind the boards. Code-drawn, no textures required.

var _stars: Array = [] # {pos, size, phase, speed, bright}
var _dust: Array = [] # slow drifting motes
var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)
	_rebuild()
	resized.connect(_rebuild)

func _rebuild() -> void:
	_stars.clear()
	_dust.clear()
	var area := size
	if area.x < 8.0 or area.y < 8.0: return
	var star_count := clampi(int(area.x * area.y / 14000.0), 28, 70)
	for i in range(star_count):
		_stars.append({
			"pos": Vector2(randf() * area.x, randf() * area.y),
			"size": randf_range(1.0, 2.4),
			"phase": randf() * TAU,
			"speed": randf_range(0.35, 1.1),
			"bright": randf_range(0.35, 0.9)
		})
	for i in range(18):
		_dust.append({
			"pos": Vector2(randf() * area.x, randf() * area.y),
			"vel": Vector2(randf_range(-6.0, 6.0), randf_range(-3.0, -10.0)),
			"size": randf_range(1.2, 2.6),
			"alpha": randf_range(0.08, 0.22)
		})
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	var area := size
	for d in _dust:
		d.pos += d.vel * delta
		if d.pos.y < -8.0:
			d.pos.y = area.y + 8.0
			d.pos.x = randf() * area.x
		elif d.pos.x < -8.0:
			d.pos.x = area.x + 8.0
		elif d.pos.x > area.x + 8.0:
			d.pos.x = -8.0
	queue_redraw()

func _draw() -> void:
	# Deep night wash behind the playfield.
	draw_rect(Rect2(Vector2.ZERO, size), Color("071018"), true)
	# Subtle vertical gradient veil.
	for i in range(6):
		var t := float(i) / 5.0
		var y := size.y * t
		draw_rect(Rect2(0.0, y, size.x, size.y / 5.0 + 2.0), Color(0.05, 0.09, 0.14, 0.12 * (1.0 - t)), true)
	for s in _stars:
		var twinkle := 0.55 + 0.45 * sin(_time * s.speed + s.phase)
		var c := Color(0.85, 0.92, 1.0, s.bright * twinkle * 0.55)
		draw_circle(s.pos, s.size * (0.7 + 0.3 * twinkle), c)
		if s.size > 1.8:
			draw_circle(s.pos, s.size * 0.35, Color(1, 1, 1, 0.35 * twinkle))
	for d in _dust:
		draw_circle(d.pos, d.size, Color(0.7, 0.85, 1.0, d.alpha))
