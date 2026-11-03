extends Control
## Simple clock glyph for the loss popup — no external art required.

func _ready() -> void:
	custom_minimum_size = Vector2(88, 88)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.42
	draw_circle(center, radius + 4.0, Color("0d1816"))
	draw_circle(center, radius, Color("243834"))
	draw_arc(center, radius, 0.0, TAU, 64, Color("d6b56a"), 3.0, true)
	for i in range(12):
		var angle := -PI * 0.5 + float(i) * TAU / 12.0
		var outer := center + Vector2(cos(angle), sin(angle)) * (radius - 4.0)
		var inner := center + Vector2(cos(angle), sin(angle)) * (radius - (12.0 if i % 3 == 0 else 8.0))
		draw_line(inner, outer, Color("e8d7a4"), 2.0 if i % 3 == 0 else 1.2, true)
	# Hands frozen at mismatched times — past and future out of sync.
	var hour := center + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * (radius * 0.42)
	var minute := center + Vector2(cos(PI * 0.72), sin(PI * 0.72)) * (radius * 0.68)
	draw_line(center, hour, Color("f0e2b0"), 3.2, true)
	draw_line(center, minute, Color("c9a24a"), 2.2, true)
	draw_circle(center, 3.5, Color("f3e7c0"))
