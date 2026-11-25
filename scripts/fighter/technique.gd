class_name Technique
extends RefCounted
## Description d'une technique de judo.
##
## kuzushi_dir : direction du déséquilibre d'uke qui favorise la technique, dans le
##   repère d'uke (y > 0 : vers l'avant, y < 0 : vers l'arrière, x : côté).
## Une technique sans animation (implemented = false) est listée mais pas encore jouable.

var id := ""
var name := ""
var family := ""          # ashi-waza, koshi-waza, te-waza, osaekomi-waza
var kuzushi_dir := Vector2.ZERO
var min_kuzushi := 0.15   # déséquilibre minimal pour avoir une chance de réussir
var stamina_cost := 18.0
var defend_window := 0.38 # secondes pendant lesquelles uke peut bloquer
var duration := 2.1
var anim_tori := ""
var anim_uke := ""
var power := 1.0          # multiplicateur de qualité
var implemented := false
var description := ""


static func make(d: Dictionary) -> Technique:
	var t := Technique.new()
	for k in d:
		t.set(k, d[k])
	return t


## Base de données des techniques (ordre d'implémentation progressive).
static func all() -> Array[Technique]:
	var list: Array[Technique] = [
		make({"id": "o_soto_gari", "name": "O-soto-gari", "family": "ashi-waza",
			"kuzushi_dir": Vector2(0.3, -1.0), "min_kuzushi": 0.15, "stamina_cost": 18.0,
			"defend_window": 0.38, "duration": 2.1, "anim_tori": "osoto_tori", "anim_uke": "osoto_uke",
			"implemented": true,
			"description": "Grand fauchage extérieur. Déséquilibrer uke vers l'arrière (pousser) puis faucher sa jambe d'appui."}),
		make({"id": "o_goshi", "name": "O-goshi", "family": "koshi-waza",
			"kuzushi_dir": Vector2(0, 1), "stamina_cost": 22.0,
			"description": "Grande projection de hanche. Déséquilibre vers l'avant."}),
		make({"id": "ippon_seoi_nage", "name": "Ippon-seoi-nage", "family": "te-waza",
			"kuzushi_dir": Vector2(0, 1), "stamina_cost": 24.0,
			"description": "Projection par-dessus l'épaule. Déséquilibre vers l'avant."}),
		make({"id": "de_ashi_barai", "name": "De-ashi-barai", "family": "ashi-waza",
			"kuzushi_dir": Vector2(1, 0), "stamina_cost": 10.0, "defend_window": 0.25,
			"description": "Balayage du pied avancé, au moment où uke déplace son poids."}),
		make({"id": "ko_uchi_gari", "name": "Ko-uchi-gari", "family": "ashi-waza",
			"kuzushi_dir": Vector2(0, -1), "stamina_cost": 12.0,
			"description": "Petit fauchage intérieur. Déséquilibre vers l'arrière."}),
		make({"id": "uchi_mata", "name": "Uchi-mata", "family": "ashi-waza",
			"kuzushi_dir": Vector2(0, 1), "stamina_cost": 24.0,
			"description": "Fauchage par l'intérieur de la cuisse. Déséquilibre vers l'avant."}),
		make({"id": "tai_otoshi", "name": "Tai-otoshi", "family": "te-waza",
			"kuzushi_dir": Vector2(0.5, 1), "stamina_cost": 16.0,
			"description": "Renversement du corps devant la jambe tendue. Déséquilibre avant-droit."}),
		make({"id": "kesa_gatame", "name": "Kesa-gatame", "family": "osaekomi-waza",
			"stamina_cost": 8.0, "implemented": true,
			"description": "Immobilisation en écharpe. Disponible quand l'adversaire est au sol."}),
	]
	return list


static func by_id(tid: String) -> Technique:
	for t in all():
		if t.id == tid:
			return t
	return null
