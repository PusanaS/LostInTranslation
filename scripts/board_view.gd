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
var anim_time := 0.0
var facing_right := false
const FLASH_DURATION := 0.72
const IDLE_FRAME_SECONDS := 0.55
const WALK_FRAME_SECONDS := 0.07

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
	var next_size := clampi(int(floor(minf(by_width,by_height))),20,160)
	if next_size == tile_size: return
	tile_size = next_size
	custom_minimum_size = Vector2(map[0].length(),map.size()) * tile_size
	queue_redraw()

func update_board(new_engine: RefCounted, new_state: Dictionary, index: int, new_art: Resource) -> void:
	var old_state := state
	engine = new_engine
	state = new_state
	room = index
	art = new_art
	var target := Vector2(state.p[room][0],state.p[room][1])
	if old_state.is_empty():
		display_position = target
		move_to = target
	elif old_state.p[room] != state.p[room]:
		move_from = display_position
		move_to = target
		if target.x != move_from.x: facing_right = target.x > move_from.x
		move_elapsed = 0.0
		sliding = _movement_touches_ice(old_state.p[room],state.p[room])
		move_duration = 0.52 if sliding else 0.22
		moving = true
	for key in state.trees:
		if not key in old_state.get("trees",[]) and room == 1: growing[key] = 0.0
	for key in growing.keys().duplicate():
		if not key in state.trees: growing.erase(key)
	custom_minimum_size = Vector2(engine.level.maps[room][0].length(),engine.level.maps[room].size()) * tile_size
	queue_redraw()

func _movement_touches_ice(from: Array, to: Array) -> bool:
	if engine == null: return false
	if engine.tile(room,from[0],from[1]) == "I" or engine.tile(room,to[0],to[1]) == "I": return true
	var steps := maxi(absi(to[0]-from[0]),absi(to[1]-from[1]))
	if steps <= 1: return false
	for step in range(1,steps):
		var x: int = int(from[0]) + signi(int(to[0])-int(from[0]))*step
		var y: int = int(from[1]) + signi(int(to[1])-int(from[1]))*step
		if engine.tile(room,x,y) == "I": return true
	return false

func bump() -> void:
	bump_elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	anim_time += delta
	# Idle breathing frames and the rift shimmer need a steady redraw.
	var redraw := true
	if moving:
		move_elapsed += delta
		var weight := clampf(move_elapsed / move_duration,0.0,1.0)
		weight = weight * weight * (3.0 - 2.0 * weight) if sliding else weight
		display_position = move_from.lerp(move_to,weight)
		redraw = true
		if weight >= 1.0:
			display_position = move_to
			moving = false
	if bump_elapsed >= 0.0 and bump_elapsed < 0.18:
		bump_elapsed += delta
		redraw = true
	for key in growing.keys().duplicate():
		growing[key] = float(growing[key]) + delta
		if growing[key] >= 1.0: growing.erase(key)
		redraw = true
	if flash_elapsed < FLASH_DURATION:
		flash_elapsed += delta
		redraw = true
	if redraw: queue_redraw()

