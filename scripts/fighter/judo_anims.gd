class_name JudoAnims
extends RefCounted
## Animations de judo générées par code (poses clés + cinématique inverse).
## Repère : le judoka regarde +Z, sa gauche est +X (voir PoseSolver).
##
## Les projections sont écrites par paires (tori / uke) avec la même durée et les
## mêmes instants clés : jouées ensemble, elles restent synchronisées. Pendant une
## projection, uke est placé à GRIP_DIST devant tori, face à lui.

const GRIP_DIST := 0.62
const LIB_NAME := "judo"

## Décalage (repère corps) à reporter sur la position du judoka à la fin d'une animation.
const END_OFFSET := {
	"osoto_tori": Vector3(0.16, 0.0, 0.22),
	"getup": Vector3(0.0, 0.0, -0.62),
}

static var _cache: AnimationLibrary


static func m(a: Dictionary, b: Dictionary) -> Dictionary:
	var r := a.duplicate()
	r.merge(b, true)
	return r


# ------------------------------------------------------------------ poses de base
static func stand() -> Dictionary:
	return {
		"hips": Vector3(0, -0.02, 0), "spine": Vector3(2, 0, 0),
		"foot_l": Vector3(0.12, 0.087, -0.01), "foot_r": Vector3(-0.12, 0.087, -0.01),
		"hand_l": Vector3(0.21, 0.86, 0.0), "hand_r": Vector3(-0.21, 0.86, 0.0),
		"elbow_l": Vector3(0.3, 0, -1), "elbow_r": Vector3(-0.3, 0, -1),
	}


static func guard() -> Dictionary:
	return {
		"hips": Vector3(0.0, -0.075, -0.01), "hips_rot": Vector3(6, 0, 0),
		"spine": Vector3(12, 0, 0), "neck": Vector3(-10, 0, 0), "head": Vector3(-4, 0, 0),
		"foot_l": Vector3(0.18, 0.087, -0.07), "foot_r": Vector3(-0.17, 0.087, 0.11),
		"knee_l": Vector3(0.25, 0, 1), "knee_r": Vector3(-0.25, 0, 1),
		"foot_yaw_l": 12.0, "foot_yaw_r": -8.0,
		"hand_l": Vector3(0.24, 1.10, 0.30), "hand_r": Vector3(-0.21, 1.15, 0.30),
		"elbow_l": Vector3(1, -1, -0.4), "elbow_r": Vector3(-1, -1, -0.4),
	}


static func grip() -> Dictionary:
	# main droite au revers gauche d'uke, main gauche à sa manche droite
	return m(guard(), {
		"hips": Vector3(0.0, -0.085, -0.03), "spine": Vector3(15, 0, 0),
		"hand_r": Vector3(-0.07, 1.30, 0.40), "elbow_r": Vector3(-1, -1.2, -0.2),
		"hand_l": Vector3(0.25, 1.08, 0.46), "elbow_l": Vector3(1, -0.8, -0.3),
	})


static func defend() -> Dictionary:
	# jigotai : bassin bas et en arrière, appuis larges, bras raides
	return m(grip(), {
		"hips": Vector3(0.0, -0.19, -0.08), "hips_rot": Vector3(14, 0, 0), "spine": Vector3(22, 0, 0),
		"neck": Vector3(-16, 0, 0),
		"foot_l": Vector3(0.30, 0.087, -0.10), "foot_r": Vector3(-0.29, 0.087, 0.05),
		"knee_l": Vector3(0.6, 0, 1), "knee_r": Vector3(-0.6, 0, 1),
		"hand_r": Vector3(-0.07, 1.22, 0.45), "hand_l": Vector3(0.26, 1.02, 0.50),
	})


