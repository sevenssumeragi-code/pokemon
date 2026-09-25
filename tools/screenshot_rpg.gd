extends SceneTree
## RPG screenshots: overworld, dialog, menu, party, wild battle. Run under xvfb-run like screenshot.gd.
var _step := 0
var _frames := 0
var _main: MainUI
var _ctrl: RPGController

func _initialize() -> void:
	GameData.ensure_loaded()
	GameState.slot_prefix = "shot_save"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/screenshots"))
	_main = MainUI.new()
	root.add_child(_main)

func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("res://reports/screenshots/%s.png" % name)
	print("saved ", name)

func _process(_d: float) -> bool:
	_frames += 1
	match _step:
		0:
			if _frames > 8:
				_main.start_new_game()
				_ctrl = _main._current
				_ctrl.move_duration = 0.0
				_step = 1; _frames = 0
		1:
			if _frames > 8:
				_shot("10_rpg_home_dialog")
				_ctrl.dialog_confirm(); _ctrl.dialog_confirm()
				_step = 2; _frames = 0
		2:
			if _frames > 5:
				_ctrl.state.set_flag("intro_done", true)
				_ctrl.load_map("town", 7, 7, "down")
				_ctrl.dialog_confirm()
				_step = 3; _frames = 0
		3:
			if _frames > 8:
				_shot("11_rpg_town")
				_ctrl.open_menu()
				_step = 4; _frames = 0
		4:
			if _frames > 5:
				_shot("12_rpg_menu")
				_ctrl.menu.closed.emit()
				_ctrl.state.set_flag("got_starter", true)
				var rng := RandomNumberGenerator.new(); rng.seed = 3
				_ctrl.state.party.append(PokemonSet.generate("renny", 12, rng))
				_ctrl.state.bag = {"monster_ball": 5, "potion": 3}
				_ctrl.load_map("field", 9, 1, "down")
				_step = 5; _frames = 0
		5:
			if _frames > 8:
				_shot("13_rpg_field")
				_ctrl.start_wild_battle("muni", 5)
				_step = 6; _frames = 0
		6:
			if _frames > 40:
				_shot("14_rpg_wild_battle")
				_ctrl.battle_screen._show_bag()
				_step = 7; _frames = 0
		7:
			if _frames > 5:
				_shot("15_rpg_battle_bag")
				var p := ProjectSettings.globalize_path(GameState.save_path(1))
				if FileAccess.file_exists(p):
					DirAccess.remove_absolute(p)
				EffectRegistry.reset()
				quit(0)
				return true
	return false
