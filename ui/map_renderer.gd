class_name MapRenderer
extends Node2D
## Draws a MapData grid with flat colored tiles plus simple entity markers; Camera2D follows the player.

const TILE := 32
var map: MapData
var state: GameState
var player_pos: Vector2 = Vector2.ZERO  # in pixels (interpolated)
var player_dir: String = "down"
var camera: Camera2D

func _ready() -> void:
	camera = Camera2D.new()
	camera.enabled = true
	add_child(camera)
	camera.make_current()

func set_map(m: MapData) -> void:
	map = m
	queue_redraw()

func _process(_d: float) -> void:
	if camera != null and map != null:
		var half := get_viewport_rect().size / 2.0
		var target := player_pos + Vector2(TILE / 2.0, TILE / 2.0)
		var mw := map.width * TILE
		var mh := map.height * TILE
		var cx := clampf(target.x, half.x, maxf(half.x, mw - half.x)) if mw > half.x * 2 else mw / 2.0
		var cy := clampf(target.y, half.y, maxf(half.y, mh - half.y)) if mh > half.y * 2 else mh / 2.0
		camera.position = Vector2(cx, cy)
	queue_redraw()

func _draw() -> void:
	if map == null:
		return
	draw_rect(Rect2(-2000, -2000, map.width * TILE + 4000, map.height * TILE + 4000), Color(0.05, 0.05, 0.08))
	for y in range(map.height):
		for x in range(map.width):
			var d := map.tile_def(x, y)
			var col := Color(str(d.get("color", "#ff00ff")))
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			draw_rect(r, col)
			match str(d.get("name", "")):
				"tall_grass":
					for i in range(3):
						draw_line(r.position + Vector2(6 + i * 9, 26), r.position + Vector2(9 + i * 9, 10), col.darkened(0.35), 2.0)
				"tree":
					draw_circle(r.get_center(), 13, col.lightened(0.15))
				"water":
					draw_line(r.position + Vector2(4, 12), r.position + Vector2(14, 12), col.lightened(0.3), 2.0)
					draw_line(r.position + Vector2(16, 22), r.position + Vector2(28, 22), col.lightened(0.3), 2.0)
				"door":
					draw_rect(Rect2(r.position + Vector2(8, 4), Vector2(16, 26)), col.darkened(0.4))
				"rock":
					draw_circle(r.get_center(), 11, col.lightened(0.2))
				"sign":
					draw_rect(Rect2(r.position + Vector2(6, 8), Vector2(20, 12)), col.darkened(0.3))
				"flower":
					draw_circle(r.get_center(), 5, Color(1, 0.9, 0.3))
				"stairs":
					for i in range(4):
						draw_line(r.position + Vector2(4, 6 + i * 7), r.position + Vector2(28, 6 + i * 7), col.lightened(0.4), 2.0)
				"table":
					draw_rect(Rect2(r.position + Vector2(3, 6), Vector2(26, 18)), col.lightened(0.2))
				"fence":
					draw_line(r.position + Vector2(0, 16), r.position + Vector2(32, 16), col.darkened(0.4), 4.0)
	# npcs
	for n in map.visible_npcs(state):
		var p := Vector2(int(n["x"]) * TILE, int(n["y"]) * TILE)
		_draw_person(p, _npc_color(str(n.get("sprite", ""))), str(n.get("dir", "down")))
	# player
	_draw_person(player_pos, Color(0.95, 0.3, 0.3), player_dir)

func _npc_color(sprite: String) -> Color:
	match sprite:
		"npc_prof": return Color(0.9, 0.9, 0.95)
		"npc_mom": return Color(0.95, 0.6, 0.8)
		"npc_nurse": return Color(0.95, 0.8, 0.85)
		"npc_clerk": return Color(0.4, 0.6, 0.95)
		"npc_trainer": return Color(0.3, 0.5, 0.9)
		"npc_boss": return Color(0.55, 0.2, 0.7)
		"npc_kid": return Color(0.95, 0.8, 0.3)
		"npc_old": return Color(0.6, 0.6, 0.6)
	return Color(0.8, 0.8, 0.8)

func _draw_person(p: Vector2, col: Color, dir: String) -> void:
	draw_circle(p + Vector2(16, 22), 9, col.darkened(0.2))  # body
	draw_circle(p + Vector2(16, 11), 7, col)  # head
	var eye := Vector2(16, 11)
	match dir:
		"up": eye += Vector2(0, -3)
		"down": eye += Vector2(0, 3)
		"left": eye += Vector2(-4, 0)
		"right": eye += Vector2(4, 0)
	draw_circle(p + eye, 2, Color.BLACK)
