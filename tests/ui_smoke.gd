extends SceneTree
## Headless UI smoke test: instantiate the battle screen in auto-play mode and run to completion.
## godot --headless --path . -s tests/ui_smoke.gd

var _bs: BattleScreen
var _frames := 0
var _done := false
var _title_checked := false

func _initialize() -> void:
	GameData.ensure_loaded()
	# title + team builder instantiate without errors
	var main := MainUI.new()
	root.add_child(main)
	main.show_team_builder()
	main.queue_free()
	_bs = BattleScreen.new()
	_bs.auto_play = true
	_bs.format = "doubles" if OS.get_environment("UI_SMOKE_DOUBLES") == "1" else "singles"
	_bs.seed_value = 12345
	_bs.player_team = TeamStore.default_team()
	_bs.battle_finished.connect(func(w): _done = true; print("battle finished, winner=", w, " turns=", _bs.battle.turn))
	root.add_child(_bs)

func _process(_delta: float) -> bool:
	_frames += 1
	if _done or _frames > 20000:
		print("frames=", _frames, " log_lines=", _bs.battle.log.size(), " done=", _done)
		if not _done:
			print("UI_SMOKE_FAIL: battle did not finish")
		else:
			print("UI_SMOKE_OK")
		EffectRegistry.reset()
		quit(0 if _done else 1)
		return true
	return false
