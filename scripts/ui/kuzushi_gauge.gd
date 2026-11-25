class_name KuzushiGauge
extends Control
## Petit indicateur du déséquilibre de l'adversaire (vu de dessus, avant = haut).
## Aide le joueur à choisir le moment de projeter.

var match_node: Match


func _ready() -> void:
	custom_minimum_size = Vector2(120, 120)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if match_node == null:
		return
	var k: Vector2 = match_node.cpu.kuzushi
	var c := size / 2.0
	var r := 46.0
	draw_circle(c, r + 8, Color(0.06, 0.07, 0.09, 0.7))
	draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.25), 2.0, true)
	draw_arc(c, r * 0.4, 0, TAU, 32, Color(1, 1, 1, 0.12), 1.5, true)
	# zone favorable à O-soto-gari (arrière d'uke = bas de la jauge)
	draw_arc(c, r, PI * 0.25, PI * 0.75, 16, Color(0.95, 0.35, 0.25, 0.8), 5.0, true)
	var p := c + Vector2(-k.x, -k.y) * r
	var col := Color(0.4, 0.9, 0.5) if k.length() < 0.35 else (Color(1.0, 0.8, 0.25) if k.length() < 0.6 else Color(1.0, 0.35, 0.25))
	draw_line(c, p, col, 3.0, true)
	draw_circle(p, 7, col)
	var font := get_theme_default_font()
	draw_string(font, Vector2(4, size.y + 6), "Déséquilibre adverse", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.75))
