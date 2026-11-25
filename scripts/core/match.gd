class_name Match
extends Node3D
## Déroulement d'un combat : salut, hajime, saisies, projections synchronisées,
## ne-waza / osaekomi, sorties de tatami, chronomètre, golden score, fin du combat.

enum Phase { INTRO, FIGHT, THROW, NEWAZA, OSAEKOMI, MATE, END }

const GRIP_RANGE := 1.05
const MIN_DIST := 0.72
const NEWAZA_WINDOW := 3.0

var dojo: Dojo
var fighters: Array[Fighter] = []
var player: Fighter
var cpu: Fighter
var camera: MatchCamera
var pc: PlayerController
var ai: AIController
var hud: Node
var board := Scoreboard.new()
var training := false
var phase: int = Phase.INTRO
var phase_time := 0.0
var engaged := false
var throw_info := {}
var osae := {}
var _mate_reason := ""
var _mate_step := 0
var _slowmo_until := -1.0
var _clock := 0.0


func _ready() -> void:
	training = Game.mode == Game.Mode.TRAINING
	dojo = Dojo.new()
	dojo.name = "Dojo"
	add_child(dojo)
	var belt: Color = Settings.BELTS.get(Settings.belt_color, Color.BLACK)
	for s in 2:
		var f := Fighter.new()
		add_child(f)
		f.setup(s, "Vous" if s == 0 else "CPU · " + Settings.difficulty_name(), belt if s == 0 else Settings.BELTS["black"], s)
		fighters.append(f)
	player = fighters[0]
	cpu = fighters[1]
	player.opponent = cpu
	cpu.opponent = player
	camera = MatchCamera.new()
	camera.player = player
	camera.opponent = cpu
	add_child(camera)
	camera.current = true
	pc = PlayerController.new()
	pc.fighter = player
	pc.match_node = self
	pc.camera = camera
	add_child(pc)
	ai = AIController.new()
	ai.setup(cpu, player, self, Settings.difficulty)
	ai.passive = training
	add_child(ai)
	if training:
		player.infinite_stamina = true
	if Game.autoplay:
		pc.fighter = null
		var ai2 := AIController.new()
		ai2.setup(player, cpu, self, Settings.Difficulty.NORMAL)
		add_child(ai2)
	hud = preload("res://scripts/ui/hud.gd").new()
	hud.match_node = self
	add_child(hud)
	_place_at_start()
	camera.snap()
	_set_phase(Phase.INTRO)
	for f in fighters:
		f.restart("rei", 0.0)
	hud.announce("REI", 1.4)


func _place_at_start() -> void:
	for f in fighters:
		f.global_position = Dojo.start_position(f.side)
		f.face_towards(Dojo.start_position(1 - f.side), 0.0)
		f.set_state(Fighter.S.FREE)
		f.has_grip = false
		f.kuzushi = Vector2.ZERO
		f.face_lock = false
	engaged = false


func _set_phase(p: int) -> void:
	phase = p
	phase_time = 0.0


# ------------------------------------------------------------------ pause / navigation
func request_pause() -> void:
	if not get_tree().paused:
		toggle_pause()


func toggle_pause() -> void:
	if phase == Phase.END and not get_tree().paused:
		return
	get_tree().paused = not get_tree().paused
	Engine.time_scale = 1.0
	hud.show_pause(get_tree().paused)


func on_back() -> void:
	toggle_pause()


func restart() -> void:
	Game.start_match(Game.mode)


# ------------------------------------------------------------------ requêtes
func is_attacking(f: Fighter) -> bool:
	return phase == Phase.THROW and throw_info.get("tori") == f and throw_info.get("t", 0.0) < throw_info.get("window", 0.0)


func can_pin(f: Fighter) -> bool:
	return phase == Phase.NEWAZA and throw_info.get("tori") == f and phase_time < NEWAZA_WINDOW \
		and f.state in [Fighter.S.FREE, Fighter.S.ATTACK]


func distance() -> float:
	return player.flat_pos().distance_to(cpu.flat_pos())


