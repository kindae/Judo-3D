extends SceneTree
## Charge chaque script pour détecter les erreurs de compilation.
func _initialize():
	var bad := 0
	for d in ["res://scripts/autoload", "res://scripts/core", "res://scripts/fighter", "res://scripts/ai", "res://scripts/camera", "res://scripts/ui", "res://scripts/env", "res://scripts/input"]:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				var s = load(d + "/" + f)
				if s == null or not s.can_instantiate():
					print("FAIL ", d, "/", f); bad += 1
	print("CHECK DONE bad=", bad)
	quit()
