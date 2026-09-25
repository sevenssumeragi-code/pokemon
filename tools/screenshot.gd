extends SceneTree
## Capture screenshots of the UI screens (needs a display, e.g. xvfb-run).
## xvfb-run -s "-screen 0 960x540x24" godot --path . --rendering-driver opengl3 -s tools/screenshot.gd

var _step := 0
var _frames := 0
var _main: MainUI
var _bs: BattleScreen

func _initialize() -> void:
	GameData.ensure_loaded()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/screenshots"))
	_main = MainUI.new()
	root.add_child(_main)

func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://reports/screenshots/%s.png" % name)
	print("saved ", name)

func _process(_d: float) -> bool:
	_frames += 1
	match _step:
		0:
			if _frames > 10:
				_shot("01_title"); _step = 1; _frames = 0
				_main.show_team_builder()
		1:
			if _frames > 10:
				_shot("02_team_builder"); _step = 2; _frames = 0
				_main.start_battle(TeamStore.default_team())
				_bs = _main._current
				_bs.message_delay = 0.0
		2:
			if _frames > 30:
				_shot("03_battle_start"); _step = 3; _frames = 0
				_bs._show_moves()
		3:
			if _frames > 5:
				_shot("04_battle_moves"); _step = 4; _frames = 0
				_bs._choose_move(0)
		4:
			if _frames > 90:
				_shot("05_battle_after_turn"); _step = 5; _frames = 0
				_bs._show_switch(false)
		5:
			if _frames > 5:
				_shot("06_battle_switch")
				EffectRegistry.reset()
				quit(0)
				return true
	return false