# Pose au sol (sur le dos). Le bassin est abaissé de 0,83 m pour que les rotations
# de tout le corps pivotent près des hanches.
static func lying() -> Dictionary:
	return {
		"root_rot": Vector3(-90, 0, 0), "root_pos": Vector3(0, 0.115, -0.47),
		"hips": Vector3(0, -0.83, 0), "spine": Vector3(-2, 0, 0), "neck": Vector3(8, 0, 0),
		"foot_l": Vector3(0.17, -0.70, -0.05), "foot_r": Vector3(-0.15, -0.68, -0.05),
		"knee_l": Vector3(0.2, 0, 1), "knee_r": Vector3(-0.2, 0, 1),
		"toe_l": -60.0, "toe_r": -60.0,
		"hand_l": Vector3(0.48, 0.80, -0.07), "hand_r": Vector3(-0.48, 0.80, -0.07),
		"elbow_l": Vector3(1, 0, -0.3), "elbow_r": Vector3(-1, 0, -0.3),
	}


# ------------------------------------------------------------------ déplacements (suri-ashi)
static func _walk(upper: Dictionary, dir: Vector2, speed: float, cycle: float) -> Array:
	# dir : x = côté (gauche +), y = avant. Le pied posé glisse vers l'arrière pendant
	# que l'autre avance, sans jamais croiser les pieds.
	var amp := speed * cycle / 4.0
	var keys := []
	var steps := 8
	for s in steps + 1:
		var ph := float(s) / steps
		var p := upper.duplicate()
		for side in ["l", "r"]:
			var phase := fmod(ph + (0.0 if side == "l" else 0.5), 1.0)
			var off := 0.0
			var lift := 0.0
			if phase < 0.5:
				off = amp - phase / 0.5 * 2.0 * amp
			else:
				var q := (phase - 0.5) / 0.5
				off = -amp + q * 2.0 * amp
				lift = sin(q * PI) * 0.035
			var base: Vector3 = upper["foot_" + side]
			p["foot_" + side] = base + Vector3(dir.x * off, lift, dir.y * off)
		var bob := -0.012 * absf(cos(ph * TAU * 2.0))
		p["hips"] = (upper["hips"] as Vector3) + Vector3(0, bob, 0)
		keys.append([ph * cycle, p])
	return keys


# ------------------------------------------------------------------ O-soto-gari
static func osoto_tori() -> Array:
	var g := grip()
	return [
		[0.0, g],
		[0.28, m(g, {  # pas d'entrée : pied gauche à côté du pied droit d'uke
			"hips": Vector3(0.13, -0.07, 0.12), "spine": Vector3(10, -10, 0),
			"foot_l": Vector3(0.38, 0.087, 0.40), "foot_yaw_l": -10.0,
			"hand_l": Vector3(0.32, 1.02, 0.36), "hand_r": Vector3(-0.02, 1.40, 0.46),
		})],
		[0.55, m(g, {  # la jambe droite passe derrière la jambe droite d'uke
			"hips": Vector3(0.22, -0.05, 0.26), "spine": Vector3(18, -14, 0), "neck": Vector3(-4, 0, 0),
			"foot_l": Vector3(0.38, 0.087, 0.40), "foot_yaw_l": -10.0,
			"foot_r": Vector3(0.10, 0.30, 0.78), "knee_r": Vector3(0, 0.3, 1),
			"hand_l": Vector3(0.36, 0.98, 0.28), "hand_r": Vector3(0.0, 1.42, 0.52),
		})],
		[0.82, m(g, {  # fauchage : la jambe balaie vers l'arrière, le buste plonge
			"hips": Vector3(0.24, -0.04, 0.30), "hips_rot": Vector3(28, 0, 0), "spine": Vector3(36, -10, 0), "neck": Vector3(-30, 0, 0),
			"foot_l": Vector3(0.38, 0.087, 0.40), "foot_yaw_l": -10.0, "knee_l": Vector3(0, 0, 1),
			"foot_r": Vector3(0.05, 0.62, 0.02), "knee_r": Vector3(0, -1, 0.2), "toe_r": 50.0,
			"hand_l": Vector3(0.36, 0.86, 0.36), "hand_r": Vector3(0.02, 1.10, 0.66),
		})],
		[1.1, m(g, {
			"hips": Vector3(0.24, -0.10, 0.32), "hips_rot": Vector3(34, 0, 0), "spine": Vector3(40, -6, 0), "neck": Vector3(-32, 0, 0),
			"foot_l": Vector3(0.38, 0.087, 0.40), "foot_yaw_l": -10.0, "knee_l": Vector3(0, 0, 1),
			"foot_r": Vector3(0.0, 0.70, -0.22), "knee_r": Vector3(0, -1, 0.2), "toe_r": 60.0,
			"hand_l": Vector3(0.34, 0.62, 0.52), "hand_r": Vector3(0.0, 0.76, 0.70),
		})],
		[1.5, m(g, {  # contrôle d'uke au sol
			"hips": Vector3(0.18, -0.24, 0.24), "spine": Vector3(32, 0, 0), "neck": Vector3(-12, 0, 0),
			"foot_l": Vector3(0.38, 0.087, 0.40), "foot_yaw_l": -10.0,
			"foot_r": Vector3(-0.06, 0.087, 0.06),
			"hand_l": Vector3(0.36, 0.50, 0.76), "hand_r": Vector3(-0.04, 0.74, 0.52),
		})],
		[2.1, m(g, {
			"hips": Vector3(0.16, -0.12, 0.22), "spine": Vector3(22, 0, 0), "neck": Vector3(-14, 0, 0),
			"foot_l": Vector3(0.36, 0.087, 0.36), "foot_r": Vector3(-0.02, 0.087, 0.12),
			"hand_l": Vector3(0.38, 0.62, 0.78), "hand_r": Vector3(-0.18, 1.05, 0.40),
		})],
		# retour en garde, décalé : ce décalage est reporté sur la position (END_OFFSET)
		[2.6, m(guard(), {"root_pos": END_OFFSET["osoto_tori"]})],
	]


