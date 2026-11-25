class_name Dojo
extends Node3D
## Dojo moderne construit par code : tatami réglementaire, murs, plafond, fenêtres
## shoji, gradins, décorations, éclairage et environnement.
##
## Tatami : aire de combat 8 x 8 m + zone de sécurité de 3 m (14 x 14 m au total),
## dalles de 1 x 2 m, deux couleurs distinctes (règle FIJ : couleurs différentes
## entre aire de combat et zone de sécurité).

const CONTEST_HALF := 4.0
const SAFETY := 3.0
const TATAMI_H := 0.06
const HALL := Vector3(26.0, 7.5, 24.0)
const START_X := 2.0   # marques de départ à 4 m l'une de l'autre

var light: DirectionalLight3D
var fill: DirectionalLight3D
var env: Environment

static var _mat_cache := {}


func _ready() -> void:
	build()
	Settings.changed.connect(_apply_quality)


func build() -> void:
	_environment()
	_floor()
	_tatami()
	_walls()
	_ceiling()
	_bleachers()
	if Settings.profile()["decor"]:
		_decorations()
	_apply_quality()


func _apply_quality() -> void:
	var p := Settings.profile()
	if light:
		light.shadow_enabled = p["shadows"]
	if fill:
		fill.visible = p["fill_light"]
	if env:
		env.glow_enabled = p["glow"]


# ------------------------------------------------------------------ matériaux
func tex_mat(base: String, uv: Vector2, tint := Color.WHITE, rough := 1.0) -> StandardMaterial3D:
	var key := "%s_%s_%s_%s" % [base, uv, tint.to_html(), rough]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/%s_albedo.jpg" % base)
	m.albedo_color = tint
	m.roughness = rough
	if Settings.profile()["tex_detail"]:
		m.normal_enabled = true
		m.normal_texture = load("res://assets/textures/%s_normal.jpg" % base)
		m.roughness_texture = load("res://assets/textures/%s_rough.jpg" % base)
	m.uv1_scale = Vector3(uv.x, uv.y, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat_cache[key] = m
	return m


func flat_mat(c: Color, rough := 0.8, emission := 0.0, metal := 0.0) -> StandardMaterial3D:
	var key := "flat_%s_%s_%s_%s" % [c.to_html(), rough, emission, metal]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	_mat_cache[key] = m
	return m


func box(size: Vector3, pos: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func plane(size: Vector2, pos: Vector3, rot_deg: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = size
	mi.mesh = q
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# ------------------------------------------------------------------ éléments
func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.085, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.74, 0.68)
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true   # étalonnage léger
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.05
	env.adjustment_brightness = 1.0
	we.environment = env
	add_child(we)

	light = DirectionalLight3D.new()   # lumière du jour venant des fenêtres
	light.name = "Sun"
	light.rotation_degrees = Vector3(-52, -35, 0)
	light.light_color = Color(1.0, 0.95, 0.86)
	light.light_energy = 1.25
	light.shadow_enabled = true
	light.shadow_bias = 0.03
	light.shadow_normal_bias = 1.2
	light.shadow_blur = 1.0
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 14.0
	add_child(light)

	fill = DirectionalLight3D.new()    # lumière artificielle froide (sans ombre)
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-70, 150, 0)
	fill.light_color = Color(0.82, 0.88, 1.0)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	add_child(fill)


func _floor() -> void:
	plane(Vector2(HALL.x, HALL.z), Vector3.ZERO, Vector3.ZERO, tex_mat("floor_wood", Vector2(HALL.x / 2.0, HALL.z / 2.0), Color(1, 1, 1), 0.9))
	# socle sombre sous le tatami (visible dans les joints)
	box(Vector3(14.1, 0.02, 14.1), Vector3(0, 0.011, 0), flat_mat(Color(0.05, 0.05, 0.05)))


func _tatami() -> void:
	var total := (CONTEST_HALF + SAFETY) * 2.0   # 14 m
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.992, TATAMI_H - 0.02, 1.992)
	var mat := tex_mat("tatami", Vector2(1, 1), Color.WHITE, 0.85)
	var mm_mat: StandardMaterial3D = mat.duplicate()
	mm_mat.vertex_color_use_as_albedo = true
	mesh.material = mm_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var contest := Color(1.0, 0.95, 0.80)       # jaune paille
	var safety := Color(0.42, 0.62, 0.52)       # vert
	# dalles de 1 x 2 m disposées en rangées alternées
	for row in int(total / 2.0):
		for col in int(total):
			var x := -total / 2.0 + col + 0.5
			var z := -total / 2.0 + row * 2.0 + 1.0
			var inside := absf(x) < CONTEST_HALF and absf(z) < CONTEST_HALF
			var t := Transform3D(Basis.IDENTITY, Vector3(x, 0.02 + (TATAMI_H - 0.02) / 2.0, z))
			xforms.append(t)
			var c := contest if inside else safety
			var v := 0.96 + fmod(absf(sin(col * 12.9898 + row * 78.233) * 43758.5453), 1.0) * 0.06
			colors.append(Color(c.r * v, c.g * v, c.b * v))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.name = "Tatami"
	add_child(mmi)
	# marques de départ (bleue et blanche) et limite rouge de l'aire de combat
	var y := TATAMI_H + 0.002
	box(Vector3(0.08, 0.004, 0.5), Vector3(-START_X, y, 0), flat_mat(Color(0.95, 0.95, 0.95), 0.6))
	box(Vector3(0.08, 0.004, 0.5), Vector3(START_X, y, 0), flat_mat(Color(0.1, 0.3, 0.85), 0.6))
	var red := flat_mat(Color(0.75, 0.1, 0.08), 0.7)
	for s: float in [-1.0, 1.0]:
		box(Vector3(CONTEST_HALF * 2 + 0.1, 0.004, 0.05), Vector3(0, y, s * CONTEST_HALF), red)
		box(Vector3(0.05, 0.004, CONTEST_HALF * 2 + 0.1), Vector3(s * CONTEST_HALF, y, 0), red)