func on_action(f: Fighter, a: String) -> void:
	var opp := f.opponent
	match a:
		"grip":
			if phase != Phase.FIGHT or not f.can_act() or f.has_grip:
				return
			if distance() > GRIP_RANGE:
				if f == player:
					hud.hint("Trop loin pour saisir : rapprochez-vous")
				return
			if not f.spend(4.0):
				return
			f.has_grip = true
			if not engaged:
				engaged = true
				for x in fighters:
					x.set_state(Fighter.S.GRIP)
			if f == player:
				hud.hint("Saisie ! Poussez (joystick vers l'adversaire) pour le déséquilibrer vers l'arrière")
		"defend":
			f.last_defend_press = _clock
			if phase == Phase.OSAEKOMI and f.state == Fighter.S.PINNED:
				_escape_press(f)
				return
			if phase == Phase.FIGHT and engaged and opp.has_grip and f.spend(5.0):
				# kumikata : tenter de casser la saisie adverse
				var chance := 0.45 + (f.stamina - opp.stamina) / 250.0
				if randf() < chance:
					opp.has_grip = false
					if f == player:
						hud.hint("Saisie adverse cassée")
					if not f.has_grip:
						_disengage()
		"throw", "special":
			if phase != Phase.FIGHT or f.state != Fighter.S.GRIP or not f.has_grip or f.tech_cooldown > 0.0:
				if f == player and phase == Phase.FIGHT and not f.has_grip:
					hud.hint("Saisissez d'abord l'adversaire")
				return
			var tech := Technique.by_id("o_soto_gari")
			var cost := tech.stamina_cost * (1.6 if a == "special" else 1.0)
			if not f.spend(cost):
				if f == player:
					hud.hint("Pas assez d'endurance")
				return
			_start_throw(f, tech, a == "special")
		"pin":
			if can_pin(f) and f.spend(Technique.by_id("kesa_gatame").stamina_cost):
				_start_osaekomi(f)


func _disengage() -> void:
	engaged = false
	for x in fighters:
		x.has_grip = false
		if x.state == Fighter.S.GRIP:
			x.set_state(Fighter.S.FREE)
	# léger écartement
	var d := (cpu.global_position - player.global_position)
	d.y = 0
	var n := d.normalized()
	player.global_position -= n * 0.12
	cpu.global_position += n * 0.12


# ------------------------------------------------------------------ boucle principale
func _process(dt: float) -> void:
	_clock += dt
	phase_time += dt
	if _slowmo_until > 0.0 and _clock > _slowmo_until:
		Engine.time_scale = 1.0
		_slowmo_until = -1.0
	match phase:
		Phase.INTRO:
			if phase_time > 2.7:
				_hajime()
		Phase.FIGHT:
			_tick_clock(dt)
			_fight(dt)
		Phase.THROW:
			_throw(dt)
		Phase.NEWAZA:
			_tick_clock(dt)
			if phase_time > NEWAZA_WINDOW:
				_mate("")
		Phase.OSAEKOMI:
			_tick_clock(dt)
			_osaekomi(dt)
		Phase.MATE:
			_mate_tick()
		Phase.END:
			pass
	hud.refresh()


func _tick_clock(dt: float) -> void:
	if training:
		return
	if board.golden_score:
		board.golden_time += dt
		return
	board.time_left = maxf(0.0, board.time_left - dt)
	# à la fin du temps, une immobilisation en cours continue (règle FIJ)
	if board.time_left <= 0.0 and phase in [Phase.FIGHT, Phase.NEWAZA]:
		if board.on_time_up():
			hud.announce("SORE-MADE · GOLDEN SCORE", 2.0)
			_mate("golden")
		else:
			_end_match()


func _hajime() -> void:
	_set_phase(Phase.FIGHT)
	for f in fighters:
		f.set_state(Fighter.S.FREE)
		f.play("guard", 0.3)
	hud.announce("HAJIME !", 1.0)