static func osoto_uke() -> Array:
	var g := grip()
	var l := lying()
	return [
		[0.0, g],
		[0.28, m(g, {  # kuzushi vers l'arrière, poids sur le talon droit
			"hips": Vector3(0.0, -0.05, -0.08), "spine": Vector3(-10, 8, 0), "neck": Vector3(6, 0, 0),
			"foot_r": Vector3(-0.15, 0.087, 0.06), "foot_l": Vector3(0.18, 0.12, -0.02), "toe_l": 25.0,
			"hand_r": Vector3(-0.10, 1.24, 0.34), "hand_l": Vector3(0.28, 1.16, 0.34),
		})],
		[0.55, m(g, {
			"hips": Vector3(-0.03, -0.06, -0.14), "spine": Vector3(-20, 12, 0), "neck": Vector3(14, 0, 0),
			"foot_r": Vector3(-0.14, 0.087, 0.04), "foot_l": Vector3(0.20, 0.20, 0.04), "toe_l": 30.0,
			"hand_r": Vector3(-0.12, 1.30, 0.28), "hand_l": Vector3(0.32, 1.22, 0.28),
		})],
		[0.82, m(g, {  # la jambe droite est fauchée
			"root_rot": Vector3(-24, 0, 0), "root_pos": Vector3(0, 0.075, 0.14),
			"hips": Vector3(0, -0.15, 0), "spine": Vector3(-10, 10, 0), "neck": Vector3(22, 0, 0),
			"foot_r": Vector3(-0.12, 0.42, 0.42), "knee_r": Vector3(0, 0.4, 1), "toe_r": -30.0,
			"foot_l": Vector3(0.18, 0.06, -0.10), "toe_l": 20.0,
			"hand_r": Vector3(-0.14, 1.28, 0.30), "hand_l": Vector3(0.40, 1.20, 0.18),
		})],
		[1.05, m(l, {  # en l'air
			"root_rot": Vector3(-62, 0, 0), "root_pos": Vector3(0, 0.22, -0.08),
			"hips": Vector3(0, -0.5, 0), "spine": Vector3(8, 0, 0), "neck": Vector3(30, 0, 0),
			"foot_r": Vector3(-0.12, -0.05, 0.62), "foot_l": Vector3(0.17, -0.10, 0.48),
			"knee_r": Vector3(0, 0.5, 1), "knee_l": Vector3(0, 0.5, 1), "toe_l": -20.0, "toe_r": -20.0,
			"hand_r": Vector3(-0.16, 1.15, 0.40), "hand_l": Vector3(0.52, 1.10, 0.05),
		})],
		[1.28, m(l, {  # impact + ukemi : la main gauche frappe le tatami
			"spine": Vector3(14, 0, 0), "neck": Vector3(32, 0, 0),
			"foot_r": Vector3(-0.14, -0.40, 0.34), "foot_l": Vector3(0.18, -0.44, 0.26),
			"knee_r": Vector3(0, 0.5, 1), "knee_l": Vector3(0, 0.5, 1), "toe_l": -40.0, "toe_r": -40.0,
			"hand_l": Vector3(0.55, 0.92, -0.08), "hand_r": Vector3(-0.30, 1.00, 0.30),
		})],
		[1.7, m(l, {"hand_r": Vector3(-0.36, 0.90, 0.10), "neck": Vector3(18, 0, 0)})],
		[2.1, l],
	]


