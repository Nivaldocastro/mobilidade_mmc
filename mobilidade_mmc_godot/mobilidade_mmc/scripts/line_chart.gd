extends Control
## Gráfico simples: tamanho da fila ao longo do tempo simulado + linha do Lq teórico.

var data: PackedFloat32Array = PackedFloat32Array()
var ref_line: float = -1.0            # Lq teórico (< 0 = não desenhar)
var title: String = "Tamanho da fila ao longo do tempo"
var max_points: int = 480
var sample_seconds: float = 15.0


func add_point(v: float) -> void:
	data.append(v)
	if data.size() > max_points:
		data = data.slice(data.size() - max_points)
	queue_redraw()


func clear_data() -> void:
	data = PackedFloat32Array()
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.10, 0.12), true)

	var pad_l: float = 38.0
	var pad_r: float = 10.0
	var pad_t: float = 24.0
	var pad_b: float = 20.0
	var pw: float = size.x - pad_l - pad_r
	var ph: float = size.y - pad_t - pad_b
	if pw <= 20.0 or ph <= 20.0:
		return

	draw_string(font, Vector2(8, 16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.92, 0.92, 0.96))

	var ymax: float = 1.0
	for v in data:
		ymax = maxf(ymax, v)
	if ref_line > 0.0:
		ymax = maxf(ymax, ref_line)
	ymax = ceilf(ymax * 1.15)

	for g in range(5):
		var gy: float = pad_t + ph - ph * float(g) / 4.0
		draw_line(Vector2(pad_l, gy), Vector2(pad_l + pw, gy), Color(1, 1, 1, 0.08), 1.0)
		draw_string(font, Vector2(4, gy + 4.0), "%d" % int(round(ymax * float(g) / 4.0)),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.7, 0.75))

	if data.size() >= 2:
		var pts: PackedVector2Array = PackedVector2Array()
		var n: int = data.size()
		for i in range(n):
			var x: float = pad_l + pw * float(i) / float(max_points - 1)
			var y: float = pad_t + ph - ph * data[i] / ymax
			pts.append(Vector2(x, y))
		draw_polyline(pts, Color(0.31, 0.64, 1.0), 2.0)

	if ref_line > 0.0:
		var ry: float = pad_t + ph - ph * ref_line / ymax
		draw_dashed_line(Vector2(pad_l, ry), Vector2(pad_l + pw, ry), Color(1.0, 0.70, 0.28), 1.5, 6.0)
		draw_string(font, Vector2(pad_l + 6.0, ry - 4.0), "Lq teórico = %.2f" % ref_line,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.70, 0.28))

	var window_min: float = float(max_points) * sample_seconds / 60.0
	draw_string(font, Vector2(pad_l, size.y - 5.0), "janela: %d min simulados" % int(window_min),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.7, 0.75))
