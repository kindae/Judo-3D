class_name Scoreboard
extends RefCounted
## Tableau de marque inspiré des Règles d'arbitrage FIJ (Sport and Organisation Rules,
## version 2026) :
##  - combat de 4 minutes de temps réel ;
##  - ippon : victoire immédiate ; deux waza-ari = ippon (waza-ari-awasete-ippon) ;
##  - yuko : se compte (1, 2, 3...) mais ne s'additionne jamais en waza-ari ;
##  - osaekomi : 5-9 s yuko, 10-19 s waza-ari, 20 s ippon ;
##    en golden score, 5 s d'osaekomi donnent yuko et mettent fin au combat ;
##  - shido (pénalité, jamais un point) ; 3e shido = hansoku-make (défaite) ;
##  - égalité de scores techniques à la fin : golden score sans limite de temps,
##    scores et shido conservés ; le premier score technique gagne.

const REGULAR_TIME := 240.0

var ippon := [false, false]
var wazaari := [0, 0]
var yuko := [0, 0]
var shido := [0, 0]
var hansoku := [false, false]
var time_left := REGULAR_TIME
var golden_score := false
var golden_time := 0.0
var winner := -1
var win_reason := ""


func is_over() -> bool:
	return winner >= 0


## Ajoute un score technique. Retourne le libellé annoncé par l'arbitre.
func add_score(side: int, kind: String) -> String:
	if is_over():
		return ""
	match kind:
		"ippon":
			ippon[side] = true
			_finish(side, "Ippon")
			return "IPPON !"
		"waza-ari":
			wazaari[side] += 1
			if wazaari[side] >= 2:
				ippon[side] = true
				_finish(side, "Waza-ari-awasete-ippon")
				return "WAZA-ARI-AWASETE-IPPON !"
			if golden_score:
				_finish(side, "Waza-ari (golden score)")
			return "WAZA-ARI !"
		"yuko":
			yuko[side] += 1
			if golden_score:
				_finish(side, "Yuko (golden score)")
			return "YUKO !"
	return ""


func add_shido(side: int) -> String:
	if is_over():
		return ""
	shido[side] += 1
	if shido[side] >= 3:
		hansoku[side] = true
		_finish(1 - side, "Hansoku-make (3 shido)")
		return "HANSOKU-MAKE !"
	return "SHIDO"


## Score d'osaekomi selon la durée tenue (en secondes).
func osaekomi_result(seconds: float) -> String:
	if golden_score:
		return "yuko" if seconds >= 5.0 else ""
	if seconds >= 20.0:
		return "ippon"
	if seconds >= 10.0:
		return "waza-ari"
	if seconds >= 5.0:
		return "yuko"
	return ""


## Durée d'osaekomi qui met fin à l'immobilisation (score maximal atteint).
func osaekomi_limit() -> float:
	return 5.0 if golden_score else 20.0


## Compare les scores techniques : 1 si side 0 mène, -1 si side 1 mène, 0 si égalité.
func compare() -> int:
	for arr in [ippon, wazaari, yuko]:
		var a = int(arr[0]) if arr[0] is bool else arr[0]
		var b = int(arr[1]) if arr[1] is bool else arr[1]
		if a != b:
			return 1 if a > b else -1
	return 0


## Fin du temps réglementaire. Retourne true si on passe en golden score.
func on_time_up() -> bool:
	var c := compare()
	if c == 0:
		golden_score = true
		return true
	_finish(0 if c > 0 else 1, "Décision aux points")
	return false


func _finish(side: int, reason: String) -> void:
	winner = side
	win_reason = reason