# ------------------------------------------------------------------ autres séquences
static func getup() -> Array:
	var l := lying()
	var sit := {
		"root_rot": Vector3(-30, 0, 0), "root_pos": Vector3(0, 0.07, -0.53),
		"hips": Vector3(0, -0.83, 0), "spine": Vector3(26, 0, 0), "neck": Vector3(-8, 0, 0),
		"foot_l": Vector3(0.18, -0.30, 0.30), "foot_r": Vector3(-0.18, -0.30, 0.34),
		"knee_l": Vector3(0.2, 1, 0.3), "knee_r": Vector3(-0.2, 1, 0.3), "toe_l": -20.0, "toe_r": -20.0,
		"hand_l": Vector3(0.36, 0.30, -0.12), "hand_r": Vector3(-0.36, 0.30, -0.12),
	}
	var squat := {
		"root_rot": Vector3(0, 0, 0), "root_pos": Vector3(0, 0, -0.62),
		"hips": Vector3(0, -0.48, -0.08), "hips_rot": Vector3(20, 0, 0), "spine": Vector3(25, 0, 0),
		"neck": Vector3(-15, 0, 0),
		"foot_l": Vector3(0.20, 0.087, 0.12), "foot_r": Vector3(-0.20, 0.087, 0.16),
		"knee_l": Vector3(0.4, 0, 1), "knee_r": Vector3(-0.4, 0, 1),
		"hand_l": Vector3(0.30, 0.55, 0.40), "hand_r": Vector3(-0.30, 0.55, 0.40),
	}
	var end := m(guard(), {"root_pos": Vector3(0, 0, -0.62)})
	return [[0.0, l], [0.45, sit], [0.95, squat], [1.4, end]]


static func rei() -> Array:
	var s := stand()
	s["foot_l"] = Vector3(0.09, 0.087, 0.0)
	s["foot_r"] = Vector3(-0.09, 0.087, 0.0)
	s["foot_yaw_l"] = 15.0
	s["foot_yaw_r"] = -15.0
	s["hand_l"] = Vector3(0.20, 0.84, 0.06)
	s["hand_r"] = Vector3(-0.20, 0.84, 0.06)
	var bow := m(s, {
		"hips": Vector3(0, -0.02, -0.06), "hips_rot": Vector3(12, 0, 0), "spine": Vector3(22, 0, 0),
		"neck": Vector3(6, 0, 0), "hand_l": Vector3(0.17, 0.74, 0.22), "hand_r": Vector3(-0.17, 0.74, 0.22),
	})
	return [[0.0, s], [0.4, s], [1.0, bow], [1.6, bow], [2.2, s], [2.6, s]]


static func victory() -> Array:
	var s := stand()
	var up := m(s, {
		"spine": Vector3(-6, 0, 0), "neck": Vector3(-14, 0, 0),
		"hand_l": Vector3(0.34, 1.98, 0.12), "hand_r": Vector3(-0.34, 1.98, 0.12),
		"elbow_l": Vector3(1, 0, -0.2), "elbow_r": Vector3(-1, 0, -0.2),
	})
	var up2 := m(up, {"hand_l": Vector3(0.38, 2.02, 0.16), "hand_r": Vector3(-0.30, 1.96, 0.10), "spine": Vector3(-4, 4, 0)})
	return [[0.0, s], [0.5, up], [1.1, up2], [1.7, up]]