func _walls() -> void:
	var hx := HALL.x / 2.0
	var hz := HALL.z / 2.0
	var h := HALL.y
	var plaster := tex_mat("wall_plaster", Vector2(6, 2), Color(0.96, 0.94, 0.9), 0.95)
	var wood := tex_mat("wood_panel", Vector2(8, 1), Color(0.85, 0.7, 0.55), 0.7)
	# murs (plans orientés vers l'intérieur)
	plane(Vector2(HALL.x, h), Vector3(0, h / 2, -hz), Vector3(90, 0, 0), plaster)
	plane(Vector2(HALL.x, h), Vector3(0, h / 2, hz), Vector3(-90, 0, 0), plaster)
	plane(Vector2(h, HALL.z), Vector3(-hx, h / 2, 0), Vector3(0, 0, -90), plaster)
	plane(Vector2(h, HALL.z), Vector3(hx, h / 2, 0), Vector3(0, 0, 90), plaster)
	# soubassement en bois et plinthes
	for s: float in [-1.0, 1.0]:
		box(Vector3(HALL.x, 1.2, 0.06), Vector3(0, 0.6, s * (hz - 0.03)), wood)
		box(Vector3(0.06, 1.2, HALL.z), Vector3(s * (hx - 0.03), 0.6, 0), wood)
	# fenêtres shoji (lumière naturelle) sur le mur nord
	var paper := tex_mat("shoji_paper", Vector2(1, 1), Color(1.0, 0.97, 0.9), 1.0)
	paper.emission_enabled = true
	paper.emission = Color(1.0, 0.94, 0.82)
	paper.emission_energy_multiplier = 1.6
	paper.emission_texture = paper.albedo_texture
	var frame := flat_mat(Color(0.25, 0.16, 0.1), 0.6)
	for i in 5:
		var x := -9.0 + i * 4.5
		box(Vector3(3.2, 2.6, 0.04), Vector3(x, 4.1, -hz + 0.05), paper)
		for k in 5:  # quadrillage
			box(Vector3(0.05, 2.6, 0.06), Vector3(x - 1.6 + k * 0.8, 4.1, -hz + 0.08), frame)
		for k in 4:
			box(Vector3(3.2, 0.05, 0.06), Vector3(x, 2.8 + k * 0.866, -hz + 0.08), frame)
	# poteaux de structure
	var post := tex_mat("wood_panel", Vector2(1, 4), Color(0.55, 0.38, 0.25), 0.6)
	for x: float in [-11.0, -6.0, 0.0, 6.0, 11.0]:
		for s: float in [-1.0, 1.0]:
			box(Vector3(0.35, h, 0.35), Vector3(x, h / 2, s * (hz - 0.18)), post)


func _ceiling() -> void:
	var h := HALL.y
	plane(Vector2(HALL.x, HALL.z), Vector3(0, h, 0), Vector3(180, 0, 0), flat_mat(Color(0.85, 0.83, 0.8), 1.0))
	var beam := tex_mat("wood_panel", Vector2(6, 1), Color(0.5, 0.35, 0.22), 0.6)
	for i in 9:
		box(Vector3(0.3, 0.4, HALL.z), Vector3(-12.0 + i * 3.0, h - 0.2, 0), beam)
	# panneaux lumineux (éclairage artificiel)
	var panel := flat_mat(Color(1.0, 0.98, 0.94), 0.5, 2.2)
	for i in 4:
		for j in 3:
			box(Vector3(2.0, 0.05, 1.0), Vector3(-6.0 + i * 4.0 - 1.5 + 1.5, h - 0.45, -5.0 + j * 5.0), panel)


