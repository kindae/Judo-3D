extends Node3D
## Menu principal : dojo en arrière-plan, combat rapide, entraînement, réglages.

var cam: Camera3D
var _t := 0.0
var _fighters: Array[Fighter] = []
var _ui: CanvasLayer
var _settings_box: VBoxContainer
var _main_box: VBoxContainer


func _ready() -> void:
	var dojo := Dojo.new()
	add_child(dojo)
	for s in 2:
		var f := Fighter.new()
		add_child(f)
		f.setup(s, "", Settings.BELTS.get(Settings.belt_color, Color.BLACK) if s == 0 else Settings.BELTS["black"], s)
		f.global_position = Vector3(-0.9 if s == 0 else 0.9, Dojo.TATAMI_H, 0)
		f.face_towards(Vector3(0.9 if s == 0 else -0.9, 0, 0), 0.0)
		f.set_process(true)
		_fighters.append(f)
	_fighters[0].restart("rei", 0.0)
	_fighters[1].restart("rei", 0.0)
	for f in _fighters:
		f.anim_done.connect(func(_a): f.play("guard", 0.4))
	cam = Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.current = true
	_build_ui()


func _process(dt: float) -> void:
	_t += dt
	var a := _t * 0.12 + 0.6
	cam.global_position = Vector3(sin(a) * 4.6, 1.7, cos(a) * 4.6)
	cam.look_at(Vector3(0, 1.0, 0))
	for f in _fighters:
		f.blob.visible = true


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 470
	root.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	margin.offset_right = 470
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 40)
	root.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)
	var title := UIStyle.label("JUDO 3D", 64, UIStyle.ACCENT, 8)
	v.add_child(title)
	var sub := UIStyle.label("Prototype · Godot 4 natif", 18, UIStyle.MUTED)
	v.add_child(sub)
	v.add_child(Control.new())
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 12)
	v.add_child(_main_box)
	var b1 := UIStyle.button("Combat rapide", true)
	b1.pressed.connect(func(): Game.start_match(Game.Mode.QUICK_MATCH))
	_main_box.add_child(b1)
	var b2 := UIStyle.button("Entraînement")
	b2.pressed.connect(func(): Game.start_match(Game.Mode.TRAINING))
	_main_box.add_child(b2)
	var bd := UIStyle.button("")
	var upd := func(): bd.text = "Difficulté : " + Settings.difficulty_name()
	upd.call()
	bd.pressed.connect(func():
		Settings.set_value("difficulty", (Settings.difficulty + 1) % 3)
		upd.call())
	_main_box.add_child(bd)
	var bs := UIStyle.button("Réglages")
	bs.pressed.connect(func(): _main_box.visible = false; _settings_box.visible = true)
	_main_box.add_child(bs)
	var soon := UIStyle.label("Bientôt : carrière, tournois, progression par ceintures", 14, UIStyle.MUTED)
	_main_box.add_child(soon)
	if not OS.has_feature("web"):
		var bq := UIStyle.button("Quitter")
		bq.pressed.connect(func(): get_tree().quit())
		_main_box.add_child(bq)
	_build_settings(v)


func _build_settings(parent: Control) -> void:
	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 10)
	_settings_box.visible = false
	parent.add_child(_settings_box)
	var entries := [
		["Graphismes", func(): return Settings.quality_name(), func(): Settings.set_value("quality", (Settings.quality + 1) % 3)],
		["Économie d'énergie", func(): return "30 FPS" if Settings.battery_saver else "non (60 FPS)", func(): Settings.set_value("battery_saver", not Settings.battery_saver)],
		["Ralentis (ippon)", func(): return "oui" if Settings.slow_motion else "non", func(): Settings.set_value("slow_motion", not Settings.slow_motion)],
		["Commandes tactiles", func(): return "oui" if Settings.touch_controls else "non", func(): Settings.set_value("touch_controls", not Settings.touch_controls)],
		["Mesures de performance", func(): return "oui" if Settings.show_perf else "non", func(): Settings.set_value("show_perf", not Settings.show_perf)],
		["Ceinture", func(): return Settings.BELT_NAMES[Settings.belt_color], func(): _next_belt()],
	]
	for e in entries:
		var b := UIStyle.button("", false, 20)
		b.custom_minimum_size = Vector2(360, 52)
		var lab: String = e[0]
		var getter: Callable = e[1]
		var act: Callable = e[2]
		b.text = "%s : %s" % [lab, getter.call()]
		b.pressed.connect(func():
			act.call()
			b.text = "%s : %s" % [lab, getter.call()])
		_settings_box.add_child(b)
	var back := UIStyle.button("Retour", true, 20)
	back.custom_minimum_size = Vector2(360, 52)
	back.pressed.connect(func(): _settings_box.visible = false; _main_box.visible = true)
	_settings_box.add_child(back)
	var info := UIStyle.label("Profil actuel : rendu %s" % RenderingServer.get_current_rendering_method(), 13, UIStyle.MUTED)
	_settings_box.add_child(info)


func _next_belt() -> void:
	var keys := Settings.BELTS.keys()
	var i := keys.find(Settings.belt_color)
	Settings.set_value("belt_color", keys[(i + 1) % keys.size()])
	_fighters[0].set_belt(Settings.BELTS[Settings.belt_color])


func on_back() -> void:
	if _settings_box.visible:
		_settings_box.visible = false
		_main_box.visible = true
	else:
		get_tree().quit()
