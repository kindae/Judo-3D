extends Node
## Navigation entre les écrans, mode de jeu choisi, mise en veille en arrière-plan.

enum Mode { QUICK_MATCH, TRAINING }
# Modes prévus (architecture prête, non implémentés) : CAREER, TOURNAMENT.

var mode: int = Mode.QUICK_MATCH
## Démo / tests automatiques : le judoka du joueur est aussi piloté par l'IA.
var autoplay := false
## Données pour une future progression (carrière, tournois, grades) — persistées à part.
var profile_data := {"grade": "white", "wins": 0, "losses": 0}

const MENU := "res://scenes/main_menu.tscn"
const MATCH := "res://scenes/match.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(true)
	get_tree().set_quit_on_go_back(false)


func start_match(m: int) -> void:
	mode = m
	get_tree().paused = false
	get_tree().change_scene_to_file(MATCH)


func to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MENU)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			# arrière-plan : on met le combat en pause et on réduit la cadence au minimum
			Engine.max_fps = 5
			var cur := get_tree().current_scene
			if cur and cur.has_method("request_pause"):
				cur.request_pause()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			Engine.max_fps = 30 if Settings.battery_saver else 60
		NOTIFICATION_WM_GO_BACK_REQUEST:
			var cur := get_tree().current_scene
			if cur and cur.has_method("on_back"):
				cur.on_back()
