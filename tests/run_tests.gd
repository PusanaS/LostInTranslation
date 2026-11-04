extends SceneTree
const EngineScript = preload("res://scripts/puzzle_engine.gd")
const Loader = preload("res://scripts/level_loader.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		if failures <= 10: push_error(message)

func _initialize() -> void:
	call_deferred("run")

func normalize(value: Variant) -> Variant:
	# JSON parses every number as float; dictionary equality is type-sensitive.
	if value is float and value == floorf(value): return int(value)
	if value is Array:
		var result := []
		for item in value: result.append(normalize(item))
		return result
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = normalize(value[key])
		return result
	return value

func run() -> void:
	var data: Dictionary = normalize(JSON.parse_string(FileAccess.get_file_as_string("res://tests/web_parity.json")))
	var engines: Array = []
	for level in data.levels: engines.append(EngineScript.new(level))
	var count := 0
	for case in data.cases:
		var engine: RefCounted = engines[int(case.level)]
		var actual: Dictionary = engine.advance(case.state,int(case.action))
		check(actual == case.next,"Transition differs from web at case %d" % count)
		check(engine.plant_reason(case.state).is_empty() == case.canPlant,"Plant permission differs at %d" % count)
		check(engine.won(case.state) == case.won,"Win differs at %d" % count)
		check(engine.lost(case.state) == case.lost,"Death differs at %d" % count)
		check(engine.remaining(case.state) == case.remaining,"Inventory differs at %d" % count)
		count += 1
	for file in DirAccess.get_files_at("res://levels"):
		if file.ends_with(".json"): check(Loader.read("res://levels/"+file).has("level"),"Invalid sample "+file)
	var good: Dictionary = data.levels[0].duplicate(true)
	for version in [1,2,3]:
		good.version = version
		check(Loader.validate(good).has("level"),"Legacy version rejected")
	for bad in [null,[],{}, {"maps":[[],[]]}]: check(Loader.validate(bad).has("error"),"Malformed payload accepted")
	for limit in [-1,1.5,1000,"3"]:
		var bad := good.duplicate(true)
		bad.seedLimit = limit
		check(Loader.validate(bad).has("error"),"Invalid inventory accepted")
	# A river is entered, then kills the witch; it is not a blocking wall.
	var river_level := {"maps":[["#####","#.W.#","#####"],["#####","#.W.#","#####"]],"start":[[1,1],[1,1]],"goal":[[3,1],[3,1]],"rules":["normal","normal"],"seedLimit":1}
	var river_engine: RefCounted = EngineScript.new(river_level)
	var drowned: Dictionary = river_engine.advance(river_engine.initial(),1)
	check(drowned.p == [[2,1],[2,1]] and river_engine.lost(drowned),"River should be entered and kill both witches")
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game: Control = scene.instantiate()
	root.add_child(game)
	await process_frame
	# Do not assume the player has kept the bundled first level unchanged.
	# Add two isolated fixtures after their real library to test the win flow.
	for fixture in [data.levels[0],data.levels[1]]:
		game.library.append({"level":fixture,"path":""})
		game.picker.add_item(fixture.name)
	var fixture_index: int = game.library.size()-2
	game._select_level(fixture_index)
	check(game.state == game.engine.initial(),"UI initial state")
	check(game.seed_icon.texture != null and game.seed_hud.text == "1","Minimal seed HUD missing")
	game._toggle_pause()
	check(game.is_paused and game.pause_panel.visible,"Pause menu did not open")
	var paused_state: Dictionary = game.state.duplicate(true)
	game._act(1)
	check(game.state == paused_state,"Movement continued while paused")
	game._toggle_pause()
	game._act(4)
	check(game.boards[1].growing.size() == 1,"Tree growth animation did not start")
	game._act(1)
	check(game.engine.won(game.state),"UI micro tutorial Space Right")
	check(game.is_transitioning,"Winning did not begin the book transition")
	await create_timer(1.0).timeout
	check(game.is_translating and game.translation_panel.visible,"Winning did not open the translation book")
	check(not game.translation_next.visible,"Translation button appeared before the text animation")
	# Reveal length scales with the page text (up to ~9.5 s), so wait for it rather than a fixed delay.
	var waited := 0.0
	while not game.translation_next.visible and waited < 12.0:
		await create_timer(0.25).timeout
		waited += 0.25
	check(game.translation_next.visible,"Translation did not finish revealing its page")
	game._continue_after_translation()
	await create_timer(1.0).timeout
	check(not game.is_transitioning,"Book transition did not finish after turning the page")
	check(game.picker.selected == fixture_index+1,"Winning did not automatically select the next level")
	check(game.engine.level.name == data.levels[1].name,"Next level did not load")
	game._undo()
	check(game.state == game.engine.initial(),"Undo changed a fresh next level")
	game._reset()
	check(game.history.is_empty() and game.state.trees.is_empty(),"UI reset")
	var old_state: Dictionary = game.state.duplicate(true)
	game._import_file("res://missing.json")
	check(game.state == old_state,"Invalid file changed current game")
	game._import_file("res://levels/03-level.json")
	check(game.engine.level.name == Loader.read("res://levels/03-level.json").level.name,"Actual JSON import failed")
	# Story data must load and point every trigger at a real scene.
	check(not game.dialogue.story.is_empty(),"Story dialogue failed to load")
	for trigger in game.dialogue.story.get("triggers",{}):
		check(game.dialogue.story.scenes.has(game.dialogue.scene_for(trigger)),"Story trigger points at a missing scene: "+trigger)
	check(game.dialogue.play("commander") and game.dialogue.is_playing(),"Commander scene did not start")
	var before_dialogue: Dictionary = game.state.duplicate(true)
	game._act(1)
	check(game.state == before_dialogue,"Movement continued during dialogue")
	game.dialogue.stop()
	var saved_path: String = game.library[-1].path
	check(Loader.read(saved_path).has("level"),"Imported level did not persist")
	DirAccess.remove_absolute(saved_path)
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	key.echo = true
	old_state = game.state.duplicate(true)
	game._unhandled_key_input(key)
	check(game.state == old_state,"Held key repeated")
	game.queue_free()
	await process_frame
	print("Godot: %d reference cases + loader and UI checks; %d failures." % [count,failures])
	quit(0 if failures == 0 else 1)
