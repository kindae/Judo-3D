class_name PoseSolver
extends RefCounted
## Calcule une pose complète du squelette à partir d'une description simple.
##
## Repère « corps » : le judoka regarde +Z, sa gauche est +X, le haut est +Y,
## l'origine est au sol entre ses pieds. Une pose est un Dictionary :
##   root_rot  : Vector3 (degrés) rotation de tout le corps autour de l'origine (chutes)
##   root_pos  : Vector3 déplacement de tout le corps
##   hips      : Vector3 décalage du bassin (le haut du corps suit, les jambes s'adaptent)
##   hips_rot  : Vector3 (degrés) rotation du bassin (x>0 : bascule vers l'avant)
##   spine     : Vector3 (degrés) flexion du dos répartie sur 3 vertèbres (x>0 : vers l'avant)
##   neck, head: Vector3 (degrés)
##   hand_l/hand_r : Vector3 position du poignet  (+ elbow_l/elbow_r : direction du coude)
##   foot_l/foot_r : Vector3 position de la cheville (+ knee_l/knee_r : direction du genou)
##   toe_l/toe_r   : float (degrés) inclinaison du pied
## Toutes les positions sont exprimées dans le repère corps (avant root_rot/root_pos).

const SKEL_PATH := "Armature/Skeleton3D:"

var n := 0
var names: PackedStringArray = []
var rest_local: Array[Transform3D] = []
var rest_global: Array[Transform3D] = []
var parent: PackedInt32Array = []
var order: PackedInt32Array = []
var idx := {}
var fist := {}  # index d'os -> Quaternion (doigts fermés)
var len_upper_l := 0.25
var len_lower_l := 0.24
var len_thigh := 0.43
var len_calf := 0.46


func _init(skel: Skeleton3D, fist_pose: Dictionary = {}) -> void:
	n = skel.get_bone_count()
	for i in n:
		names.append(skel.get_bone_name(i))
		rest_local.append(skel.get_bone_rest(i))
		rest_global.append(skel.get_bone_global_rest(i))
		parent.append(skel.get_bone_parent(i))
		idx[skel.get_bone_name(i)] = i
	# ordre parents -> enfants
	var done := {}
	while order.size() < n:
		for i in n:
			if done.has(i):
				continue
			if parent[i] < 0 or done.has(parent[i]):
				order.append(i)
				done[i] = true
	for k in fist_pose:
		if idx.has(k):
			fist[idx[k]] = fist_pose[k]
	len_upper_l = rest_local[idx["lowerarm_l"]].origin.length()
	len_lower_l = rest_local[idx["hand_l"]].origin.length()
	len_thigh = rest_local[idx["calf_l"]].origin.length()
	len_calf = rest_local[idx["foot_l"]].origin.length()


static func _rad(v: Vector3) -> Vector3:
	return Vector3(deg_to_rad(v.x), deg_to_rad(v.y), deg_to_rad(v.z))


static func _align(b: Basis, dir: Vector3) -> Basis:
	var cur := b.y.normalized()
	var d := dir.normalized()
	if cur.dot(d) > 0.99999:
		return b
	if cur.dot(d) < -0.9999:
		return Basis(Vector3.FORWARD, PI) * b
	return Basis(Quaternion(cur, d)) * b


static func _two_bone(s: Vector3, t: Vector3, a: float, b: float, pole: Vector3) -> Vector3:
	var d := t - s
	var dist := clampf(d.length(), absf(a - b) + 0.002, a + b - 0.002)
	var dir := d.normalized()
	var cos_a := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
	var sin_a := sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var perp := pole - dir * pole.dot(dir)
	if perp.length() < 0.0001:
		perp = dir.cross(Vector3.RIGHT)
	perp = perp.normalized()
	return s + dir * a * cos_a + perp * a * sin_a


