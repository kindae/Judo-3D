extends SceneTree
## Lance une scène, capture des images et mesure les statistiques de rendu.
## godot --path . --script tools/capture.gd -- <menu|match|training> <t1,t2,...> <prefixe> [autoplay] [qualite 0-2]
var args: PackedStringArray
var times: PackedFloat64Array = []
var ti := 0
var t := 0.0
var frames := 0
var dts: Array[float] = []
var draws: Array[float] = []
var prims: Array[float] = []
func _start():
	var game = root.get_node("/root/Game")
	var settings = root.get_node("/root/Settings")
	game.autoplay = args.size() > 3 and args[3] == "autoplay"
	if args.size() > 4:
		settings.quality = int(args[4])
		settings.apply()
	if args[0] == "menu":
		change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		game.mode = 1 if args[0] == "training" else 0
		change_scene_to_file("res://scenes/match.tscn")
func _initialize():
	args = OS.get_cmdline_user_args()
	for x in args[1].split(","): times.append(float(x))
func _process(dt):
	if frames == 0: _start()
	t += dt
	frames += 1
	if frames > 30:
		dts.append(dt)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if ti < times.size() and t >= times[ti]:
		if args[2] != "-":
			root.get_texture().get_image().save_png("%s_%02d.png" % [args[2], ti])
		ti += 1
		if ti >= times.size():
			var s := 0.0
			for x in dts: s += x
			dts.sort()
			var p95 := dts[int(dts.size() * 0.95)] if dts.size() > 0 else 0.0
			var dmax := 0.0; var dsum := 0.0; var pmax := 0.0; var psum := 0.0
			for i in draws.size():
				dmax = maxf(dmax, draws[i]); dsum += draws[i]; pmax = maxf(pmax, prims[i]); psum += prims[i]
			var n := maxi(1, draws.size())
			print("MEASURE renderer=%s quality=%s frames=%d avg_ms=%.2f p95_ms=%.2f draws_avg=%.0f draws_max=%.0f prims_avg=%.0f prims_max=%.0f vram_mb=%.1f static_mem_mb=%.1f" % [
				RenderingServer.get_current_rendering_method(), root.get_node("/root/Settings").quality_name(), frames,
				1000.0 * s / n, 1000.0 * p95, dsum / n, dmax, psum / n, pmax,
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
				Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
			quit()
	return false