static func defeat() -> Array:
	var s := stand()
	var down := m(s, {
		"hips": Vector3(0, -0.03, 0), "spine": Vector3(14, 0, 0), "neck": Vector3(28, 0, 0), "head": Vector3(8, 0, 0),
		"hand_l": Vector3(0.20, 0.82, 0.08), "hand_r": Vector3(-0.30, 0.86, 0.10),
	})
	return [[0.0, s], [0.8, down], [2.0, m(down, {"spine": Vector3(16, 0, 0)})]]


static func kuzushi_back() -> Array:
	var g := grip()
	var lean := m(g, {
		"hips": Vector3(0, -0.06, -0.12), "spine": Vector3(-12, 0, 0), "neck": Vector3(10, 0, 0),
		"foot_l": Vector3(0.20, 0.13, 0.0), "toe_l": 25.0,
		"hand_l": Vector3(0.32, 1.20, 0.38), "hand_r": Vector3(-0.12, 1.30, 0.36),
	})
	return [[0.0, g], [0.25, lean], [0.7, g]]


static func kuzushi_fwd() -> Array:
	var g := grip()
	var lean := m(g, {
		"hips": Vector3(0, -0.08, 0.08), "spine": Vector3(32, 0, 0), "neck": Vector3(-20, 0, 0),
		"foot_r": Vector3(-0.17, 0.087, 0.26), "foot_l": Vector3(0.18, 0.12, -0.12), "toe_l": 30.0,
	})
	return [[0.0, g], [0.25, lean], [0.7, g]]


static func attack_blocked() -> Array:
	# tori entre, uke résiste en jigotai, tori est repoussé
	var g := grip()
	return [
		[0.0, g],
		[0.28, m(g, {"hips": Vector3(0.12, -0.07, 0.12), "spine": Vector3(12, -10, 0),
			"foot_l": Vector3(0.36, 0.087, 0.38)})],
		[0.5, m(g, {"hips": Vector3(0.14, -0.06, 0.16), "spine": Vector3(22, -12, 0),
			"foot_l": Vector3(0.36, 0.087, 0.38), "foot_r": Vector3(0.06, 0.26, 0.60), "knee_r": Vector3(0, 0.3, 1)})],
		[0.85, m(g, {"hips": Vector3(0.0, -0.06, -0.06), "spine": Vector3(6, 0, 0), "foot_l": Vector3(0.22, 0.087, 0.0)})],
		[1.1, g],
	]


static func defend_block() -> Array:
	var d := defend()
	return [[0.0, grip()], [0.2, d], [0.85, d], [1.1, grip()]]


static func pin_tori() -> Array:
	# Kesa-gatame : assis à droite d'uke, buste sur sa poitrine, bras autour du cou.
	var p := {
		"root_rot": Vector3(0, 0, 0), "root_pos": Vector3(0, 0, 0),
		"hips": Vector3(0.0, -0.80, 0.0), "hips_rot": Vector3(0, 0, 0), "spine": Vector3(30, 0, 18),
		"neck": Vector3(-10, 0, 0),
		"foot_r": Vector3(-0.22, 0.06, 0.58), "foot_l": Vector3(0.52, 0.06, -0.42),
		"knee_r": Vector3(-0.3, 1, 0.4), "knee_l": Vector3(0.6, 1, -0.2), "toe_l": -70.0, "toe_r": -70.0,
		"hand_r": Vector3(-0.34, 0.30, 0.42), "hand_l": Vector3(0.12, 0.40, 0.32),
		"elbow_r": Vector3(-1, 0.3, 0), "elbow_l": Vector3(1, 0, -0.4),
	}
	var p2 := m(p, {"spine": Vector3(33, 0, 21), "hips": Vector3(0.02, -0.80, 0.02)})
	return [[0.0, p], [0.8, p2], [1.6, p]]