func _fight(dt: float) -> void:
	var a := player
	var b := cpu
	if engaged:
		# les deux judokas se déplacent ensemble ; le plus engagé entraîne l'autre
		var da := a.update_locomotion(dt, b.global_position)
		var db := b.update_locomotion(dt, a.global_position)
		var pair := (da + db) * 0.5
		a.global_position += pair
		b.global_position += pair
		_apply_kuzushi(a, b, dt)
		_apply_kuzushi(b, a, dt)
		# maintien de la distance de saisie
		var mid := (a.global_position + b.global_position) * 0.5
		var n := (b.global_position - a.global_position)
		n.y = 0
		n = n.normalized()
		a.global_position = a.global_position.lerp(mid - n * JudoAnims.GRIP_DIST * 0.5, clampf(dt * 6.0, 0, 1))
		b.global_position = b.global_position.lerp(mid + n * JudoAnims.GRIP_DIST * 0.5, clampf(dt * 6.0, 0, 1))
		if not a.has_grip and not b.has_grip:
			_disengage()
	else:
		a.global_position += a.update_locomotion(dt, b.global_position)
		b.global_position += b.update_locomotion(dt, a.global_position)
		var d := b.global_position - a.global_position
		d.y = 0
		if d.length() < MIN_DIST:
			var push := d.normalized() * (MIN_DIST - d.length()) * 0.5
			a.global_position -= push
			b.global_position += push
	for f in fighters:
		f.global_position.y = Dojo.TATAMI_H
	# sortie de l'aire de combat
	if not training:
		for f in fighters:
			var p := f.flat_pos()
			if absf(p.x) > Dojo.CONTEST_HALF + 0.15 or absf(p.y) > Dojo.CONTEST_HALF + 0.15:
				var msg := board.add_shido(f.side)
				hud.announce("MATE · %s (sortie)" % msg, 1.6)
				if board.is_over():
					_end_match()
				else:
					_mate("")
				return
	else:
		for f in fighters:
			var p := f.global_position
			p.x = clampf(p.x, -Dojo.CONTEST_HALF - 1.5, Dojo.CONTEST_HALF + 1.5)
			p.z = clampf(p.z, -Dojo.CONTEST_HALF - 1.5, Dojo.CONTEST_HALF + 1.5)
			f.global_position = p


## tori pousse/tire : modifie le déséquilibre d'uke (repère d'uke).
func _apply_kuzushi(tori: Fighter, uke: Fighter, dt: float) -> void:
	if not tori.has_grip:
		return
	var mv := tori.move_input.limit_length(1.0)
	if mv.length() < 0.15:
		return
	var w := Vector3(mv.x, 0, mv.y)
	var fwd := uke.forward()
	var left := Vector3.UP.cross(fwd).normalized()
	var effect := Vector2(w.dot(left), w.dot(fwd))
	# résistance d'uke : marcher contre la poussée ou se mettre en défense
	var resist := 0.0
	var uw := Vector3(uke.move_input.x, 0, uke.move_input.y)
	if uw.length() > 0.15:
		resist = clampf(uw.normalized().dot(-w.normalized()), 0.0, 1.0) * 0.7
		if resist > 0.0:
			uke.spend(5.0 * dt)
	if uke.defending:
		resist += 0.45
	var gain := 0.95 * (1.0 - clampf(resist, 0.0, 0.9)) * (0.6 + 0.4 * tori.stamina / Fighter.MAX_STAMINA)
	uke.kuzushi = (uke.kuzushi + effect * gain * dt * 1.6).limit_length(1.0)
	tori.spend(2.0 * dt)


# ------------------------------------------------------------------ projections
func _start_throw(tori: Fighter, tech: Technique, special: bool) -> void:
	var uke := tori.opponent
	_set_phase(Phase.THROW)
	tori.set_state(Fighter.S.ATTACK)
	uke.set_state(Fighter.S.THROWN)
	# placement exact : uke face à tori, à distance de saisie
	tori.face_towards(uke.global_position, 0.0)
	uke.global_position = tori.global_position + tori.forward() * JudoAnims.GRIP_DIST
	uke.face_towards(tori.global_position, 0.0)
	tori.restart(tech.anim_tori, 0.1)
	uke.restart(tech.anim_uke, 0.1)
	throw_info = {"tori": tori, "uke": uke, "tech": tech, "t": 0.0, "window": tech.defend_window,
		"decided": false, "blocked": false, "scored": false, "special": special, "start_clock": _clock, "result": ""}
	camera.focus_override = uke
	hud.technique(tech.name + (" (spécial)" if special else ""), tori == player)


