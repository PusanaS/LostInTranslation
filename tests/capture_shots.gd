extends SceneTree
## Renders a few key screens to user://shots/ for a quick visual check.
## Run (not headless): godot --path . --script res://tests/capture_shots.gd

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute("user://shots")
	root.get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % name)

func run() -> void:
	var game: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await create_timer(0.6).timeout
	for i in range(3): game.dialogue.advance(); game.dialogue.advance()
	await create_timer(1.2).timeout
	await shot("01_intro")
	game._select_level(1) # 02-level: has a crack on the child's side
	await create_timer(0.4).timeout
	game._act(0)
	await create_timer(0.5).timeout
	await shot("02_board")
	game._select_level(2) # 03-level: cracks on the player's side
	game._act(0); game._act(4)
	await create_timer(1.2).timeout
	await shot("03_sealed")
	game.dialogue.play("commander")
	for i in range(5): game.dialogue.advance(); game.dialogue.advance()
	await create_timer(1.5).timeout
	await shot("04_commander")
	game.dialogue.stop()
	game._select_level(0)
	game._show_translation()
	await create_timer(9.0).timeout
	await shot("05_book")
	game._continue_after_translation()
	await create_timer(1.0).timeout
	game._toggle_pause(); game._show_level_select()
	await shot("06_level_select")
	print("shots saved to ", ProjectSettings.globalize_path("user://shots"))
	quit()
