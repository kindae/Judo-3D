extends CanvasLayer
## Interface du combat : tableau de marque, chronomètre, endurance, déséquilibre,
## annonces de l'arbitre, commandes tactiles, pause, résultat, mesures de performance.

var match_node: Match

var _rows: Array[Dictionary] = []
var _timer: Label
var _gs: Label
var _announce: Label
var _announce_t := 0.0
var _hint: Label
var _hint_t := 0.0
var _tech: Label
var _tech_t := 0.0
var _kuz: Control
var _osae_box: PanelContainer
var _osae_bar: ProgressBar
var _osae_lbl: Label
var _pause: Control
var _result: Control
var _result_title: Label
var _result_reason: Label
var _touch: TouchControls
var _pause_btn: Button
var perf: PerfOverlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_scoreboard(root)
	_build_center(root)
	_build_osaekomi(root)
	_touch = TouchControls.new()
	_touch.controller = match_node.pc
	_touch.match_node = match_node
	_touch.visible = Settings.touch_controls
	_touch.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(_touch)
	_pause_btn = UIStyle.button("II", false, 26)
	_pause_btn.custom_minimum_size = Vector2(64, 56)
	_pause_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_pause_btn.position = Vector2(-80, 14)
	_pause_btn.offset_left = -80
	_pause_btn.offset_right = -16
	_pause_btn.offset_top = 14
	_pause_btn.offset_bottom = 70
	_pause_btn.pressed.connect(func(): match_node.toggle_pause())
	root.add_child(_pause_btn)
	_build_pause(root)
	_build_result(root)
	perf = PerfOverlay.new()
	root.add_child(perf)


# ------------------------------------------------------------------ construction
func _build_scoreboard(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	panel.position = Vector2(16, 14)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	for s in 2:
		var f: Fighter = match_node.fighters[s]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		v.add_child(h)
		var chip := ColorRect.new()
		chip.color = UIStyle.WHITE if s == 0 else UIStyle.BLUE
		chip.custom_minimum_size = Vector2(10, 34)
		h.add_child(chip)
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", 2)
		h.add_child(nv)
		var nm := UIStyle.label(f.display_name, 17)
		nm.custom_minimum_size = Vector2(170, 0)
		nv.add_child(nm)
		var st := UIStyle.bar(Color(0.35, 0.85, 0.45))
		st.max_value = Fighter.MAX_STAMINA
		nv.add_child(st)
		var score := UIStyle.label("", 26, UIStyle.TEXT)
		score.custom_minimum_size = Vector2(150, 0)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(score)
		var sh := HBoxContainer.new()
		sh.add_theme_constant_override("separation", 3)
		sh.custom_minimum_size = Vector2(52, 0)
		h.add_child(sh)
		var cards: Array[ColorRect] = []
		for i in 3:
			var c := ColorRect.new()
			c.custom_minimum_size = Vector2(12, 20)
			c.color = Color(0.95, 0.8, 0.1)
			c.visible = false
			sh.add_child(c)
			cards.append(c)
		_rows.append({"stamina": st, "score": score, "cards": cards})
	var th := HBoxContainer.new()
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(th)
	_timer = UIStyle.label("4:00", 30, UIStyle.ACCENT)
	th.add_child(_timer)
	_gs = UIStyle.label("  GOLDEN SCORE", 18, UIStyle.ACCENT)
	_gs.visible = false
	th.add_child(_gs)
	var legend := UIStyle.label("I  W  Y", 13, UIStyle.MUTED)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(legend)
	# indicateur de déséquilibre de l'adversaire
	_kuz = KuzushiGauge.new()
	_kuz.match_node = match_node
	_kuz.position = Vector2(16, 210)
	root.add_child(_kuz)


func _build_center(root: Control) -> void:
	_announce = UIStyle.label("", 64, Color(1, 1, 1), 10)
	_announce.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_announce.offset_top = 150
	_announce.offset_left = -600
	_announce.offset_right = 600
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_announce)
	_tech = UIStyle.label("", 34, UIStyle.ACCENT, 8)
	_tech.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_tech.offset_top = 236
	_tech.offset_left = -500
	_tech.offset_right = 500
	_tech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_tech)
	_hint = UIStyle.label("", 18, Color(1, 1, 1, 0.95), 6)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.offset_top = 96
	_hint.offset_left = -360
	_hint.offset_right = 360
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_hint)


func _build_osaekomi(root: Control) -> void:
	_osae_box = PanelContainer.new()
	_osae_box.add_theme_stylebox_override("panel", UIStyle.panel())
	_osae_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_osae_box.offset_top = -150
	_osae_box.offset_bottom = -90
	_osae_box.offset_left = -220
	_osae_box.offset_right = 220
	_osae_box.visible = false
	root.add_child(_osae_box)
	var v := VBoxContainer.new()
	_osae_box.add_child(v)
	_osae_lbl = UIStyle.label("OSAEKOMI 0 s", 18)
	_osae_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_osae_lbl)
	_osae_bar = UIStyle.bar(UIStyle.ACCENT)
	_osae_bar.max_value = 20.0
	_osae_bar.custom_minimum_size = Vector2(400, 14)
	v.add_child(_osae_bar)


func _overlay(root: Control) -> Control:
	var c := ColorRect.new()
	c.color = Color(0, 0, 0, 0.55)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.visible = false
	root.add_child(c)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(center)
	return c