func _throw(dt: float) -> void:
	var ti := throw_info
	ti["t"] += dt
	var t: float = ti["t"]
	var tori: Fighter = ti["tori"]
	var uke: Fighter = ti["uke"]
	var tech: Technique = ti["tech"]
	if not ti["decided"] and t >= tech.defend_window:
		ti["decided"] = true
		_decide_throw(ti)
		if ti["blocked"]:
			return
		if Settings.slow_motion and ti["result"] == "ippon":
			Engine.time_scale = 0.35
			_slowmo_until = _clock + 0.45
	if ti["blocked"]:
		if t > tech.defend_window + 0.75:
			camera.focus_override = null
			for f in [tori, uke]:
				f.set_state(Fighter.S.GRIP)
				f.face_lock = false
			tori.tech_cooldown = 1.2
			_set_phase(Phase.FIGHT)
		return
	if not ti["scored"] and t >= 1.28:
		ti["scored"] = true
		camera.shake(1.0)
		var res: String = ti["result"]
		if res == "":
			hud.announce("Pas de score", 1.2)
		else:
			var msg := board.add_score(tori.side, res)
			hud.announce(msg, 1.8)
			_training_continue()
	if t >= 2.1 and uke.state == Fighter.S.THROWN:
		uke.set_state(Fighter.S.DOWN)
		uke.play("down", 0.1)
	if t >= 2.15:
		camera.focus_override = null
		if board.is_over():
			_end_match()
			return
		_set_phase(Phase.NEWAZA)
		if tori == player:
			hud.hint("Appuyez sur IMMOBILISER pour enchaîner au sol (kesa-gatame)")
		tori.anim_done.connect(_on_tori_recovered.bind(tori), CONNECT_ONE_SHOT)


func _on_tori_recovered(_a: String, tori: Fighter) -> void:
	if tori.state == Fighter.S.ATTACK:
		tori.set_state(Fighter.S.FREE)
		tori.play("guard", 0.0)


func _decide_throw(ti: Dictionary) -> void:
	var tori: Fighter = ti["tori"]
	var uke: Fighter = ti["uke"]
	var tech: Technique = ti["tech"]
	var dirv := tech.kuzushi_dir.normalized()
	var align := clampf(uke.kuzushi.dot(dirv), 0.0, 1.0)
	var defended := uke.defending or (_clock - uke.last_defend_press) < tech.defend_window + 0.05
	var block_chance := 0.0
	if defended:
		block_chance = clampf(0.92 - align * 0.6 + (uke.stamina - tori.stamina) / 400.0, 0.12, 0.95)
	if align < tech.min_kuzushi:
		block_chance = maxf(block_chance, 0.55)   # sans kuzushi, uke reste solide
	if randf() < block_chance:
		ti["blocked"] = true
		tori.restart("attack_blocked", 0.15)
		tori.anim.seek(tech.defend_window, true)
		uke.restart("defend_block", 0.15)
		uke.anim.seek(0.2, true)
		tori.kuzushi = (tori.kuzushi + Vector2(0, 0.3)).limit_length(1.0)
		tori.spend(6.0)
		hud.announce("Bloqué !" if defended else "Pas de déséquilibre", 1.0)
		camera.focus_override = null
		return
	var q := 0.2 + align * 0.62 + tori.stamina / Fighter.MAX_STAMINA * 0.12
	q += 0.12 if ti["special"] else 0.0
	q -= 0.14 if defended else 0.0
	q += randf_range(-0.08, 0.08)
	var res := ""
	if q >= 0.74:
		res = "ippon"
	elif q >= 0.52:
		res = "waza-ari"
	elif q >= 0.32:
		res = "yuko"
	ti["result"] = res
	uke.kuzushi = Vector2.ZERO
	tori.kuzushi = Vector2.ZERO
	tori.has_grip = false
	uke.has_grip = false
	engaged = false


## En entraînement, un ippon ne termine pas la séance : on remet le tableau à zéro.
func _training_continue() -> void:
	if training and board.is_over():
		board = Scoreboard.new()


