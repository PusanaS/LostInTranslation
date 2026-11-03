extends Control
## Rendering only. Replacing textures does not affect collision or game rules.
var engine: RefCounted
var state: Dictionary
var room := 0
var art: Resource
var tile_size := 48
var display_position := Vector2.ZERO
var move_from := Vector2.ZERO
var move_to := Vector2.ZERO
var move_elapsed := 0.0
var move_duration := 0.0
var moving := false
var sliding := false
var bump_elapsed := 1.0
var growing: Dictionary = {}
var flash_cell := Vector2i(-999, -999)
var flash_elapsed := 99.0
const FLASH_DURATION := 0.72
var idle_time := 0.0
var idle_bob := 0.0
var env_time := 0.0
var book_sparks: Array = [] # {pos:Vector2, age:float, life:float, vel:Vector2}
var ice_glints: Array = [] # {origin:Vector2, t:float, span:float}

func flash_tile(x: int, y: int) -> void:
	flash_cell = Vector2i(x, y)
	flash_elapsed = 0.0
	queue_redraw()

func fit_to_space(space: Vector2) -> void:
	if engine == null or engine.level.maps.is_empty(): return
	var map: Array = engine.level.maps[room]
	if map.is_empty() or map[0].length() == 0: return
	# Small rooms grow to fill their half of the screen; large rooms shrink to fit.
	var by_width := space.x / float(map[0].length())
	var by_height := space.y / float(map.size())
	var next_size := clampi(int(floor(minf(by_width, by_height))), 20, 160)
	if next_size == tile_size: return
	tile_size = next_size
	custom_minimum_size = Vector2(map[0].length(), map.size()) * tile_size
	queue_redraw()

func update_board(new_engine: RefCounted, new_state: Dictionary, index: int, new_art: Resource) -> void:
	var old_state := state
	engine = new_engine
	state = new_state
	room = index
	art = new_art
	var target := Vector2(state.p[room][0], state.p[room][1])
	if old_state.is_empty():
		display_position = target
		move_to = target
	elif old_state.p[room] != state.p[room]:
		move_from = display_position
		move_to = target
		move_elapsed = 0.0
		sliding = _movement_touches_ice(old_state.p[room], state.p[room])
		move_duration = 0.52 if sliding else 0.22
		moving = true
	for key in state.trees:
		if not key in old_state.get("trees", []) and room == 1: growing[key] = 0.0
	for key in growing.keys().duplicate():
		if not key in state.trees: growing.erase(key)
	custom_minimum_size = Vector2(engine.level.maps[room][0].length(), engine.level.maps[room].size()) * tile_size
	queue_redraw()

func _movement_touches_ice(from: Array, to: Array) -> bool:
	if engine == null: return false
	if engine.tile(room, from[0], from[1]) == "I" or engine.tile(room, to[0], to[1]) == "I": return true
	var steps := maxi(absi(to[0] - from[0]), absi(to[1] - from[1]))
	if steps <= 1: return false
	for step in range(1, steps):
		var x: int = int(from[0]) + signi(int(to[0]) - int(from[0])) * step
		var y: int = int(from[1]) + signi(int(to[1]) - int(from[1])) * step
		if engine.tile(room, x, y) == "I": return true
	return false

func bump() -> void:
	bump_elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	var redraw := false
	env_time += delta
	redraw = true
	if moving:
		move_elapsed += delta
		var weight := clampf(move_elapsed / move_duration, 0.0, 1.0)
		weight = weight * weight * (3.0 - 2.0 * weight) if sliding else weight
		display_position = move_from.lerp(move_to, weight)
		if weight >= 1.0:
			display_position = move_to
			moving = false
			idle_time = 0.0
	else:
		idle_time += delta
		idle_bob = sin(idle_time * 2.15) * tile_size * 0.035
	if bump_elapsed >= 0.0 and bump_elapsed < 0.18:
		bump_elapsed += delta
	for key in growing.keys().duplicate():
		growing[key] = float(growing[key]) + delta
		if growing[key] >= 1.0: growing.erase(key)
	if flash_elapsed < FLASH_DURATION:
		flash_elapsed += delta
	_update_env_fx(delta)
	if redraw: queue_redraw()

