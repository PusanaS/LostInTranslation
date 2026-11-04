extends Resource
## Open art/game_art.tres in the Inspector to assign your PNG/SVG textures.
@export_group("Tiles")
@export var floor_texture: Texture2D = preload("res://assets/handmade/tiles/floor_a.png")
@export var floor_alt_texture: Texture2D = preload("res://assets/handmade/tiles/floor_b.png")
@export var wall_texture: Texture2D = preload("res://assets/handmade/tiles/wall_rock.png")
@export var ice_texture: Texture2D = preload("res://assets/handmade/tiles/ice.png")
@export var hole_texture: Texture2D = preload("res://assets/tiles/hole.svg")
## "W" tiles: an open dimension crack. Walking in without a cube sealing it loses the level.
@export var river_texture: Texture2D = preload("res://assets/handmade/tiles/rift_crack.png")
@export var door_closed_texture: Texture2D = preload("res://assets/handmade/tiles/door_closed.png")
@export var door_open_texture: Texture2D = preload("res://assets/handmade/tiles/door_open.png")
@export var plate_up_texture: Texture2D = preload("res://assets/handmade/tiles/plate_up.png")
@export var plate_down_texture: Texture2D = preload("res://assets/handmade/tiles/plate_down.png")
@export_group("Characters")
## Left room: the child East Witch, who casts the cubes.
@export var witch_past_texture: Texture2D = preload("res://assets/handmade/characters/witch_child.png")
## Right room: the player as a chess-piece sprite.
@export var witch_future_texture: Texture2D = preload("res://assets/handmade/characters/player_chibi.png")
## Optional animation frames. Left empty so the board shows the chess-piece sprite;
## the full-body idle/walk frames are kept in assets/handmade/characters/ if wanted later.
@export var player_idle_frames: Array[Texture2D] = []
@export var player_walk_frames: Array[Texture2D] = []
@export_group("Objects")
@export var book_texture: Texture2D = preload("res://assets/objects/book.svg")
## Left room: small cube the child witch places.
@export var seed_texture: Texture2D = preload("res://assets/handmade/objects/cube_small.png")
## Right room: the large cube that materialises at the same coordinates.
@export var tree_texture: Texture2D = preload("res://assets/handmade/objects/cube_large.png")
## Right room: a crack sealed by a cube — walkable.
@export var lily_texture: Texture2D = preload("res://assets/handmade/tiles/rift_sealed.png")
@export_group("Story")
@export var open_book_texture: Texture2D = preload("res://assets/handmade/ui/book_open.png")
@export var textbox_texture: Texture2D = preload("res://assets/handmade/ui/textbox.png")
@export var soldier_texture: Texture2D = preload("res://assets/handmade/characters/soldier.png")
@export var player_chibi_texture: Texture2D = preload("res://assets/handmade/characters/player_chibi.png")
