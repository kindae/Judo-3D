class_name PerfOverlay
extends Label
## Mesures réelles du moteur (F3 ou réglage) : FPS, temps d'image, appels de dessin,
## primitives, mémoire vidéo, moteur de rendu. Écrit aussi un résumé dans les logs
## toutes les 10 s (adb logcat -s godot) pour comparer avec d'autres jeux.

var _acc := 0.0
var _frames := 0
var _min_fps := 1e9
var _max_ms := 0.0
var _sum_ms := 0.0
var _log_t := 0.0


func _ready() -> void:
	position = Vector2(16, 0)
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	offset_top = -150
	offset_left = 16
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	add_theme_constant_override("outline_size", 4)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(dt: float) -> void:
	visible = Settings.show_perf
	var ms := dt * 1000.0 / maxf(Engine.time_scale, 0.01)
	_frames += 1
	_sum_ms += ms
	_max_ms = maxf(_max_ms, ms)
	_acc += dt
	_log_t += dt
	if _acc < 0.5:
		return
	var fps := Engine.get_frames_per_second()
	_min_fps = minf(_min_fps, fps)
	var avg := _sum_ms / maxf(_frames, 1)
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var cpu_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var renderer := RenderingServer.get_current_rendering_method()
	var res := get_viewport().get_visible_rect().size * get_viewport().scaling_3d_scale
	text = "FPS %d (min %d)  image %.1f ms moy / %.1f ms max\nCPU script %.2f ms  appels de dessin %d  primitives %d\nVRAM %.0f Mo  rendu %s %dx%d  profil %s  plafond %d FPS" % [
		fps, _min_fps, avg, _max_ms, cpu_ms, draws, prims, vram, renderer, res.x, res.y,
		Settings.quality_name(), Engine.max_fps]
	if _log_t >= 10.0:
		_log_t = 0.0
		print("[PERF] fps=%d min=%d avg_ms=%.2f max_ms=%.2f draws=%d prims=%d vram_mb=%.0f renderer=%s quality=%s" % [
			fps, _min_fps, avg, _max_ms, draws, prims, vram, renderer, Settings.quality_name()])
		_min_fps = 1e9
		_max_ms = 0.0
	_acc = 0.0
	_frames = 0
	_sum_ms = 0.0