func _update_env_fx(delta: float) -> void:
	if engine == null or state.is_empty(): return
	var map: Array = engine.level.maps[room]
	var goal: Array = engine.level.goal[room]
	# Book halo sparks.
	if randf() < delta * 3.5:
		var center := (Vector2(goal[0], goal[1]) + Vector2(0.5, 0.5)) * tile_size
		book_sparks.append({
			"pos": center + Vector2(randf_range(-tile_size * 0.25, tile_size * 0.25), randf_range(-tile_size * 0.1, tile_size * 0.2)),
			"vel": Vector2(randf_range(-8.0, 8.0), randf_range(-22.0, -8.0)),
			"age": 0.0,
			"life": randf_range(0.45, 0.9)
		})
	var alive_sparks: Array = []
	for s in book_sparks:
		s.age += delta
		s.pos += s.vel * delta
		if s.age < s.life: alive_sparks.append(s)
	book_sparks = alive_sparks
	# Ice mirror glints — spawn occasionally on ice tiles.
	if randf() < delta * 2.2:
		for y in range(map.size()):
			for x in range(map[y].length()):
				if map[y][x] != "I": continue
				if randf() > 0.18: continue
				ice_glints.append({
					"origin": Vector2(x, y) * tile_size,
					"t": 0.0,
					"span": randf_range(0.55, 0.95)
				})
	var alive_glints: Array = []
	for g in ice_glints:
		g.t += delta / g.span
		if g.t < 1.0: alive_glints.append(g)
	ice_glints = alive_glints

