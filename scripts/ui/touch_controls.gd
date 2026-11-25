class_name TouchControls
extends Control
## Commandes tactiles multi-touch : joystick à gauche, boutons d'action à droite.
## Fonctionne aussi à la souris (emulate_touch_from_mouse).

var controller: PlayerController
var match_node: Match

var _joy_center := Vector2.ZERO
var _joy_touch := -1
var _joy_vec := Vector2.ZERO
var _joy_radius := 90.0
var _buttons: Array[Dictionary] = []
var _held := {}         # index de doigt -> id du bouton
var pin_visible := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# id, libellé, position relative au coin bas-droit, rayon, couleur
	_buttons = [
		{"id": "throw", "label": "PROJETER", "off": Vector2(-120, -130), "r": 66.0, "col": Color(0.92, 0.3, 0.22)},
		{"id": "grip", "label": "SAISIR", "off": Vector2(-270, -95), "r": 54.0, "col": Color(0.96, 0.78, 0.25)},
		{"id": "defend", "label": "DÉFENSE", "off": Vector2(-215, -235), "r": 50.0, "col": Color(0.25, 0.6, 0.95)},
		{"id": "special", "label": "SPÉCIAL", "off": Vector2(-90, -285), "r": 46.0, "col": Color(0.62, 0.35, 0.9)},
		{"id": "pin", "label": "IMMOBILISER", "off": Vector2(-330, -235), "r": 56.0, "col": Color(0.2, 0.8, 0.45), "ctx": true},
	]


func _process(_d: float) -> void:
	pin_visible = match_node != null and match_node.can_pin(match_node.player)
	queue_redraw()


func _btn_pos(b: Dictionary) -> Vector2:
	return size + (b["off"] as Vector2)


func _joy_home() -> Vector2:
	return Vector2(170, size.y - 160)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			# boutons d'action
			for b in _buttons:
				if b.get("ctx", false) and not pin_visible:
					continue
				if e.position.distance_to(_btn_pos(b)) <= b["r"] + 12.0:
					_held[e.index] = b["id"]
					_press(b["id"])
					get_viewport().set_input_as_handled()
					return
			# joystick : moitié gauche de l'écran
			if e.position.x < size.x * 0.45 and e.position.y > size.y * 0.3 and _joy_touch < 0:
				_joy_touch = e.index
				_joy_center = e.position
				_joy_vec = Vector2.ZERO
				get_viewport().set_input_as_handled()
		else:
			if e.index == _joy_touch:
				_joy_touch = -1
				_joy_vec = Vector2.ZERO
				_send_joy()
			if _held.has(e.index):
				if _held[e.index] == "defend" and controller:
					controller.set_touch_defend(false)
				_held.erase(e.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_touch:
			var v := (d.position - _joy_center) / _joy_radius
			if v.length() > 1.0:
				# le socle suit le doigt
				_joy_center = d.position - v.normalized() * _joy_radius
				v = v.normalized()
			_joy_vec = v
			_send_joy()
			get_viewport().set_input_as_handled()


func _send_joy() -> void:
	if controller:
		controller.touch_move = Vector2(_joy_vec.x, -_joy_vec.y)


func _press(id: String) -> void:
	if controller == null:
		return
	if id == "defend":
		controller.set_touch_defend(true)
	else:
		controller.action(id)


func _draw() -> void:
	var font := get_theme_default_font()
	# joystick
	var c := _joy_center if _joy_touch >= 0 else _joy_home()
	draw_circle(c, _joy_radius, Color(1, 1, 1, 0.08))
	draw_arc(c, _joy_radius, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(c + _joy_vec * _joy_radius, 38, Color(1, 1, 1, 0.45 if _joy_touch >= 0 else 0.25))
	# boutons
	var held_ids := _held.values()
	for b in _buttons:
		if b.get("ctx", false) and not pin_visible:
			continue
		var p := _btn_pos(b)
		var r: float = b["r"]
		var col: Color = b["col"]
		var pressed: bool = b["id"] in held_ids
		draw_circle(p, r, Color(col, 0.85 if pressed else 0.55))
		draw_arc(p, r, 0, TAU, 48, Color(1, 1, 1, 0.75), 2.5, true)
		var fs := 15 if String(b["label"]).length() > 8 else 17
		var tw := font.get_string_size(b["label"], HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string_outline(font, p + Vector2(-tw / 2.0, fs * 0.35), b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
		draw_string(font, p + Vector2(-tw / 2.0, fs * 0.35), b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