## Retourne {"rot": Array[Quaternion], "pos": Array[Vector3]} (transformations locales de chaque os).
func solve(p: Dictionary) -> Dictionary:
	var g: Array[Transform3D] = []
	g.resize(n)
	var out_rot: Array[Quaternion] = []
	out_rot.resize(n)
	var out_pos: Array[Vector3] = []
	out_pos.resize(n)
	var body := Basis.from_euler(_rad(p.get("root_rot", Vector3.ZERO)))
	var body_t := Transform3D(body, p.get("root_pos", Vector3.ZERO))
	var joints := {}  # coudes/genoux calculés

	for i in order:
		var nm: String = names[i]
		var base_local := rest_local[i]
		if fist.has(i):
			base_local = Transform3D(Basis(fist[i]), base_local.origin)
		var gp := Transform3D.IDENTITY if parent[i] < 0 else g[parent[i]]
		var cur := gp * base_local
		match nm:
			"root":
				cur = body_t * rest_local[i]
			"pelvis":
				var r := body * Basis.from_euler(_rad(p.get("hips_rot", Vector3.ZERO))) * body.inverse()
				cur.basis = r * cur.basis
				cur.origin += body * (p.get("hips", Vector3.ZERO) as Vector3)
			"spine_01", "spine_02", "spine_03":
				var e: Vector3 = p.get("spine", Vector3.ZERO) / 3.0
				cur.basis = body * Basis.from_euler(_rad(e)) * body.inverse() * cur.basis
			"neck_01":
				cur.basis = body * Basis.from_euler(_rad(p.get("neck", Vector3.ZERO))) * body.inverse() * cur.basis
			"Head":
				cur.basis = body * Basis.from_euler(_rad(p.get("head", Vector3.ZERO))) * body.inverse() * cur.basis
			"upperarm_l", "upperarm_r", "thigh_l", "thigh_r":
				var side := nm.substr(nm.length() - 1)
				var is_arm := nm.begins_with("upper")
				var key := ("hand_" if is_arm else "foot_") + side
				if p.has(key):
					var target: Vector3 = body_t * (p[key] as Vector3)
					var pole_key := ("elbow_" if is_arm else "knee_") + side
					var default_pole := Vector3(0.0, -1.0, -0.4) if is_arm else Vector3(0.0, 0.0, 1.0)
					if is_arm:
						default_pole.x = 0.6 if side == "l" else -0.6
					var pole: Vector3 = body * (p.get(pole_key, default_pole) as Vector3)
					var a := len_upper_l if is_arm else len_thigh
					var b := len_lower_l if is_arm else len_calf
					var j := _two_bone(cur.origin, target, a, b, pole)
					joints[nm] = [j, target]
					cur.basis = _align(cur.basis, j - cur.origin)
			"lowerarm_l", "lowerarm_r", "calf_l", "calf_r":
				var up := ("upperarm_" if nm.begins_with("lower") else "thigh_") + nm.substr(nm.length() - 1)
				if joints.has(up):
					var t: Vector3 = joints[up][1]
					cur.basis = _align(cur.basis, t - cur.origin)
			"foot_l", "foot_r":
				var side := nm.substr(nm.length() - 1)
				var toe: float = p.get("toe_" + side, 0.0)
				var yaw: float = p.get("foot_yaw_" + side, 0.0)
				cur.basis = body * Basis.from_euler(Vector3(deg_to_rad(toe), deg_to_rad(yaw), 0.0)) * rest_global[i].basis
			"hand_l", "hand_r":
				var hk := "hand_rot_" + nm.substr(nm.length() - 1)
				if p.has(hk):
					cur.basis = body * Basis.from_euler(_rad(p[hk])) * body.inverse() * cur.basis
		g[i] = cur
		var loc := gp.affine_inverse() * cur
		out_rot[i] = loc.basis.get_rotation_quaternion()
		out_pos[i] = loc.origin
	return {"rot": out_rot, "pos": out_pos}


## Construit une Animation à partir d'une liste de clés [temps, pose].
func make_animation(keys: Array, length: float, loop: bool) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var solved: Array = []
	for k in keys:
		solved.append(solve(k[1]))
	for i in n:
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath(SKEL_PATH + names[i]))
		anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
		anim.track_set_interpolation_loop_wrap(t, loop)
		for ki in keys.size():
			anim.rotation_track_insert_key(t, keys[ki][0], solved[ki]["rot"][i])
	for bn in ["root", "pelvis"]:
		var i: int = idx[bn]
		var t := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(t, NodePath(SKEL_PATH + bn))
		anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
		anim.track_set_interpolation_loop_wrap(t, loop)
		for ki in keys.size():
			anim.position_track_insert_key(t, keys[ki][0], solved[ki]["pos"][i])
	return anim
