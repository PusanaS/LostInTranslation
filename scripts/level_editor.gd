extends Control
## Godot counterpart to the browser Level Studio. It emits the same v3 JSON.
const Loader = preload("res://scripts/level_loader.gd")
const RULES = ["normal","double","triple","mirror","mirrorVertical","inverse","horizontal","vertical","slide","pulse"]
@export var art: Resource
var level: Dictionary
var brush := "wall"
var pair_id := "A"
var grids: Array[GridContainer] = []
var name_input: LineEdit
var seed_input: SpinBox
var pair_picker: OptionButton
var save_dialog: FileDialog
var open_dialog: FileDialog
var toast: Label
var rule_pickers: Array[OptionButton] = []
var width_inputs: Array[SpinBox] = []
var height_inputs: Array[SpinBox] = []

func _ready() -> void:
	level = _blank_level()
	_build_ui()
	_refresh()

func _blank_map(width := 9, height := 7) -> Array:
	var map: Array = []
	for y in range(height):
		var row := ""
		for x in range(width): row += "#" if x == 0 or y == 0 or x == width-1 or y == height-1 else "."
		map.append(row)
	return map

func _blank_level() -> Dictionary:
	return {"format":"lost-in-translation-level","version":3,"name":"New level","maps":[_blank_map(),_blank_map()],"start":[[1,5],[1,5]],"goal":[[7,1],[7,1]],"rules":["normal","normal"],"seedLimit":3,"circuits":[{},{}]}

func _label(text: String, size := 14) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",size)
	return node

func _button(text: String, callback: Callable, parent: Node) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 36
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,18)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation",10)
	margin.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
	var heading := _label("LEVEL STUDIO  /  GODOT",26)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_button("← Back to game",func(): get_tree().change_scene_to_file("res://scenes/main.tscn"),header)
	var project := HBoxContainer.new()
	project.add_theme_constant_override("separation",10)
	page.add_child(project)
	project.add_child(_label("LEVEL NAME"))
	name_input = LineEdit.new()
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.text_changed.connect(func(value: String): level.name = value.left(80))
	project.add_child(name_input)
	project.add_child(_label("SEEDS"))
	seed_input = SpinBox.new()
	seed_input.min_value = 0; seed_input.max_value = 999; seed_input.step = 1
	seed_input.value_changed.connect(func(value: float): level.seedLimit = int(value))
	project.add_child(seed_input)
	_button("Open JSON…",func(): open_dialog.popup_centered(Vector2i(850,560)),project)
	_button("Save JSON…",func(): save_dialog.popup_centered(Vector2i(850,560)),project)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation",7)
	page.add_child(tools)
	for entry in [["▧ Wall","wall"],["□ Floor","floor"],["● Witch","start"],["◇ Book","goal"],["❄ Ice","ice"],["▥ Door","door"],["▣ Plate","plate"],["≈ River","river"]]:
		var selected: String = str(entry[1])
		_button(entry[0],func(): brush = selected; _toast("Brush: "+selected.capitalize()),tools)
	tools.add_child(_label("PAIR"))
	pair_picker = OptionButton.new()
	for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ": pair_picker.add_item(letter)
	pair_picker.item_selected.connect(func(index: int): pair_id = pair_picker.get_item_text(index))
	tools.add_child(pair_picker)
	tools.add_child(_label("Rivers are lethal. A planted lily on the right map is safe."))
	var rooms := HBoxContainer.new()
	rooms.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rooms.add_theme_constant_override("separation",18)
	page.add_child(rooms)
	for room in range(2):
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rooms.add_child(column)
		column.add_child(_label("01 / PAST" if room == 0 else "02 / FUTURE",18))
		var settings := HBoxContainer.new()
		column.add_child(settings)
		settings.add_child(_label("W"))
		var width := SpinBox.new(); width.min_value=3; width.max_value=24; width.step=1; settings.add_child(width); width_inputs.append(width)
		settings.add_child(_label("H"))
		var height := SpinBox.new(); height.min_value=3; height.max_value=30; height.step=1; settings.add_child(height); height_inputs.append(height)
		_button("Resize",_resize_room.bind(room),settings)
		var rule := OptionButton.new()
		for item in RULES: rule.add_item(item)
		rule.item_selected.connect(_set_rule.bind(room,rule))
		settings.add_child(rule); rule_pickers.append(rule)
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(scroll)
		var grid := GridContainer.new()
		grid.add_theme_constant_override("h_separation",1)
		grid.add_theme_constant_override("v_separation",1)
		scroll.add_child(grid)
		grids.append(grid)
	var footer := HBoxContainer.new()
	page.add_child(footer)
	footer.add_child(_label("Click a tile to paint. Doors and plates with the same letter form one pair in each room. Existing JSON with black holes stays readable, but this editor cannot add new ones."))
	toast = _label("",15)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(toast)
	open_dialog = FileDialog.new()
	open_dialog.access = FileDialog.ACCESS_FILESYSTEM; open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.filters = PackedStringArray(["*.json ; Lost in Translation level"])
	open_dialog.file_selected.connect(_open_json)
	add_child(open_dialog)
	save_dialog = FileDialog.new()
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM; save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.filters = PackedStringArray(["*.json ; Lost in Translation level"])
	save_dialog.file_selected.connect(_save_json)
	add_child(save_dialog)