func _build_pause(root: Control) -> void:
	_pause = _overlay(root)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel(Color(0.08, 0.09, 0.12, 0.96), 18))
	_pause.get_child(0).add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := UIStyle.label("PAUSE", 36, UIStyle.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b1 := UIStyle.button("Reprendre", true)
	b1.pressed.connect(func(): match_node.toggle_pause())
	v.add_child(b1)
	var b2 := UIStyle.button("Recommencer")
	b2.pressed.connect(func(): match_node.restart())
	v.add_child(b2)
	var bq := UIStyle.button("Graphismes : " + Settings.quality_name())
	bq.pressed.connect(func():
		Settings.set_value("quality", (Settings.quality + 1) % 3)
		bq.text = "Graphismes : " + Settings.quality_name())
	v.add_child(bq)
	var bf := UIStyle.button("Économie d'énergie : " + ("30 FPS" if Settings.battery_saver else "non (60 FPS)"))
	bf.pressed.connect(func():
		Settings.set_value("battery_saver", not Settings.battery_saver)
		bf.text = "Économie d'énergie : " + ("30 FPS" if Settings.battery_saver else "non (60 FPS)"))
	v.add_child(bf)
	var bt := UIStyle.button("Commandes tactiles : " + ("oui" if Settings.touch_controls else "non"))
	bt.pressed.connect(func():
		Settings.set_value("touch_controls", not Settings.touch_controls)
		_touch.visible = Settings.touch_controls
		bt.text = "Commandes tactiles : " + ("oui" if Settings.touch_controls else "non"))
	v.add_child(bt)
	var b3 := UIStyle.button("Menu principal")
	b3.pressed.connect(func(): Game.to_menu())
	v.add_child(b3)
	var keys := UIStyle.label("Clavier : ZQSD/WASD/flèches · J saisir · K projeter · L défense · I spécial · U immobiliser · Échap pause · F3 mesures", 14, UIStyle.MUTED)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.custom_minimum_size = Vector2(380, 0)
	v.add_child(keys)


func _build_result(root: Control) -> void:
	_result = _overlay(root)
	_result.color = Color(0, 0, 0, 0.35)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel(Color(0.08, 0.09, 0.12, 0.94), 18))
	_result.get_child(0).add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	_result_title = UIStyle.label("", 44, UIStyle.ACCENT)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_result_title)
	_result_reason = UIStyle.label("", 20)
	_result_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_result_reason)
	var b1 := UIStyle.button("Rejouer", true)
	b1.pressed.connect(func(): match_node.restart())
	v.add_child(b1)
	var b2 := UIStyle.button("Menu principal")
	b2.pressed.connect(func(): Game.to_menu())
	v.add_child(b2)


# ------------------------------------------------------------------ API
func announce(text: String, duration := 1.5) -> void:
	print("[ARBITRE] %s" % text)
	_announce.text = text
	_announce_t = duration
	_announce.modulate.a = 1.0
	_announce.scale = Vector2.ONE


func is_announcing() -> bool:
	return _announce_t > 0.0


func hint(text: String, duration := 3.0) -> void:
	_hint.text = text
	_hint_t = duration


func technique(tname: String, by_player: bool) -> void:
	_tech.text = tname
	_tech.add_theme_color_override("font_color", UIStyle.ACCENT if by_player else Color(0.55, 0.7, 1.0))
	_tech_t = 1.6


func show_pause(on: bool) -> void:
	_pause.visible = on


func show_result(player_won: bool, reason: String) -> void:
	await get_tree().create_timer(1.8).timeout
	_result_title.text = "VICTOIRE" if player_won else "DÉFAITE"
	_result_reason.text = reason
	_result.visible = true


func _fmt_time(t: float) -> String:
	var s := int(ceil(t))
	return "%d:%02d" % [s / 60, s % 60]


func refresh() -> void:
	var b := match_node.board
	for s in 2:
		var f: Fighter = match_node.fighters[s]
		var r := _rows[s]
		(r["stamina"] as ProgressBar).value = f.stamina
		var ip := "1" if b.ippon[s] else "0"
		(r["score"] as Label).text = "%s   %d   %d" % [ip, b.wazaari[s], b.yuko[s]]
		var cards: Array = r["cards"]
		for i in 3:
			(cards[i] as ColorRect).visible = b.shido[s] > i
			(cards[i] as ColorRect).color = Color(0.9, 0.1, 0.1) if b.shido[s] >= 3 else Color(0.95, 0.8, 0.1)
	if match_node.training:
		_timer.text = "ENTRAÎNEMENT"
	elif b.golden_score:
		_timer.text = "+" + _fmt_time(b.golden_time)
	else:
		_timer.text = _fmt_time(b.time_left)
	_gs.visible = b.golden_score
	var os := match_node.phase == Match.Phase.OSAEKOMI
	_osae_box.visible = os
	if os:
		var t: float = match_node.osae["time"]
		_osae_bar.max_value = b.osaekomi_limit()
		_osae_bar.value = t
		var who := "Vous immobilisez" if match_node.osae["tori"] == match_node.player else "Vous êtes immobilisé"
		_osae_lbl.text = "OSAEKOMI %d s · %s · dégagement %d %%" % [int(t), who, int(match_node.osae["escape"] * 100)]


func _process(dt: float) -> void:
	if _announce_t > 0.0:
		_announce_t -= dt / maxf(Engine.time_scale, 0.01)
		_announce.modulate.a = clampf(_announce_t * 2.0, 0.0, 1.0)
	if _hint_t > 0.0:
		_hint_t -= dt
		_hint.modulate.a = clampf(_hint_t * 2.0, 0.0, 1.0)
	if _tech_t > 0.0:
		_tech_t -= dt
		_tech.modulate.a = clampf(_tech_t * 2.0, 0.0, 1.0)
	_pause_btn.visible = not _result.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _result.visible:
		match_node.toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_perf"):
		Settings.set_value("show_perf", not Settings.show_perf)
