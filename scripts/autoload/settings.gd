extends Node
## Réglages persistants (user://settings.cfg) et application des profils graphiques.

signal changed

enum Quality { LOW, MEDIUM, HIGH }
enum Difficulty { EASY, NORMAL, HARD }

const PATH := "user://settings.cfg"

var quality: int = Quality.MEDIUM
var battery_saver := false     # 30 FPS
var slow_motion := true        # ralenti sur ippon
var show_perf := false         # surcouche de mesures (F3)
var difficulty: int = Difficulty.NORMAL
var touch_controls := true
var belt_color := "black"

const BELTS := {
	"white": Color(0.93, 0.93, 0.9), "yellow": Color(0.95, 0.8, 0.1), "orange": Color(0.95, 0.45, 0.08),
	"green": Color(0.1, 0.55, 0.2), "blue": Color(0.1, 0.3, 0.8), "brown": Color(0.35, 0.2, 0.1),
	"black": Color(0.04, 0.04, 0.04), "red_white": Color(0.8, 0.1, 0.1),
}
const BELT_NAMES := {
	"white": "Blanche", "yellow": "Jaune", "orange": "Orange", "green": "Verte",
	"blue": "Bleue", "brown": "Marron", "black": "Noire", "red_white": "Rouge et blanche",
}


func _ready() -> void:
	load_settings()
	if OS.has_feature("mobile"):
		touch_controls = true
	apply()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		# premier lancement : profil choisi selon la plateforme
		quality = Quality.MEDIUM if OS.has_feature("mobile") else Quality.HIGH
		return
	quality = cf.get_value("video", "quality", quality)
	battery_saver = cf.get_value("video", "battery_saver", battery_saver)
	slow_motion = cf.get_value("video", "slow_motion", slow_motion)
	show_perf = cf.get_value("video", "show_perf", show_perf)
	difficulty = cf.get_value("game", "difficulty", difficulty)
	touch_controls = cf.get_value("game", "touch_controls", touch_controls)
	belt_color = cf.get_value("game", "belt_color", belt_color)


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("video", "quality", quality)
	cf.set_value("video", "battery_saver", battery_saver)
	cf.set_value("video", "slow_motion", slow_motion)
	cf.set_value("video", "show_perf", show_perf)
	cf.set_value("game", "difficulty", difficulty)
	cf.set_value("game", "touch_controls", touch_controls)
	cf.set_value("game", "belt_color", belt_color)
	cf.save(PATH)


func set_value(key: String, value) -> void:
	set(key, value)
	save_settings()
	apply()


## Paramètres du profil graphique courant.
func profile() -> Dictionary:
	match quality:
		Quality.LOW:
			return {"scale": 0.67, "msaa": Viewport.MSAA_DISABLED, "fxaa": true, "shadows": false,
				"shadow_size": 1024, "glow": false, "fill_light": false, "decor": false, "tex_detail": false}
		Quality.HIGH:
			return {"scale": 1.0, "msaa": Viewport.MSAA_2X, "fxaa": false, "shadows": true,
				"shadow_size": 2048, "glow": true, "fill_light": true, "decor": true, "tex_detail": true}
		_:
			return {"scale": 0.85, "msaa": Viewport.MSAA_DISABLED, "fxaa": true, "shadows": true,
				"shadow_size": 1024, "glow": true, "fill_light": false, "decor": true, "tex_detail": true}


func apply() -> void:
	Engine.max_fps = 30 if battery_saver else 60
	var p := profile()
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = p["scale"]
	vp.msaa_3d = p["msaa"]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if p["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(p["shadow_size"], true)
	changed.emit()


func quality_name(q: int = -1) -> String:
	if q < 0:
		q = quality
	return ["Faible", "Moyen", "Élevé"][q]


func difficulty_name(d: int = -1) -> String:
	if d < 0:
		d = difficulty
	return ["Facile", "Normale", "Difficile"][d]
