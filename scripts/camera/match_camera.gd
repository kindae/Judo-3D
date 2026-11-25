class_name MatchCamera
extends Camera3D
## Caméra à la troisième personne : derrière le joueur, cadre les deux combattants,
## ajuste sa distance, recentre l'action pendant les projections.

var player: Fighter
var opponent: Fighter
var focus_override: Node3D = null     # pendant une projection : uke
var _focus := Vector3.ZERO
var _yaw := 0.0
var _dist := 4.0
var _shake := 0.0
var _orbit := 0.0                      # rotation lente autour de l'action (ralentis, victoire)


func _ready() -> void:
	fov = 55.0
	near = 0.1
	far = 60.0


func snap() -> void:
	_update(1.0, true)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(dt: float) -> void:
	_update(dt, false)


func _update(dt: float, instant: bool) -> void:
	if player == null or opponent == null:
		return
	var a := player.global_position
	var b := opponent.global_position
	var mid := (a + b) * 0.5
	var sep := Vector2(a.x - b.x, a.z - b.z).length()
	var target_focus := mid + Vector3(0, 0.95, 0)
	var want_dist := clampf(3.2 + sep * 0.75, 3.4, 6.5)
	if focus_override:
		target_focus = focus_override.pelvis_world() if focus_override is Fighter else focus_override.global_position
		target_focus.y = clampf(target_focus.y, 0.5, 1.0)
		want_dist = 3.9
	# derrière le joueur, légèrement décalé sur le côté pour voir les deux judokas
	var dir := Vector3(b.x - a.x, 0, b.z - a.z)
	if dir.length() < 0.05:
		dir = player.forward()
	var want_yaw := atan2(dir.x, dir.z) + deg_to_rad(28.0) + _orbit
	var k := 1.0 if instant else clampf(dt * 3.0, 0.0, 1.0)
	_focus = _focus.lerp(target_focus, 1.0 if instant else clampf(dt * 5.0, 0.0, 1.0))
	_yaw = lerp_angle(_yaw, want_yaw, k * 0.8)
	_dist = lerpf(_dist, want_dist, k)
	var back := Vector3(sin(_yaw), 0, cos(_yaw))
	var pos := _focus - back * _dist + Vector3(0, 1.05 + _dist * 0.16, 0)
	# ne pas sortir de la salle
	pos.x = clampf(pos.x, -12.4, 12.4)
	pos.z = clampf(pos.z, -10.6, 10.6)
	if _shake > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.05
		_shake = maxf(0.0, _shake - dt * 3.0)
	global_position = pos
	look_at(_focus, Vector3.UP)
