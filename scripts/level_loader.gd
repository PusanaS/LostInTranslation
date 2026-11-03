extends RefCounted
## Accepts editor JSON v1/v2/v3 and legacy built-in rule fields.
const RULES = ["normal","double","triple","mirror","mirrorVertical","inverse","horizontal","vertical","slide","pulse","rotate"]

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

static func read(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {"error":"Không mở được file: " + path}
	if file.get_length() > 200000: return {"error":"JSON vượt quá 200 KB."}
	var json := JSON.new()
	var code := json.parse(file.get_as_text())
	if code != OK: return {"error":"JSON lỗi dòng %d: %s" % [json.get_error_line(),json.get_error_message()]}
	return validate(json.data)

static func validate(raw: Variant) -> Dictionary:
	if not raw is Dictionary: return {"error":"JSON phải chứa một level."}
	if raw.has("version") and (not integer(raw.version) or raw.version < 1 or raw.version > 3): return {"error":"Chỉ hỗ trợ JSON level phiên bản 1–3."}
	if raw.has("format") and raw.format != "lost-in-translation-level": return {"error":"Không phải JSON level của Lost in Translation."}
	if not raw.get("maps") is Array or raw.maps.size() != 2: return {"error":"Cần đúng hai map."}
	var limit: Variant = raw.get("seedLimit")
	if limit != null and (not integer(limit) or limit < 0 or limit > 999): return {"error":"seedLimit phải từ 0–999 hoặc null."}
	var legacy: String = str(raw.get("rule","normal"))
	var rules: Variant = raw.get("rules",["slide","normal"] if legacy == "slide" else ["normal",legacy])
	if not rules is Array or rules.size() != 2: return {"error":"Cần một quy luật cho mỗi map."}
	var circuits: Variant = raw.get("circuits",[{},{}])
	if not circuits is Array or circuits.size() != 2: return {"error":"circuits cần hai phòng."}
	var level := {"name":str(raw.get("name","Màn chưa đặt tên")).left(80),"maps":[],"start":[],"goal":[],"rules":rules.duplicate(),"seedLimit":null if limit == null else int(limit),"circuits":[{},{}]}
	# Preserve optional post-win tutorial / narrative block used by the translation screen.
	var translation: Variant = raw.get("translation")
	if translation is Dictionary:
		var title := str(translation.get("title","")).left(120)
		var body := str(translation.get("body","")).left(2000)
		var illustration := str(translation.get("illustration","")).left(32)
		if not body.is_empty():
			level["translation"] = {"title":title,"body":body,"illustration":illustration}
	for i in range(2):
		var map: Variant = raw.maps[i]
		if not map is Array or map.size() < 3 or map.size() > 30: return {"error":"Map phải dài 3–30 ô."}
		if not map[0] is String or map[0].length() < 3 or map[0].length() > 24: return {"error":"Map phải rộng 3–24 ô."}
		if not circuits[i] is Dictionary: return {"error":"Dữ liệu cặp cửa không hợp lệ."}
		var width: int = map[0].length()
		var used := {}
		for y in range(map.size()):
			if not map[y] is String or map[y].length() != width: return {"error":"Các hàng phải cùng chiều rộng."}
			for x in range(width):
				var t: String = map[y][x]
				if not t in [".","#","I","H","D","P","W"]: return {"error":"Tile không hợp lệ: " + t}
				if t in ["D","P"]:
					var key := "%d,%d" % [x,y]
					var id: Variant = circuits[i].get(key,"A")
					if not id is String or id.length() != 1 or not id in "ABCDEFGHIJKLMNOPQRSTUVWXYZ": return {"error":"Mã cặp cửa phải từ A–Z."}
					if used.has(t+id): return {"error":"Một cặp chỉ có 1 cửa và 1 cơ quan trong cùng phòng."}
					used[t+id] = true
					level.circuits[i][key] = id
		level.maps.append(map.duplicate())
		for type in ["start","goal"]:
			var points: Variant = raw.get(type)
			if not points is Array or points.size() != 2: return {"error":"Thiếu vị trí " + type}
			var p: Variant = points[i]
			if not p is Array or p.size() != 2 or not integer(p[0]) or not integer(p[1]): return {"error":"Tọa độ phải gồm hai số nguyên."}
			var x := int(p[0])
			var y := int(p[1])
			if x < 0 or x >= width or y < 0 or y >= map.size() or not map[y][x] in [".","I","P"]: return {"error":"Nhân vật/đích phải ở sàn, băng hoặc cơ quan."}
			level[type].append([x,y])
		if not rules[i] in RULES: return {"error":"Quy luật không được hỗ trợ: " + str(rules[i])}
	return {"level":level}