func _bleachers() -> void:
	# gradins simples des deux côtés (sud et nord)
	var step := tex_mat("wood_panel", Vector2(6, 0.5), Color(0.72, 0.56, 0.42), 0.7)
	var seat := flat_mat(Color(0.12, 0.2, 0.38), 0.55)
	var hz := HALL.z / 2.0
	for s: float in [-1.0, 1.0]:
		for t in 4:
			var depth := 0.8
			var z := s * (hz - 0.6 - (3 - t) * depth)
			var hgt := 0.45 * (t + 1)
			box(Vector3(18.0, hgt, depth), Vector3(0, hgt / 2.0, z), step)
			box(Vector3(17.6, 0.06, 0.38), Vector3(0, hgt + 0.03, z + s * 0.12), seat)


func _decorations() -> void:
	var hx := HALL.x / 2.0
	# bannières suspendues aux extrémités
	var cols := [Color(0.72, 0.08, 0.08), Color(0.95, 0.95, 0.92), Color(0.08, 0.16, 0.42)]
	for s: float in [-1.0, 1.0]:
		for i in 3:
			box(Vector3(0.03, 3.2, 1.1), Vector3(s * (hx - 0.12), 4.6, -2.6 + i * 2.6), flat_mat(cols[i], 0.9))
			box(Vector3(0.06, 0.06, 1.3), Vector3(s * (hx - 0.12), 6.25, -2.6 + i * 2.6), flat_mat(Color(0.3, 0.2, 0.12), 0.5))
		# tableau d'affichage
		box(Vector3(0.12, 1.3, 3.2), Vector3(s * (hx - 0.1), 2.35, 7.2), flat_mat(Color(0.03, 0.03, 0.04), 0.3))
		box(Vector3(0.02, 1.1, 1.4), Vector3(s * (hx - 0.17), 2.35, 6.4), flat_mat(Color(0.9, 0.9, 0.88), 0.4, 0.6))
		box(Vector3(0.02, 1.1, 1.4), Vector3(s * (hx - 0.17), 2.35, 8.0), flat_mat(Color(0.1, 0.3, 0.85), 0.4, 0.9))
		# horloge
		var clock := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.35
		cyl.bottom_radius = 0.35
		cyl.height = 0.06
		clock.mesh = cyl
		clock.material_override = flat_mat(Color(0.95, 0.95, 0.95), 0.4)
		clock.position = Vector3(s * (hx - 0.06), 5.2, 7.2)
		clock.rotation_degrees = Vector3(0, 0, 90)
		add_child(clock)
	# table de marque, chaises et bouteilles en bord de tatami
	var table_mat := flat_mat(Color(0.18, 0.18, 0.2), 0.5)
	box(Vector3(2.4, 0.06, 0.8), Vector3(0, 0.75, 8.1), table_mat)
	box(Vector3(2.4, 0.7, 0.04), Vector3(0, 0.38, 7.72), flat_mat(Color(0.08, 0.16, 0.42), 0.7))
	for i in 3:
		var x := -0.8 + i * 0.8
		box(Vector3(0.45, 0.05, 0.45), Vector3(x, 0.46, 8.75), flat_mat(Color(0.1, 0.1, 0.1), 0.5))
		box(Vector3(0.45, 0.5, 0.05), Vector3(x, 0.72, 8.97), flat_mat(Color(0.1, 0.1, 0.1), 0.5))
		box(Vector3(0.18, 0.1, 0.12), Vector3(x, 0.83, 8.0), flat_mat(Color(0.25, 0.25, 0.28), 0.3, 0.0, 0.6))
	for i in 4:
		box(Vector3(0.07, 0.24, 0.07), Vector3(7.6, 0.18, -2.0 + i * 0.12), flat_mat(Color(0.2, 0.55, 0.9, 1.0), 0.15))
	# pile de tatamis de réserve et sac de frappe dans un coin
	for i in 6:
		box(Vector3(1.0, 0.04, 2.0), Vector3(-10.6, 0.02 + i * 0.045, -8.5), flat_mat(Color(0.3, 0.5, 0.42), 0.85))
	var bag := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.22
	bc.bottom_radius = 0.22
	bc.height = 1.2
	bag.mesh = bc
	bag.material_override = flat_mat(Color(0.45, 0.08, 0.06), 0.6)
	bag.position = Vector3(10.6, 0.6, -8.4)
	add_child(bag)


## Point de départ (sur le tatami) d'un combattant.
static func start_position(side: int) -> Vector3:
	return Vector3(-START_X if side == 0 else START_X, TATAMI_H, 0.0)
