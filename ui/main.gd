class_name MainUI
extends Control
## Root screen switcher: title -> team builder -> battle -> title.

var _current: Control = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameData.ensure_loaded()
	show_title()

func _swap(node: Control) -> void:
	if _current != null:
		_current.queue_free()
	_current = node
	add_child(node)

func show_title() -> void:
	var t := TitleScreen.new()
	t.start_team_builder.connect(show_team_builder)
	t.quick_battle.connect(func(): start_battle(TeamStore.default_team()))
	t.quit_game.connect(func(): get_tree().quit())
	_swap(t)

func show_team_builder() -> void:
	var tb := TeamBuilder.new()
	tb.battle_requested.connect(start_battle)
	tb.back_requested.connect(show_title)
	_swap(tb)

func start_battle(team: Array) -> void:
	var bs := BattleScreen.new()
	bs.player_team = team
	bs.back_to_title.connect(show_title)
	_swap(bs)
