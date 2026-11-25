class_name AIController
extends Node
## Adversaire contrôlé par l'ordinateur.
##
## Comportements : se déplacer, garder une distance adaptée, saisir, pousser/tirer
## pour déséquilibrer, projeter quand le joueur est déséquilibré, anticiper et
## défendre, gérer son endurance, immobiliser ou s'échapper au sol.

const PARAMS := {
	# temps de réaction, probabilité de défendre, seuil de déséquilibre pour attaquer,
	# agressivité, cadence d'échappement au sol (appuis/s), anticipation
	Settings.Difficulty.EASY: {"react": 0.55, "defend": 0.25, "throw_k": 0.55, "aggr": 0.35, "escape": 2.5, "anticip": 0.1, "push": 0.6},
	Settings.Difficulty.NORMAL: {"react": 0.32, "defend": 0.5, "throw_k": 0.42, "aggr": 0.6, "escape": 4.0, "anticip": 0.35, "push": 0.8},
	Settings.Difficulty.HARD: {"react": 0.18, "defend": 0.75, "throw_k": 0.32, "aggr": 0.85, "escape": 6.0, "anticip": 0.6, "push": 1.0},
}

var fighter: Fighter
var opponent: Fighter
var match_node: Node
var p: Dictionary
var passive := false            # entraînement : l'IA ne fait que se défendre

var _think := 0.0
var _plan := "approach"
var _plan_time := 0.0
var _circle := 1.0
var _pending_defend := -1.0     # instant où l'IA appuiera sur « défense »
var _escape_acc := 0.0
var _watched_attack := false


func setup(f: Fighter, opp: Fighter, m: Node, difficulty: int) -> void:
	fighter = f
	opponent = opp
	match_node = m
	p = PARAMS[difficulty]


func _process(dt: float) -> void:
	if fighter == null or match_node == null:
		return
	var phase: int = match_node.phase
	fighter.defending = false
	fighter.move_input = Vector2.ZERO
	_plan_time += dt
	_think -= dt

	# réaction aux attaques du joueur (fenêtre de défense)
	if match_node.is_attacking(opponent):
		if not _watched_attack:
			_watched_attack = true
			var anticipating: bool = fighter.kuzushi.length() > 0.3 and randf() < p["anticip"]
			if anticipating:
				_pending_defend = 0.05   # l'IA avait senti venir l'attaque
			elif randf() < p["defend"]:
				_pending_defend = p["react"] * randf_range(0.8, 1.25)
			else:
				_pending_defend = -1.0
		if _pending_defend >= 0.0:
			_pending_defend -= dt
			if _pending_defend < 0.0:
				match_node.on_action(fighter, "defend")
				_pending_defend = -1.0
			fighter.defending = _pending_defend < 0.0
		return
	_watched_attack = false

	match phase:
		Match.Phase.NEWAZA:
			if match_node.can_pin(fighter) and not passive and randf() < 0.9 * dt * 3.0:
				match_node.on_action(fighter, "pin")
			return
		Match.Phase.OSAEKOMI:
			if fighter.state == Fighter.S.PINNED:
				_escape_acc += dt * p["escape"] * randf_range(0.6, 1.3)
				while _escape_acc >= 1.0:
					_escape_acc -= 1.0
					match_node.on_action(fighter, "defend")
			return
		Match.Phase.FIGHT:
			pass
		_:
			return

	if fighter.state == Fighter.S.FREE:
		_free_play(dt)
	elif fighter.state == Fighter.S.GRIP:
		_grip_play(dt)


func _dir_to_opp() -> Vector2:
	var d := opponent.global_position - fighter.global_position
	return Vector2(d.x, d.z)


func _free_play(dt: float) -> void:
	var d := _dir_to_opp()
	var dist := d.length()
	var n := d.normalized()
	var tangent := Vector2(-n.y, n.x) * _circle
	# rester loin des bords
	var pos := fighter.flat_pos()
	var to_center := -pos.normalized() * clampf((pos.length() - 2.5) / 1.5, 0.0, 1.0)
	var tired := fighter.stamina < 28.0
	if _think <= 0.0:
		_think = randf_range(0.6, 1.4)
		if randf() < 0.3:
			_circle = -_circle
		if tired or passive:
			_plan = "keep"
		elif randf() < p["aggr"]:
			_plan = "approach"
		else:
			_plan = "keep"
	var want := Vector2.ZERO
	match _plan:
		"approach":
			want = n * 0.9 + tangent * 0.2
			if dist < 0.95 and fighter.stamina > 20.0:
				match_node.on_action(fighter, "grip")
		"keep":
			var ideal: float = 1.6 if tired else 1.15
			want = n * clampf((dist - ideal) * 2.0, -1.0, 1.0) + tangent * 0.45
	fighter.move_input = (want + to_center).limit_length(1.0)


func _grip_play(dt: float) -> void:
	var tired := fighter.stamina < 22.0
	# l'IA se défend si le joueur la déséquilibre
	if fighter.kuzushi.length() > 0.35 and randf() < p["anticip"] * 2.0:
		fighter.defending = true
	# casser la saisie quand elle est fatiguée ou dominée
	if opponent.has_grip and (tired or fighter.kuzushi.length() > 0.55) and _think <= 0.0:
		_think = 0.6
		match_node.on_action(fighter, "defend")
		return
	if passive:
		return
	if not fighter.has_grip:
		if _think <= 0.0:
			_think = 0.4
			match_node.on_action(fighter, "grip")
		return
	# exploiter le déséquilibre du joueur
	var k := opponent.kuzushi
	var back := -k.y
	if back > p["throw_k"] and fighter.tech_cooldown <= 0.0 and fighter.stamina > 20.0:
		match_node.on_action(fighter, "throw")
		return
	# construire le kuzushi : pousser le joueur vers l'arrière (pour O-soto-gari)
	var d := _dir_to_opp().normalized()
	if _think <= 0.0:
		_think = randf_range(0.5, 1.1)
		_plan = "push" if randf() < 0.75 else "pull"
	var want := d if _plan == "push" else -d * 0.6
	fighter.move_input = want * p["push"]
	# attaque opportuniste (moins efficace) de temps en temps
	if randf() < 0.05 * dt * p["aggr"] and fighter.stamina > 50.0:
		match_node.on_action(fighter, "throw")