func _set_rule(room: int, picker: OptionButton, index: int) -> void:
	level.rules[room] = picker.get_item_text(index)

func _resize_room(room: int) -> void:
	var width := int(width_inputs[room].value)
	var height := int(height_inputs[room].value)
	var old: Array = level.maps[room]
	var map: Array = []
	for y in range(height):
		var row := ""
		for x in range(width): row += old[y][x] if y < old.size() and x < old[y].length() else "."
		map.append(row)
	level.maps[room] = map
	for kind in ["start","goal"]:
		level[kind][room][0] = mini(level[kind][room][0],width-1)
		level[kind][room][1] = mini(level[kind][room][1],height-1)
		_set_tile(room,level[kind][room][0],level[kind][room][1],".")
	_refresh()

func _replace_character(text: String, x: int, tile: String) -> String:
	return text.left(x)+tile+text.substr(x+1)

func _set_tile(room: int, x: int, y: int, tile: String) -> void:
	level.maps[room][y] = _replace_character(level.maps[room][y],x,tile)

func _paint(room: int, x: int, y: int) -> void:
	if brush == "start" or brush == "goal":
		level[brush][room] = [x,y]
		if level.maps[room][y][x] not in [".","I","P"]: _set_tile(room,x,y,".")
	else:
		var tile: String = str({"wall":"#","floor":".","ice":"I","door":"D","plate":"P","river":"W"}.get(brush,"."))
		if tile in ["#","W","D"] and (level.start[room] == [x,y] or level.goal[room] == [x,y]):
			_toast("Move the witch or book before painting this tile.")
			return
		if tile in ["D","P"]:
			for key in level.circuits[room].keys().duplicate():
				var old: PackedStringArray = key.split(",")
				if level.circuits[room][key] == pair_id and level.maps[room][int(old[1])][int(old[0])] == tile:
					_set_tile(room,int(old[0]),int(old[1]),".")
					level.circuits[room].erase(key)
			level.circuits[room]["%d,%d" % [x,y]] = pair_id
		else: level.circuits[room].erase("%d,%d" % [x,y])
		_set_tile(room,x,y,tile)
	_refresh()

func _tile_text(room: int, x: int, y: int) -> String:
	var t: String = level.maps[room][y][x]
	if level.start[room] == [x,y]: return "●"
	if level.goal[room] == [x,y]: return "◇"
	if t == "#": return "▧"
	if t == "I": return "❄"
	if t == "D": return "▥"+str(level.circuits[room].get("%d,%d" % [x,y],"A"))
	if t == "P": return "▣"+str(level.circuits[room].get("%d,%d" % [x,y],"A"))
	if t == "W": return "≈"
	if t == "H": return "◉"
	return ""

func _refresh() -> void:
	name_input.text = level.name
	seed_input.value = int(level.seedLimit) if level.seedLimit != null else 3
	for room in range(2):
		var grid := grids[room]
		grid.columns = level.maps[room][0].length()
		for child in grid.get_children(): child.queue_free()
		width_inputs[room].value = level.maps[room][0].length()
		height_inputs[room].value = level.maps[room].size()
		rule_pickers[room].select(maxi(0,RULES.find(level.rules[room])))
		for y in range(level.maps[room].size()):
			for x in range(level.maps[room][y].length()):
				var cell := Button.new()
				cell.text = _tile_text(room,x,y)
				cell.custom_minimum_size = Vector2(38,38)
				cell.tooltip_text = "(%d, %d)" % [x+1,y+1]
				cell.pressed.connect(_paint.bind(room,x,y))
				grid.add_child(cell)

func _open_json(path: String) -> void:
	var parsed := Loader.read(path)
	if parsed.has("error"): _toast("Could not open this level JSON."); return
	level = parsed.level.duplicate(true)
	_refresh()
	_toast("Level loaded.")

func _save_json(path: String) -> void:
	var parsed := Loader.validate(level)
	if parsed.has("error"): _toast("Fix this level before saving: "+parsed.error); return
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: _toast("Could not save this level."); return
	var saved: Dictionary = parsed.level.duplicate(true)
	saved.format = "lost-in-translation-level"; saved.version = 3
	file.store_string(JSON.stringify(saved,"\t")); file.close()
	level = saved
	_toast("Level saved as JSON.")

func _toast(text: String) -> void:
	toast.text = text
