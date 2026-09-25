class_name DialogBox
extends Control
## Bottom message window with optional choices. Emits confirmed / chosen(index).

signal confirmed
signal chosen(index: int)

var _label: RichTextLabel
var _choices: VBoxContainer
var _panel: PanelContainer
var _buttons: Array = []
var awaiting_choice: bool = false

func _ready() -> void:
	UITheme.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = UITheme.make_panel()
	_panel.anchor_left = 0.03
	_panel.anchor_right = 0.97
	_panel.anchor_top = 0.72
	_panel.anchor_bottom = 0.97
	add_child(_panel)
	var vb := VBoxContainer.new()
	_panel.add_child(vb)
	_label = RichTextLabel.new()
	_label.add_theme_font_size_override("normal_font_size", 19)
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.custom_minimum_size = Vector2(0, 70)
	vb.add_child(_label)
	_choices = VBoxContainer.new()
	_choices.anchor_left = 0.6
	_choices.anchor_right = 0.97
	_choices.anchor_top = 0.35
	_choices.anchor_bottom = 0.70
	add_child(_choices)
	visible = false

func show_message(text: String) -> void:
	visible = true
	awaiting_choice = false
	_clear_choices()
	_label.text = text + "\n[color=gray]▼[/color]"

func show_choice(text: String, options: Array) -> void:
	visible = true
	awaiting_choice = true
	_label.text = text
	_clear_choices()
	for i in range(options.size()):
		var b := UITheme.make_button(str(options[i]), 17, Vector2(220, 40))
		var idx := i
		b.pressed.connect(func(): _pick(idx))
		_choices.add_child(b)
		_buttons.append(b)
	if not _buttons.is_empty():
		_buttons[0].grab_focus()

func hide_box() -> void:
	visible = false
	_clear_choices()

func _clear_choices() -> void:
	for b in _buttons:
		b.queue_free()
	_buttons.clear()

func _pick(i: int) -> void:
	awaiting_choice = false
	chosen.emit(i)

func _gui_input(event: InputEvent) -> void:
	if not visible or awaiting_choice:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and (event.keycode in [KEY_Z, KEY_ENTER, KEY_SPACE, KEY_X, KEY_ESCAPE])):
		accept_event()
		confirmed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or awaiting_choice:
		return
	if event is InputEventKey and event.pressed and (event.keycode in [KEY_Z, KEY_ENTER, KEY_SPACE, KEY_X, KEY_ESCAPE]):
		get_viewport().set_input_as_handled()
		confirmed.emit()
