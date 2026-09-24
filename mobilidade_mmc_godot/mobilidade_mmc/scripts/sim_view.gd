extends Control
## Desenha o sistema M/M/c: fila única (FIFO) à esquerda e servidores (faixas/cabines) à direita.

const TYPE_NAMES := ["Carro", "Bicicleta", "Ônibus", "Caminhão"]
const TYPE_LEN := [1.0, 0.6, 1.6, 1.35]   # comprimento relativo de cada tipo

var sim = null   # MMcSimulation (definido pelo main.gd)
var type_colors: Array = [
	Color(0.31, 0.64, 1.0),    # carro
	Color(0.37, 0.82, 0.48),   # bicicleta
	Color(1.0, 0.70, 0.28),    # ônibus
	Color(0.88, 0.39, 0.36),   # caminhão
]


func _draw() -> void:
	var font: Font = get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.10, 0.12), true)
	if sim == null:
		return

	var w: float = size.x
	var h: float = size.y
	var top: float = 50.0
	var lanes: int = sim.lanes_visible()
	var lane_h: float = maxf((h - top - 8.0) / float(lanes), 4.0)
	var booth_w: float = clampf(w * 0.13, 64.0, 130.0)
	var booth_x: float = w - booth_w - 14.0
	var queue_right: float = booth_x - 10.0
	var queue_left: float = 12.0
	var veh_h: float = clampf(lane_h * 0.6, 5.0, 24.0)

	# ---- cabeçalho
	var header: String = "λ = %.2f veíc/min  >>  fila única FIFO  >>  c = %d servidores (μ = %.2f veíc/min cada)" % [
		sim.lam * 60.0, sim.c, sim.mu * 60.0]
	draw_string(font, Vector2(12, 18), header, HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, 13, Color(0.92, 0.92, 0.96))

	# ---- legenda
	var lx: float = 12.0
	for t in range(4):
		draw_rect(Rect2(lx, 29.0, 10.0, 10.0), type_colors[t], true)
		draw_string(font, Vector2(lx + 14.0, 38.0), str(TYPE_NAMES[t]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.85))
		lx += 96.0
	var counts: String = "Na fila: %d    Em atendimento: %d" % [sim.queue_size(), sim.busy_count()]
	draw_string(font, Vector2(0, 38.0), counts, HORIZONTAL_ALIGNMENT_RIGHT, w - 12.0, 12, Color(0.92, 0.92, 0.96))

	# ---- faixas e servidores
	for i in range(lanes):
		var y: float = top + float(i) * lane_h
		var lane_col: Color = Color(0.14, 0.15, 0.18) if i % 2 == 0 else Color(0.12, 0.13, 0.16)
		draw_rect(Rect2(0.0, y, w, lane_h), lane_col, true)

		var busy: bool = int(sim.srv_type[i]) >= 0
		var active: bool = i < sim.c
		var bcol: Color
		if not active:
			bcol = Color(0.35, 0.35, 0.38)     # fechando (termina o veículo atual)
		elif busy:
			bcol = Color(0.42, 0.16, 0.16)     # ocupado
		else:
			bcol = Color(0.14, 0.36, 0.20)     # livre
		var brect: Rect2 = Rect2(booth_x, y + 1.0, booth_w, lane_h - 2.0)
		draw_rect(brect, bcol, true)
		draw_rect(brect, Color(1, 1, 1, 0.25), false, 1.0)

		if busy:
			var t: int = int(sim.srv_type[i])
			var vw: float = veh_h * 1.6 * float(TYPE_LEN[t])
			var s: float = float(sim.srv_start[i])
			var e: float = float(sim.srv_end[i])
			var frac: float = clampf((sim.clock - s) / maxf(e - s, 0.0001), 0.0, 1.0)
			draw_rect(Rect2(booth_x + 6.0, y + (lane_h - veh_h) * 0.5, vw, veh_h), type_colors[t], true)
			draw_rect(Rect2(booth_x + 2.0, y + lane_h - 4.0, (booth_w - 4.0) * frac, 2.5), Color(1, 1, 1, 0.8), true)
		if lane_h >= 14.0:
			draw_string(font, Vector2(booth_x + booth_w - 28.0, y + lane_h * 0.5 + 4.0), "S%d" % (i + 1),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.7))

	# ---- linha de parada
	draw_line(Vector2(queue_right + 4.0, top), Vector2(queue_right + 4.0, top + float(lanes) * lane_h), Color(1, 1, 1, 0.5), 2.0)

	# ---- fila (a cabeça da fila fica junto aos servidores)
	var qn: int = sim.queue_size()
	var cell_w: float = veh_h * 1.6 * 1.6 + 4.0
	var cols: int = maxi(1, int((queue_right - queue_left) / cell_w))
	var shown: int = mini(qn, cols * lanes)
	for k in range(shown):
		var lane: int = k % lanes
		var col: int = int(float(k) / float(lanes))
		var tt: int = sim.queue_type_at(k)
		var vw2: float = veh_h * 1.6 * float(TYPE_LEN[tt])
		var x: float = queue_right - float(col + 1) * cell_w + (cell_w - vw2) * 0.5
		var y2: float = top + float(lane) * lane_h + (lane_h - veh_h) * 0.5
		draw_rect(Rect2(x, y2, vw2, veh_h), type_colors[tt], true)
	if qn > shown:
		draw_string(font, Vector2(queue_left, top + 16.0), "+%d veículos na fila" % (qn - shown),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.85, 0.5))