static func pinned_uke() -> Array:
	var l := lying()
	var push := m(l, {"hips": Vector3(0.05, -0.80, 0.03), "spine": Vector3(-6, 0, -8),
		"hand_l": Vector3(0.20, 1.20, 0.25), "hand_r": Vector3(-0.40, 0.95, 0.10),
		"foot_l": Vector3(0.22, -0.50, 0.12), "knee_l": Vector3(0, 0.6, 1)})
	return [[0.0, l], [0.4, push], [0.9, l]]


# ------------------------------------------------------------------ bibliothèque
static func hand_pose() -> Dictionary:
	var out := {}
	var f := FileAccess.open("res://assets/animations/hand_poses.json", FileAccess.READ)
	if f == null:
		return out
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	for k in data["Sword_Idle"]:
		var a: Array = data["Sword_Idle"][k]
		out[k] = Quaternion(a[0], a[1], a[2], a[3])
	return out


static func build_library(skel: Skeleton3D) -> AnimationLibrary:
	if _cache != null:
		return _cache
	var t0 := Time.get_ticks_usec()
	var s := PoseSolver.new(skel, hand_pose())
	var lib := AnimationLibrary.new()
	var g := guard()
	var gr := grip()
	var g2 := m(g, {"hips": (g["hips"] as Vector3) + Vector3(0, -0.012, 0), "spine": Vector3(13, 0, 0)})
	var gr2 := m(gr, {"hips": (gr["hips"] as Vector3) + Vector3(0, -0.012, 0), "spine": Vector3(16, 0, 0)})
	lib.add_animation("guard", s.make_animation([[0.0, g], [1.2, g2], [2.4, g]], 2.4, true))
	lib.add_animation("grip_idle", s.make_animation([[0.0, gr], [1.0, gr2], [2.0, gr]], 2.0, true))
	lib.add_animation("stand", s.make_animation([[0.0, stand()], [1.0, stand()]], 1.0, true))
	lib.add_animation("defend", s.make_animation([[0.0, defend()], [1.0, defend()]], 1.0, true))
	var dirs := {"fwd": Vector2(0, 1), "back": Vector2(0, -1), "left": Vector2(1, 0), "right": Vector2(-1, 0)}
	for d in dirs:
		var sp := 0.62 if d in ["left", "right"] else 0.8
		lib.add_animation("walk_" + d, s.make_animation(_walk(g, dirs[d], sp, 0.6), 0.6, true))
		lib.add_animation("gwalk_" + d, s.make_animation(_walk(gr, dirs[d], sp * 0.8, 0.7), 0.7, true))
	lib.add_animation("osoto_tori", s.make_animation(osoto_tori(), 2.6, false))
	lib.add_animation("osoto_uke", s.make_animation(osoto_uke(), 2.1, false))
	lib.add_animation("down", s.make_animation([[0.0, lying()], [1.0, lying()]], 1.0, true))
	lib.add_animation("getup", s.make_animation(getup(), 1.4, false))
	lib.add_animation("rei", s.make_animation(rei(), 2.6, false))
	lib.add_animation("victory", s.make_animation(victory(), 1.7, true))
	lib.add_animation("defeat", s.make_animation(defeat(), 2.0, false))
	lib.add_animation("kuzushi_back", s.make_animation(kuzushi_back(), 0.7, false))
	lib.add_animation("kuzushi_fwd", s.make_animation(kuzushi_fwd(), 0.7, false))
	lib.add_animation("attack_blocked", s.make_animation(attack_blocked(), 1.1, false))
	lib.add_animation("defend_block", s.make_animation(defend_block(), 1.1, false))
	lib.add_animation("pin_tori", s.make_animation(pin_tori(), 1.6, true))
	lib.add_animation("pinned_uke", s.make_animation(pinned_uke(), 0.9, true))
	print("[JudoAnims] %d animations générées en %.1f ms" % [lib.get_animation_list().size(), (Time.get_ticks_usec() - t0) / 1000.0])
	_cache = lib
	return lib