func texture_at(texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> void:
	if texture != null: draw_texture_rect(texture, rect, false, tint)

func book_screen_center() -> Vector2:
	if engine == null: return get_global_rect().get_center()
	var goal: Array = engine.level.goal[room]
	return global_position + (Vector2(goal[0], goal[1]) + Vector2(0.5, 0.5)) * tile_size

func seed_screen_center(cell: Array) -> Vector2:
	return global_position + (Vector2(cell[0], cell[1]) + Vector2(0.5, 0.5)) * tile_size

func _draw_river_anim(rect: Rect2) -> void:
	# Soft scrolling water bands over the river tile.
	for i in range(3):
		var phase := env_time * (0.55 + i * 0.18) + float(i) * 1.7
		var y := rect.position.y + fposmod(phase * tile_size * 0.35, rect.size.y)
		var a := 0.10 + 0.08 * sin(phase * 2.0)
		draw_line(Vector2(rect.position.x + 3, y), Vector2(rect.end.x - 3, y + sin(phase) * 2.0), Color(0.75, 0.95, 1.0, a), 1.6)
	# Gentle caustic shimmer.
	var shimmer_x := rect.position.x + fposmod(env_time * tile_size * 0.4, rect.size.x)
	draw_line(Vector2(shimmer_x, rect.position.y + 4), Vector2(shimmer_x + tile_size * 0.15, rect.end.y - 4), Color(0.85, 1.0, 1.0, 0.12), 2.0)

func _draw_ice_glints() -> void:
	for g in ice_glints:
		var t: float = g.t
		var p0: Vector2 = g.origin + Vector2(-tile_size * 0.1, tile_size * 0.15) + Vector2(tile_size * 1.2, tile_size * 0.7) * t
		var p1 := p0 + Vector2(tile_size * 0.35, tile_size * 0.18)
		var a := sin(t * PI) * 0.55
		draw_line(p0, p1, Color(1.0, 1.0, 1.0, a), 2.2)
		draw_line(p0 + Vector2(0, 2), p1 + Vector2(0, 2), Color(0.75, 0.9, 1.0, a * 0.45), 1.2)

func _draw_book(rect: Rect2) -> void:
	var center := rect.get_center()
	var pulse := 0.5 + 0.5 * sin(env_time * 2.0)
	# Soft golden halo behind the book.
	for i in range(3):
		var r := tile_size * (0.28 + i * 0.12 + pulse * 0.04)
		draw_circle(center, r, Color(0.95, 0.82, 0.35, 0.10 - i * 0.025))
	for s in book_sparks:
		var life_t: float = 1.0 - s.age / s.life
		draw_circle(s.pos, 1.2 + 1.6 * life_t, Color(1.0, 0.9, 0.55, 0.15 + 0.55 * life_t))
	var bob := sin(env_time * 2.4) * tile_size * 0.04
	var breathe := 1.0 + sin(env_time * 1.8) * 0.04
	var book_size := rect.size * breathe
	var book_rect := Rect2(center - book_size * 0.5 + Vector2(0, bob), book_size)
	texture_at(art.book_texture, book_rect)

func _draw() -> void:
	if engine == null or art == null or state.is_empty(): return
	var map: Array = engine.level.maps[room]
	for y in range(map.size()):
		for x in range(map[y].length()):
			var rect := Rect2(Vector2(x, y) * tile_size, Vector2.ONE * tile_size)
			texture_at(art.floor_texture, rect)
			var t: String = map[y][x]
			match t:
				"#":
					texture_at(art.wall_texture, rect)
				"I":
					texture_at(art.ice_texture, rect)
				"H":
					texture_at(art.hole_texture, rect)
				"W":
					texture_at(art.river_texture, rect)
					_draw_river_anim(rect)
				"D":
					texture_at(art.door_open_texture if engine.door_open(state, room, x, y) else art.door_closed_texture, rect)
				"P":
					var pressed: bool = (state.p[room] == [x, y] and not state.dead[room]) or (room == 1 and engine.coord([x, y]) in state.trees)
					texture_at(art.plate_down_texture if pressed else art.plate_up_texture, rect)
			if engine.level.goal[room] == [x, y]:
				_draw_book(rect)
			if engine.coord([x, y]) in state.trees:
				var plant_rect := rect
				if room == 1 and growing.has(engine.coord([x, y])):
					var progress: float = clampf(float(growing[engine.coord([x, y])]), 0.0, 1.0)
					var scale := lerpf(0.08, 1.08, sin(progress * PI * 0.5))
					plant_rect = Rect2(rect.get_center() - rect.size * scale * 0.5, rect.size * scale)
				texture_at(art.seed_texture if room == 0 else (art.lily_texture if t == "W" else art.tree_texture), plant_rect)
			if t in ["D", "P"]:
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(tile_size - 15, 14), engine.pair(room, x, y), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("fff0c5"))
	_draw_ice_glints()
	var player_tile := Rect2(display_position * tile_size, Vector2.ONE * tile_size)
	var lift := -sin(clampf(move_elapsed / maxf(move_duration, 0.01), 0.0, 1.0) * PI) * tile_size * 0.12 if moving and not sliding else 0.0
	var bounce := sin(clampf(bump_elapsed / 0.18, 0.0, 1.0) * PI * 2.0) * tile_size * 0.10 if bump_elapsed < 0.18 else 0.0
	player_tile.position.y += lift + (0.0 if moving or state.dead[room] else idle_bob)
	player_tile.position.x += bounce
	texture_at(art.witch_past_texture if room == 0 else art.witch_future_texture, player_tile.grow(-tile_size * 0.06), Color(1, 1, 1, 0.25) if state.dead[room] else Color.WHITE)
	if flash_elapsed < FLASH_DURATION and flash_cell.x >= 0 and flash_cell.y >= 0:
		var pulse := absf(sin(flash_elapsed / (FLASH_DURATION * 0.5) * PI))
		var flash_rect := Rect2(Vector2(flash_cell) * tile_size, Vector2.ONE * tile_size).grow(-tile_size * 0.04)
		draw_rect(flash_rect, Color(1.0, 0.18, 0.22, 0.10 + 0.22 * pulse), true)
		draw_rect(flash_rect, Color(1.0, 0.28, 0.32, 0.35 + 0.55 * pulse), false, maxf(2.0, tile_size * 0.07))
