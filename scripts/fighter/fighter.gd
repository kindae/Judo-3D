class_name Fighter
extends Node3D
## Un judoka : modèle 3D, animations, déplacements, endurance et déséquilibre (kuzushi).
## Les décisions (saisie, projections, points) sont prises par le Match.

signal anim_done(anim_name: String)

enum S { FREE, GRIP, ATTACK, THROWN, DOWN, GETUP, PIN, PINNED, BLOCKED, CEREMONY, KUZUSHI }

const MODEL := preload("res://assets/characters/judoka.glb")
const HAIRS := ["Hair_SimpleParted", "Hair_Buzzed"]
const WALK_SPEED := 0.8
const SIDE_SPEED := 0.62
const GRIP_SPEED := 0.55
const MAX_STAMINA := 100.0

const GI_WHITE := Color(0.93, 0.93, 0.91)
const GI_BLUE := Color(0.05, 0.22, 0.62)
const HAIR_COLORS := [Color(0.16, 0.11, 0.08), Color(0.06, 0.05, 0.05)]

var side := 0
var display_name := ""
var opponent: Fighter
var state: int = S.FREE
var state_time := 0.0
var move_input := Vector2.ZERO      # direction voulue dans le monde (x, z), longueur 0..1
var stamina := MAX_STAMINA
var infinite_stamina := false
var kuzushi := Vector2.ZERO         # déséquilibre subi, repère du judoka (y>0 : vers l'avant)
var has_grip := false
var defending := false              # défense maintenue (jigotai)
var last_defend_press := -100.0
var tech_cooldown := 0.0
var face_lock := false

var model: Node3D
var skel: Skeleton3D
var anim: AnimationPlayer
var cur_anim := ""
var blob: MeshInstance3D
var _pelvis_idx := 1
var _time := 0.0

static var _mats := {}


func setup(p_side: int, p_name: String, belt: Color, hair_variant: int = 0) -> void:
	side = p_side
	display_name = p_name
	name = "Fighter%d" % side
	model = MODEL.instantiate()
	add_child(model)
	skel = model.find_child("Skeleton3D", true, false)
	_pelvis_idx = skel.find_bone("pelvis")
	_apply_materials(GI_WHITE if side == 0 else GI_BLUE, belt, hair_variant)
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	model.add_child(anim)
	anim.add_animation_library(JudoAnims.LIB_NAME, JudoAnims.build_library(skel))
	anim.animation_finished.connect(_on_anim_finished)
	_make_blob()
	play("guard", 0.0)


# ------------------------------------------------------------------ matériaux partagés
static func _shared(key: String, maker: Callable) -> Material:
	if not _mats.has(key):
		_mats[key] = maker.call()
	return _mats[key]


func _apply_materials(gi: Color, belt: Color, hair_variant: int) -> void:
	var detail: bool = Settings.profile()["tex_detail"]
	var gi_mat := _shared("gi_%s_%s" % [gi.to_html(), detail], func():
		var m := StandardMaterial3D.new()
		m.albedo_color = gi
		m.roughness = 0.92
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if detail:
			m.normal_enabled = true
			m.normal_texture = preload("res://assets/textures/gi_fabric_normal.jpg")
			m.normal_scale = 0.6
			m.uv1_scale = Vector3(7, 7, 7)
		return m)
	var belt_mat := _shared("belt_%s" % belt.to_html(), func():
		var m := StandardMaterial3D.new()
		m.albedo_color = belt
		m.roughness = 0.8
		return m)
	var hair_col: Color = HAIR_COLORS[hair_variant % HAIR_COLORS.size()]
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if mi.name.begins_with("Judogi"):
			mi.material_override = gi_mat
		elif mi.name == "Belt":
			mi.material_override = belt_mat
		elif mi.name.begins_with("Hair_") and not mi.name.begins_with(HAIRS[hair_variant % HAIRS.size()]):
			mi.visible = false
		elif mi.name.begins_with("Hair_") or mi.name == "Eyebrows":
			var src := mi.mesh.surface_get_material(0)
			mi.material_override = _shared("hair_%d_%s" % [hair_variant, mi.name], func():
				var m: StandardMaterial3D = src.duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()
				m.albedo_color = hair_col
				return m)
		elif mi.name == "Eyes":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_belt(color: Color) -> void:
	var belt_mat := _shared("belt_%s" % color.to_html(), func():
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.8
		return m)
	var b := model.find_child("Belt", true, false) as MeshInstance3D
	if b:
		b.material_override = belt_mat


func _make_blob() -> void:
	# ombre de contact douce (quad transparent, très peu coûteux)
	blob = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.orientation = PlaneMesh.FACE_Y
	blob.mesh = q
	blob.material_override = _shared("blob", func():
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0, 0, 0, 0.5)
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		g.gradient = grad
		g.width = 64
		g.height = 64
		m.albedo_texture = g
		m.render_priority = -1
		return m)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.top_level = true
	add_child(blob)


