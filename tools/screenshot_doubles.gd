extends SceneTree
var _step := 0
var _frames := 0
var _bs: BattleScreen
func _initialize() -> void:
	GameData.ensure_loaded()
	var m := MainUI.new()
	root.add_child(m)
	m.start_battle(TeamStore.default_team(), "doubles")
	_bs = m._current
	_bs.message_delay = 0.0
func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("res://reports/screenshots/%s.png" % name)
	print("saved ", name)
func _process(_d: float) -> bool:
	_frames += 1
	match _step:
		0:
			if _frames > 40:
				_shot("20_doubles_command"); _bs._show_moves(); _step = 1; _frames = 0
		1:
			if _frames > 5:
				_shot("21_doubles_moves"); _bs._choose_move(0); _step = 2; _frames = 0
		2:
			if _frames > 5:
				_shot("22_doubles_target")
				EffectRegistry.reset()
				quit(0)
				return true
	return false