# ------------------------------------------------------------------ ne-waza
func _start_osaekomi(tori: Fighter) -> void:
	var uke := tori.opponent
	_set_phase(Phase.OSAEKOMI)
	tori.set_state(Fighter.S.PIN)
	uke.set_state(Fighter.S.PINNED)
	# tori s'installe à droite d'uke, face à sa tête (kesa-gatame)
	var fu := uke.forward()
	var right_u := -Vector3.UP.cross(fu).normalized()
	var hips := uke.pelvis_world()
	hips.y = Dojo.TATAMI_H
	var target := hips + right_u * 0.42 - fu * 0.12
	var tw := create_tween()
	tw.tween_property(tori, "global_position", target, 0.35)
	tori.face_lock = true
	tori.rotation.y = atan2(-fu.x, -fu.z)
	tori.play("pin_tori", 0.3)
	uke.play("pinned_uke", 0.2)
	osae = {"tori": tori, "uke": uke, "time": 0.0, "escape": 0.0, "awarded_wa": false}
	hud.announce("OSAEKOMI !", 1.2)
	if uke == player:
		hud.hint("Tapotez DÉFENSE pour vous dégager !")


func _escape_press(f: Fighter) -> void:
	if not f.spend(1.5):
		return
	var tori: Fighter = osae["tori"]
	osae["escape"] += 0.075 * (0.5 + f.stamina / 200.0) * (1.25 - tori.stamina / 400.0)


func _osaekomi(dt: float) -> void:
	osae["time"] += dt
	osae["escape"] = maxf(0.0, osae["escape"] - 0.05 * dt)
	var tori: Fighter = osae["tori"]
	var t: float = osae["time"]
	# waza-ari-awasete-ippon : si tori a déjà waza-ari, 10 s suffisent
	if board.wazaari[tori.side] >= 1 and t >= 10.0 and not board.golden_score:
		_end_osaekomi(false)
		return
	if t >= board.osaekomi_limit():
		_end_osaekomi(false)
		return
	if osae["escape"] >= 1.0:
		_end_osaekomi(true)


func _end_osaekomi(escaped: bool) -> void:
	var tori: Fighter = osae["tori"]
	var res := board.osaekomi_result(osae["time"])
	var msg := ""
	if res != "":
		msg = board.add_score(tori.side, res)
		_training_continue()
	var head := "TOKETA" if escaped else "SORE-MADE" if board.is_over() else "IPPON"
	hud.announce((head + " · " + msg) if msg != "" else head, 1.8)
	tori.face_lock = false
	if board.is_over():
		_end_match()
	else:
		_mate("")


# ------------------------------------------------------------------ mate / fin
func _mate(reason: String) -> void:
	_mate_reason = reason
	_mate_step = 0
	_set_phase(Phase.MATE)
	camera.focus_override = null
	if reason == "" and not hud.is_announcing():
		hud.announce("MATE", 1.0)
	for f in fighters:
		f.has_grip = false
		f.face_lock = false
		if f.state in [Fighter.S.DOWN, Fighter.S.PINNED, Fighter.S.THROWN]:
			f.set_state(Fighter.S.GETUP)
			f.restart("getup", 0.25)
		elif f.state == Fighter.S.PIN:
			f.set_state(Fighter.S.GETUP)
			f.global_position += f.global_basis * Vector3(0, 0, -0.3)
			f.restart("getup", 0.3)
		else:
			f.set_state(Fighter.S.FREE)
			f.play("guard", 0.3)
	engaged = false


func _mate_tick() -> void:
	if _mate_step == 0 and phase_time > 1.6:
		_mate_step = 1
		_place_at_start()
		for f in fighters:
			f.restart("guard", 0.0)
		camera.snap()
	elif _mate_step == 1 and phase_time > 2.2:
		_hajime()


func _end_match() -> void:
	_set_phase(Phase.END)
	Engine.time_scale = 1.0
	camera.focus_override = null
	var w := board.winner
	for f in fighters:
		f.face_lock = false
		f.has_grip = false
		var won := f.side == w
		f.set_state(Fighter.S.CEREMONY)
		if f.cur_anim in ["down", "pinned_uke", "osoto_uke"]:
			f.restart("getup", 0.25)
			f.anim_done.connect(func(_a): f.restart("victory" if won else "defeat", 0.3), CONNECT_ONE_SHOT)
		else:
			f.restart("victory" if won else "defeat", 0.3)
	if w == 0:
		Game.profile_data["wins"] += 1
	else:
		Game.profile_data["losses"] += 1
	hud.show_result(w == 0, board.win_reason)
