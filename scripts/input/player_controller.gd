class_name PlayerController
extends Node
## Lit le clavier (ZQSD/WASD/flèches + J K L I U) et les commandes tactiles,
## et transmet les intentions au combattant du joueur.

var fighter: Fighter
var match_node: Node
var camera: Camera3D
var touch_move := Vector2.ZERO        # rempli par le joystick tactile (x droite, y haut)
var _touch_defend_held := false


func _process(_dt: float) -> void:
	if fighter == null:
		return
	var v := Input.get_vector("move_left", "move_right", "move_down", "move_up")
	if touch_move.length() > v.length():
		v = touch_move
	# directions relatives à la caméra
	var fwd := Vector3.FORWARD
	if camera:
		fwd = -camera.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var w := right * v.x + fwd * v.y
	fighter.move_input = Vector2(w.x, w.z)
	fighter.defending = Input.is_action_pressed("defend") or _touch_defend_held


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	for a in ["grip", "throw", "defend", "special", "pin"]:
		if event.is_action_pressed(a):
			action(a)


func action(a: String) -> void:
	if match_node:
		match_node.on_action(fighter, a)


func set_touch_defend(held: bool) -> void:
	_touch_defend_held = held
	if held:
		action("defend")
