extends SceneTree
## Capture d'écran de poses : godot --path . --script tools/pose_preview.gd -- anim temps [anim_uke] [sortie]
var args: PackedStringArray
var frames := 0
var A: AnimationPlayer
var B: AnimationPlayer
func _mk(pos: Vector3, yaw: float, tint: Color) -> AnimationPlayer:
	var c: Node3D = load("res://assets/characters/judoka.glb").instantiate()
	root.add_child(c)
	c.position = pos; c.rotation.y = yaw
	for mi in c.find_children("*", "MeshInstance3D", true, false):
		if mi.name.begins_with("Judogi"):
			var mat := StandardMaterial3D.new(); mat.albedo_color = tint; mi.material_override = mat
	var sk: Skeleton3D = c.find_child("Skeleton3D", true, false)
	var ap := AnimationPlayer.new(); c.add_child(ap)
	ap.add_animation_library("judo", JudoAnims.build_library(sk))
	return ap
func _initialize():
	args = OS.get_cmdline_user_args()
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.5,0.55,0.6)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.7,0.7,0.75); e.ambient_light_energy = 0.6
	env.environment = e; root.add_child(env)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-50, 30, 0); l.shadow_enabled = true; root.add_child(l)
	var f := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(8,8); f.mesh = pm; root.add_child(f)
	var cam := Camera3D.new(); root.add_child(cam)
	var view := args[4] if args.size() > 4 else "side"
	if view == "side": cam.look_at_from_position(Vector3(3.2, 1.3, 0.3), Vector3(0, 0.8, 0.3))
	elif view == "front": cam.look_at_from_position(Vector3(0.6, 1.4, -2.8), Vector3(0, 0.9, 0.3))
	elif view == "close": cam.look_at_from_position(Vector3(2.0, 1.2, 0.4), Vector3(0, 0.9, 0.3))
	else: cam.look_at_from_position(Vector3(2.2, 2.2, -1.8), Vector3(0, 0.6, 0.3))
	A = _mk(Vector3.ZERO, 0.0, Color(0.95,0.95,0.93))
	if args.size() > 2 and args[2] != "-":
		B = _mk(Vector3(0,0,JudoAnims.GRIP_DIST), PI, Color(0.1,0.25,0.7))
var times: PackedStringArray
var ti := 0
var shots: Array[Image] = []
func _process(_d):
	frames += 1
	if frames == 1: times = args[1].split(",")
	if frames % 3 == 1:
		var t := float(times[ti])
		A.play("judo/" + args[0]); A.seek(t, true); A.pause()
		if B: B.play("judo/" + args[2]); B.seek(t, true); B.pause()
	elif frames % 3 == 0:
		var img := root.get_texture().get_image()
		img.resize(480, 270)
		shots.append(img)
		ti += 1
		if ti >= times.size():
			var cols := mini(3, shots.size()); var rows := (shots.size() + cols - 1) / cols
			var sheet := Image.create(480 * cols, 270 * rows, false, img.get_format())
			for i in shots.size(): sheet.blit_rect(shots[i], Rect2i(0,0,480,270), Vector2i((i % cols) * 480, (i / cols) * 270))
			sheet.save_png(args[3])
			quit()
	return false
