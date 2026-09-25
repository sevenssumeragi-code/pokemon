class_name HPBar
extends Control
## Animated HP bar with color thresholds.

var max_hp: int = 100
var hp: float = 100.0
var target_hp: int = 100
var speed: float = 120.0  # hp per second
var show_numbers: bool = true
signal animation_done

func _ready() -> void:
	custom_minimum_size = Vector2(180, 14)

func set_hp(new_max: int, new_hp: int, instant: bool = false) -> void:
	max_hp = maxi(1, new_max)
	target_hp = clampi(new_hp, 0, max_hp)
	if instant:
		hp = target_hp
	queue_redraw()

func is_animating() -> bool:
	return absf(hp - target_hp) > 0.01

func _process(delta: float) -> void:
	if is_animating():
		var step := speed * delta * maxf(1.0, max_hp / 200.0)
		if hp > target_hp:
			hp = maxf(target_hp, hp - step)
		else:
			hp = minf(target_hp, hp + step)
		queue_redraw()
		if not is_animating():
			animation_done.emit()

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.15, 0.15, 0.15))
	var frac := clampf(hp / float(max_hp), 0.0, 1.0)
	var col := Color(0.3, 0.85, 0.3)
	if frac <= 0.2:
		col = Color(0.9, 0.2, 0.2)
	elif frac <= 0.5:
		col = Color(0.95, 0.75, 0.2)
	draw_rect(Rect2(2, 2, (w - 4) * frac, h - 4), col)
	if show_numbers:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(w + 6, h - 1), "%d / %d" % [int(round(hp)), max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
