extends SceneTree
## Extrait la pose des doigts (main fermée) de l'animation CC0 « Idle » de Quaternius.
## Usage : godot --headless --path . --script tools/extract_fist.gd
func _initialize():
	var a = load("res://assets/animations/UAL1_Standard.glb").instantiate()
	var ap: AnimationPlayer = a.find_child("AnimationPlayer", true, false)
	var out := {}
	for anim_name in ["Idle", "Sword_Idle"]:
		var an := ap.get_animation(anim_name)
		var d := {}
		for t in an.get_track_count():
			if an.track_get_type(t) != Animation.TYPE_ROTATION_3D: continue
			var bone := String(an.track_get_path(t).get_concatenated_subnames())
			if not (bone.begins_with("index") or bone.begins_with("middle") or bone.begins_with("ring") or bone.begins_with("pinky") or bone.begins_with("thumb")): continue
			var q: Quaternion = an.rotation_track_interpolate(t, 0.0)
			d[bone] = [q.x, q.y, q.z, q.w]
		out[anim_name] = d
	var f := FileAccess.open("res://assets/animations/hand_poses.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("OK ", out["Idle"].size(), " ", out["Sword_Idle"].size())
	a.free()
	quit()