# ------------------------------------------------------------------ animation
func play(anim_name: String, blend := 0.18, speed := 1.0) -> void:
	if cur_anim == anim_name and anim.is_playing():
		anim.speed_scale = speed
		return
	cur_anim = anim_name
	anim.play(JudoAnims.LIB_NAME + "/" + anim_name, blend)
	anim.speed_scale = speed


func restart(anim_name: String, blend := 0.12) -> void:
	cur_anim = anim_name
	anim.stop()
	anim.play(JudoAnims.LIB_NAME + "/" + anim_name, blend)
	anim.speed_scale = 1.0


func _on_anim_finished(full_name: StringName) -> void:
	var a := String(full_name).get_slice("/", 1)
	if JudoAnims.END_OFFSET.has(a):
		# on reporte le déplacement de l'animation sur la position du judoka
		var off: Vector3 = JudoAnims.END_OFFSET[a]
		global_position += global_basis * Vector3(off.x, 0, off.z)
		cur_anim = ""
	anim_done.emit(a)


func set_state(s: int) -> void:
	state = s
	state_time = 0.0


# ------------------------------------------------------------------ utilitaires
func forward() -> Vector3:
	return global_basis.z.normalized()


func flat_pos() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func face_towards(target: Vector3, dt: float, rate := 8.0) -> void:
	var d := target - global_position
	d.y = 0
	if d.length() < 0.01:
		return
	var want := atan2(d.x, d.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(rate * dt, 0.0, 1.0)) if dt > 0.0 else want


func can_act() -> bool:
	return state in [S.FREE, S.GRIP]


func spend(amount: float) -> bool:
	if infinite_stamina:
		return true
	if stamina < amount:
		return false
	stamina -= amount
	return true


func pelvis_world() -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(_pelvis_idx).origin


# ------------------------------------------------------------------ mise à jour
func _process(dt: float) -> void:
	_time += dt
	state_time += dt
	tech_cooldown = maxf(0.0, tech_cooldown - dt)
	# récupération de l'endurance
	var regen := 7.0
	if state == S.GRIP:
		regen = 3.0
	elif state in [S.ATTACK, S.PIN, S.PINNED, S.THROWN]:
		regen = 0.0
	if defending:
		regen -= 4.0
	stamina = clampf(stamina + regen * dt, 0.0, MAX_STAMINA)
	if infinite_stamina:
		stamina = MAX_STAMINA
	# le déséquilibre se résorbe naturellement (plus vite en défense)
	var rec := 0.55 * (1.8 if defending else 1.0) * (0.6 + 0.4 * stamina / MAX_STAMINA)
	kuzushi = kuzushi.move_toward(Vector2.ZERO, rec * dt)
	_update_blob()


func update_locomotion(dt: float, opponent_pos: Vector3) -> Vector3:
	## Déplacement libre ou en saisie. Retourne le déplacement monde voulu pour ce pas.
	if not face_lock:
		face_towards(opponent_pos, dt, 10.0 if state == S.FREE else 6.0)
	var mv := move_input.limit_length(1.0)
	var fwd := forward()
	var left := Vector3.UP.cross(fwd).normalized()  # +X local = gauche du judoka
	var w := Vector3(mv.x, 0, mv.y)
	var f := w.dot(fwd)
	var l := w.dot(left)
	var gripping := state == S.GRIP
	var prefix := "gwalk_" if gripping else "walk_"
	if defending and gripping:
		play("defend", 0.2)
	elif mv.length() < 0.12:
		play("grip_idle" if gripping else "guard", 0.22)
	else:
		var a: String
		if absf(f) >= absf(l):
			a = prefix + ("fwd" if f > 0 else "back")
		else:
			a = prefix + ("left" if l > 0 else "right")
		play(a, 0.2, clampf(mv.length() * 1.1, 0.5, 1.2))
	var speed := GRIP_SPEED if gripping else (WALK_SPEED if absf(f) >= absf(l) else SIDE_SPEED)
	if defending:
		speed *= 0.5
	if stamina < 15.0:
		speed *= 0.7
	return (fwd * f + left * l) * speed * dt


func _update_blob() -> void:
	if blob == null:
		return
	var p := pelvis_world()
	var lying := state in [S.DOWN, S.PINNED, S.THROWN] and cur_anim in ["down", "pinned_uke", "osoto_uke"]
	blob.global_position = Vector3(p.x, 0.062, p.z)
	var h := clampf(p.y, 0.1, 1.0)
	var s := 0.85 + (1.0 - h) * 0.6
	blob.scale = Vector3(s, 1, s * (1.8 if lying else 1.0))
	if lying:
		blob.global_rotation = Vector3(0, rotation.y, 0)