func texture_at(texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> void:
	if texture != null: draw_texture_rect(texture,rect,false,tint)

## Draws a texture inside rect keeping its aspect ratio, standing on the rect's bottom edge.
func texture_standing(texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE, flip := false) -> void:
	if texture == null: return
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0: return
	var scale := minf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
	var drawn := tex_size * scale
	var pos := Vector2(rect.get_center().x - drawn.x * 0.5, rect.end.y - drawn.y)
	if flip:
		draw_set_transform(Vector2(pos.x + drawn.x, pos.y), 0.0, Vector2(-1, 1))
		draw_texture_rect(texture,Rect2(Vector2.ZERO,drawn),false,tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(texture,Rect2(pos,drawn),false,tint)

func _player_frame() -> Texture2D:
	if art == null: return null
	if room == 0: return art.witch_past_texture
	var walk: Array = art.get("player_walk_frames") if art.get("player_walk_frames") != null else []
	var idle: Array = art.get("player_idle_frames") if art.get("player_idle_frames") != null else []
	if moving and not walk.is_empty():
		return walk[int(move_elapsed / WALK_FRAME_SECONDS) % walk.size()]
	if not idle.is_empty():
		return idle[int(anim_time / IDLE_FRAME_SECONDS) % idle.size()]
	return art.witch_future_texture

func _draw_rift_glow(rect: Rect2, strength: float) -> void:
	# Soft violet pulse that sits under cracks and freshly summoned cubes.
	var pulse := 0.5 + 0.5 * sin(anim_time * 3.2 + rect.position.x * 0.05)
	var c := rect.get_center()
	draw_circle(c, rect.size.x * 0.42, Color(0.55, 0.25, 1.0, (0.10 + 0.10 * pulse) * strength))
	draw_circle(c, rect.size.x * 0.26, Color(0.75, 0.45, 1.0, (0.08 + 0.08 * pulse) * strength))

func book_screen_center() -> Vector2:
	if engine == null: return get_global_rect().get_center()
	var goal: Array = engine.level.goal[room]
	return global_position + (Vector2(goal[0],goal[1]) + Vector2(0.5,0.5)) * tile_size

func _draw() -> void:
	if engine == null or art == null or state.is_empty(): return
	var map: Array = engine.level.maps[room]
	for y in range(map.size()):
		for x in range(map[y].length()):
			var rect := Rect2(Vector2(x,y)*tile_size,Vector2.ONE*tile_size)
			var t: String = map[y][x]
			# Walls stay empty space: no floor and no obstacle art.
			if t == "#": continue
			var alt_floor: Texture2D = art.get("floor_alt_texture")
			texture_at(alt_floor if alt_floor != null and (x+y)%2 == 1 else art.floor_texture,rect)
			var cubed: bool = engine.coord([x,y]) in state.trees
			var sealed := room == 1 and t == "W" and cubed
			match t:
				"I": texture_at(art.ice_texture,rect)
				"H": texture_at(art.hole_texture,rect)
				"W":
					# An open crack shimmers; a cube left there in the past seals it shut.
					if not sealed:
						_draw_rift_glow(rect, 1.0)
						texture_at(art.river_texture,rect)
				"D": texture_at(art.door_open_texture if engine.door_open(state,room,x,y) else art.door_closed_texture,rect.grow(-tile_size*0.06))
				"P":
					var pressed: bool = (state.p[room] == [x,y] and not state.dead[room]) or (room == 1 and cubed)
					texture_at(art.plate_down_texture if pressed else art.plate_up_texture,rect.grow(-tile_size*0.08))
			if engine.level.goal[room] == [x,y]: texture_at(art.book_texture,rect)
			if cubed:
				var progress := 1.0
				if room == 1 and growing.has(engine.coord([x,y])):
					progress = clampf(float(growing[engine.coord([x,y])]),0.0,1.0)
					_draw_rift_glow(rect, 1.0 - progress)
				var scale := lerpf(0.08,1.0,sin(progress * PI * 0.5))
				if room == 0: scale *= 0.62
				var cube_rect := Rect2(rect.get_center()-rect.size*scale*0.5,rect.size*scale)
				texture_at(art.seed_texture if room == 0 else (art.lily_texture if sealed else art.tree_texture),cube_rect)
			if t in ["D","P"]:
				draw_string(ThemeDB.fallback_font,rect.position+Vector2(tile_size-15,14),engine.pair(room,x,y),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("fff0c5"))
	var player_tile := Rect2(display_position*tile_size,Vector2.ONE*tile_size)
	var lift := -sin(clampf(move_elapsed / maxf(move_duration,0.01),0.0,1.0)*PI)*tile_size*0.12 if moving and not sliding else 0.0
	var bounce := sin(clampf(bump_elapsed/0.18,0.0,1.0)*PI*2.0)*tile_size*0.10 if bump_elapsed < 0.18 else 0.0
	player_tile.position.y += lift
	player_tile.position.x += bounce
	var tint := Color(1,1,1,0.25) if state.dead[room] else Color.WHITE
	# Both characters are chess-piece sprites that fit inside their tile.
	texture_standing(_player_frame(),player_tile.grow(-tile_size*0.04),tint)
	if flash_elapsed < FLASH_DURATION and flash_cell.x >= 0 and flash_cell.y >= 0:
		# Two soft red pulses around the highlighted tile.
		var pulse := absf(sin(flash_elapsed / (FLASH_DURATION * 0.5) * PI))
		var flash_rect := Rect2(Vector2(flash_cell) * tile_size, Vector2.ONE * tile_size).grow(-tile_size * 0.04)
		draw_rect(flash_rect, Color(1.0, 0.18, 0.22, 0.10 + 0.22 * pulse), true)
		draw_rect(flash_rect, Color(1.0, 0.28, 0.32, 0.35 + 0.55 * pulse), false, maxf(2.0, tile_size * 0.07))
