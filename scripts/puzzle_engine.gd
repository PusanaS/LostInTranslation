extends RefCounted
## Pure deterministic rules. Positions stay as [x,y] arrays for JSON parity.
const DIRS = [[0,-1],[1,0],[0,1],[-1,0]]
var level: Dictionary

func _init(data: Dictionary = {}) -> void:
	level = data.duplicate(true)

func initial() -> Dictionary:
	return {"p":level.start.duplicate(true), "trees":[], "phase":0, "dead":[false,false]}

func coord(p: Array) -> String:
	return "%d,%d" % [p[0],p[1]]

func tile(i: int, x: int, y: int) -> String:
	if y < 0 or y >= level.maps[i].size() or x < 0 or x >= level.maps[i][y].length():
		return ""
	return level.maps[i][y][x]

func floor_tile(i: int, x: int, y: int) -> bool:
	return tile(i,x,y) in [".","I","H","D","P","W"]

func pair(i: int, x: int, y: int) -> String:
	return level.get("circuits",[{},{}])[i].get(coord([x,y]),"A")

func lost(s: Dictionary) -> bool:
	return s.get("dead",[false,false]).has(true)

func won(s: Dictionary) -> bool:
	return not lost(s) and s.p == level.goal

func seed_limit() -> int:
	return -1 if level.get("seedLimit") == null else int(level.seedLimit)

func remaining(s: Dictionary) -> int:
	return -1 if seed_limit() < 0 else maxi(0,seed_limit()-s.trees.size())

func door_open(s: Dictionary, i: int, x: int, y: int) -> bool:
	var id := pair(i,x,y)
	for py in range(level.maps[i].size()):
		for px in range(level.maps[i][py].length()):
			if tile(i,px,py) == "P" and pair(i,px,py) == id:
				if (s.p[i] == [px,py] and not s.get("dead",[false,false])[i]) or (i == 1 and coord([px,py]) in s.trees):
					return true
	return false

func passable(s: Dictionary, i: int, x: int, y: int) -> bool:
	var t := tile(i,x,y)
	var planted: bool = coord([x,y]) in s.trees
	return floor_tile(i,x,y) and (t != "D" or door_open(s,i,x,y)) and not (i == 1 and t != "W" and planted)

func plant_reason(s: Dictionary) -> String:
	if lost(s): return "Đã rơi xuống hố. Nhấn Z hoặc R."
	var p: Array = s.p[0]
	var k := coord(p)
	var t := tile(1,p[0],p[1])
	if k in s.trees:
		return "Đưa nhân vật phải rời bèo trước khi thu hồi hạt." if t == "W" and s.p[1] == p else ""
	if remaining(s) == 0: return "Đã hết hạt. Nhặt lại hạt để dùng ở nơi khác."
	if t == "D": return "Không thể mọc cây trên cửa, kể cả cửa mở."
	if t == "H": return "Không thể mọc cây trên hố đen."
	if not floor_tile(1,p[0],p[1]): return "Ô tương ứng bên phải là tường hoặc ngoài map."
	if s.p[1] == p: return "Nhân vật phải đang đứng ở vị trí cây sẽ mọc."
	if level.goal[1] == p: return "Không thể mọc cây trên đích bên phải."
	return ""

func advance(s: Dictionary, action: int) -> Dictionary:
	if lost(s) or action < 0 or action > 4: return s
	if action == 4:
		if not plant_reason(s).is_empty(): return s
		var planted := s.duplicate(true)
		var k := coord(s.p[0])
		if k in planted.trees: planted.trees.erase(k)
		else: planted.trees.append(k)
		planted.trees.sort()
		return planted
	var legacy: String = level.get("rule","normal")
	var rules: Array = level.get("rules",["slide","normal"] if legacy == "slide" else ["normal",legacy])
	var result := s.duplicate(true)
	result.dead = [false,false]
	for i in range(2):
		var rule: String = rules[i]
		var d := action
		var stride := 1
		if rule == "rotate": d = (action+1)%4
		if rule == "double": stride = 2
		if rule == "triple": stride = 3
		if rule == "mirror" and action%2 == 1: d = (action+2)%4
		if rule == "mirrorVertical" and action%2 == 0: d = (action+2)%4
		if rule == "inverse": d = (action+2)%4
		if rule == "horizontal" and action%2 == 1: stride = 2
		if rule == "vertical" and action%2 == 0: stride = 2
		if rule == "pulse": stride = int(s.phase)+1
		if rule == "slide": stride = maxi(level.maps[i].size(),level.maps[i][0].length())
		var p: Array = s.p[i].duplicate()
		var on_ice := tile(i,p[0],p[1]) == "I"
		var step := 0
		while step < stride or on_ice:
			var next := [p[0]+DIRS[d][0],p[1]+DIRS[d][1]]
			var live := s.duplicate(true)
			live.p[i] = p.duplicate()
			if not passable(live,i,next[0],next[1]): break
			p = next
			var t := tile(i,p[0],p[1])
			if t == "H" or (t == "W" and not (i == 1 and coord(p) in s.trees)):
				result.dead[i] = true
				break
			if t == "I": on_ice = true
			elif on_ice:
				on_ice = false
				if rule != "slide": break
			step += 1
		result.p[i] = p
	if result.p == s.p: return s
	result.phase = 1-int(s.phase) if "pulse" in rules else 0
	return result
