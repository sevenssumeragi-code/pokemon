class_name MainUI
extends Control
## Root screen switcher: title -> team builder -> battle -> title.

var _current: Control = null

func _ready() -> void:
	UITheme.fill_parent(self)
	GameData.ensure_loaded()
	get_tree().root.size_changed.connect(_on_resized)
	if _current == null:
		show_title()

func _on_resized() -> void:
	UITheme.fill_parent(self)
	if _current != null:
		UITheme.fill_parent(_current)

func _swap(node: Control) -> void:
	if _current != null:
		_current.queue_free()
	_current = node
	add_child(node)
	UITheme.fill_parent(node)

func show_title() -> void:
	var t := TitleScreen.new()
	t.start_team_builder.connect(show_team_builder)
	t.quick_battle.connect(func(): start_battle(TeamStore.default_team(), "singles"))
	t.new_game.connect(start_new_game)
	t.continue_game.connect(continue_game)
	t.quit_game.connect(func(): get_tree().quit())
	_swap(t)

func start_new_game() -> void:
	var g := GameState.new()
	g.map_id = "home"
	g.pos = Vector2i(4, 4)
	g.dir = "down"
	g.rng_seed = int(Time.get_unix_time_from_system()) % 1000000 + 1
	start_rpg(g)

func continue_game() -> void:
	var g := GameState.load_slot(1)
	if g == null:
		start_new_game()
		return
	start_rpg(g)

func start_rpg(g: GameState) -> void:
	GameState.current = g
	var c := RPGController.new()
	c.state = g
	c.request_title.connect(show_title)
	c.game_ended.connect(show_title)
	_swap(c)

func show_team_builder() -> void:
	var tb := TeamBuilder.new()
	tb.battle_requested.connect(start_battle)
	tb.back_requested.connect(show_title)
	_swap(tb)

func start_battle(team: Array, format: String = "singles") -> void:
	var bs := BattleScreen.new()
	bs.format = format
	bs.player_team = team
	bs.back_to_title.connect(show_title)
	_swap(bs)
