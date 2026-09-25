class_name TitleScreen
extends Control
## Title: たいせん (team builder -> battle), クイックバトル, おわる

signal start_team_builder
signal quick_battle
signal quit_game

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.anchor_left = 0.5
	vb.anchor_right = 0.5
	vb.anchor_top = 0.5
	vb.anchor_bottom = 0.5
	vb.offset_left = -160
	vb.offset_right = 160
	vb.offset_top = -160
	vb.offset_bottom = 160
	vb.add_theme_constant_override("separation", 14)
	add_child(vb)
	var title := UITheme.make_label("モンスターバトル", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := UITheme.make_label("第9世代準拠 対戦システム", 16, Color(0.7, 0.75, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	vb.add_child(Control.new())
	var b1 := UITheme.make_button("たいせん（チームを組む）", 20, Vector2(320, 48))
	b1.pressed.connect(func(): start_team_builder.emit())
	vb.add_child(b1)
	var b2 := UITheme.make_button("クイックバトル（おすすめチーム）", 20, Vector2(320, 48))
	b2.pressed.connect(func(): quick_battle.emit())
	vb.add_child(b2)
	var b3 := UITheme.make_button("おわる", 20, Vector2(320, 48))
	b3.pressed.connect(func(): quit_game.emit())
	vb.add_child(b3)
	b1.grab_focus()
