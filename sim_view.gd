extends Control
## Visualização 2D do sistema M/M/c.
## Mantém a lógica da simulação intacta e altera apenas a apresentação:
## - via com marcações pontilhadas;
## - veículos desenhados como veículos vistos de cima;
## - semáforos no lugar das caixas dos servidores;
## - servidor livre = verde / ocupado = vermelho.

const TYPE_NAMES := ["Carro", "Bicicleta", "Ônibus", "Caminhão"]
const TYPE_LEN := [1.0, 0.6, 1.6, 1.35]

var sim = null

var type_colors: Array = [
	Color(0.31, 0.64, 1.0),    # carro
	Color(0.37, 0.82, 0.48),   # bicicleta
	Color(1.0, 0.70, 0.28),    # ônibus
	Color(0.88, 0.39, 0.36),   # caminhão
]


func _draw() -> void:
	var font: Font = get_theme_default_font()

	# Fundo
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.10, 0.12), true)

	if sim == null:
		return

	var w: float = size.x
	var h: float = size.y
	var top: float = 50.0

	var lanes: int = max(1, sim.lanes_visible())
	var lane_h: float = maxf((h - top - 8.0) / float(lanes), 4.0)

	# Área dos semáforos/atendimento.
	var signal_w: float = clampf(w * 0.10, 70.0, 105.0)
	var signal_x: float = w - signal_w - 18.0

	var road_right: float = signal_x - 12.0
	var road_left: float = 12.0

	var veh_h: float = clampf(lane_h * 0.58, 9.0, 28.0)

	# -------------------------------------------------------------------------
	# CABEÇALHO
	# -------------------------------------------------------------------------
	var header: String = "λ = %.2f veíc/min  >>  FILA ÚNICA FIFO  >>  c = %d servidores (μ = %.2f veíc/min cada)" % [
		sim.lam * 60.0, sim.c, sim.mu * 60.0
	]
	draw_string(
		font,
		Vector2(12, 18),
		header,
		HORIZONTAL_ALIGNMENT_LEFT,
		w - 24.0,
		13,
		Color(0.92, 0.92, 0.96)
	)

	# -------------------------------------------------------------------------
	# LEGENDA DOS TIPOS
	# -------------------------------------------------------------------------
	var lx: float = 12.0
	for t in range(4):
		draw_rect(Rect2(lx, 29.0, 10.0, 10.0), type_colors[t], true)
		draw_string(
			font,
			Vector2(lx + 14.0, 38.0),
			str(TYPE_NAMES[t]),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			Color(0.8, 0.8, 0.85)
		)
		lx += 96.0

	var counts: String = "Na fila: %d    Em atendimento: %d" % [
		sim.queue_size(),
		sim.busy_count()
	]
	draw_string(
		font,
		Vector2(0, 38.0),
		counts,
		HORIZONTAL_ALIGNMENT_RIGHT,
		w - 12.0,
		12,
		Color(0.92, 0.92, 0.96)
	)

	# -------------------------------------------------------------------------
	# ÁREA DA VIA
	# -------------------------------------------------------------------------
	var road_rect := Rect2(road_left, top, road_right - road_left, float(lanes) * lane_h)
	draw_rect(road_rect, Color(0.14, 0.15, 0.18), true)

	# Bordas da pista
	draw_line(
		Vector2(road_left, top),
		Vector2(road_right, top),
		Color(0.55, 0.56, 0.60),
		2.0
	)
	draw_line(
		Vector2(road_left, top + float(lanes) * lane_h),
		Vector2(road_right, top + float(lanes) * lane_h),
		Color(0.55, 0.56, 0.60),
		2.0
	)

	# -------------------------------------------------------------------------
	# FAIXAS PONTILHADAS ENTRE AS FAIXAS DE TRÂNSITO
	# -------------------------------------------------------------------------
	for i in range(1, lanes):
		var divider_y: float = top + float(i) * lane_h

		var dash_len := 16.0
		var gap := 12.0
		var x := road_left + 8.0

		while x < road_right - 8.0:
			draw_line(
				Vector2(x, divider_y),
				Vector2(minf(x + dash_len, road_right - 8.0), divider_y),
				Color(0.82, 0.83, 0.85, 0.75),
				2.0
			)
			x += dash_len + gap

	# -------------------------------------------------------------------------
	# INDICAÇÃO DE ENTRADA
	# -------------------------------------------------------------------------
	draw_string(
		font,
		Vector2(road_left + 4.0, top - 17.0),
		"ENTRADA  ↓",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color(0.75, 0.86, 1.0)
	)

	# -------------------------------------------------------------------------
	# SERVIDORES REPRESENTADOS POR SEMÁFOROS
	# -------------------------------------------------------------------------
	for i in range(lanes):
		var y: float = top + float(i) * lane_h
		var center_y: float = y + lane_h * 0.5

		var busy: bool = int(sim.srv_type[i]) >= 0
		var active: bool = i < sim.c

		# Faixa de atendimento final
		var service_x: float = road_right + 3.0
		var service_w: float = signal_x - service_x

		if active:
			draw_rect(
				Rect2(service_x, y + 2.0, service_w, lane_h - 4.0),
				Color(0.16, 0.17, 0.20),
				true
			)
		else:
			draw_rect(
				Rect2(service_x, y + 2.0, service_w, lane_h - 4.0),
				Color(0.10, 0.11, 0.13),
				true
			)

		# Linha de parada
		draw_line(
			Vector2(service_x + 2.0, y + 4.0),
			Vector2(service_x + 2.0, y + lane_h - 4.0),
			Color(1.0, 0.85, 0.35, 0.9),
			3.0
		)

		# Semáforo
		var light_x: float = signal_x + signal_w * 0.40
		var housing_h: float = minf(lane_h - 8.0, 48.0)
		var housing_w: float = 30.0
		var housing_y: float = center_y - housing_h * 0.5

		draw_rect(
			Rect2(light_x - housing_w * 0.5, housing_y, housing_w, housing_h),
			Color(0.055, 0.06, 0.07),
			true
		)
		draw_rect(
			Rect2(light_x - housing_w * 0.5, housing_y, housing_w, housing_h),
			Color(0.45, 0.46, 0.50, 0.8),
			false,
			1.0
		)

		# Luzes apagadas
		var r := minf(6.0, housing_h * 0.15)
		var red_y := center_y - minf(8.0, housing_h * 0.18)
		var green_y := center_y + minf(8.0, housing_h * 0.18)

		draw_circle(Vector2(light_x, red_y), r, Color(0.22, 0.05, 0.05))
		draw_circle(Vector2(light_x, green_y), r, Color(0.04, 0.20, 0.08))

		if active:
			if busy:
				draw_circle(Vector2(light_x, red_y), r, Color(0.95, 0.12, 0.10))
				draw_circle(Vector2(light_x, red_y), r + 2.0, Color(1.0, 0.18, 0.12, 0.18))
			else:
				draw_circle(Vector2(light_x, green_y), r, Color(0.15, 0.90, 0.30))
				draw_circle(Vector2(light_x, green_y), r + 2.0, Color(0.20, 1.0, 0.35, 0.18))

		# Identificação do servidor
		draw_string(
			font,
			Vector2(signal_x + 42.0, center_y + 4.0),
			"M%d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			Color(0.92, 0.92, 0.96)
		)

		# Estado textual
		var state := "ATENDENDO" if busy and active else "LIVRE" if active else "FECHADO"
		var state_col := Color(1.0, 0.45, 0.40) if busy and active else Color(0.35, 0.95, 0.48) if active else Color(0.55, 0.55, 0.58)

		draw_string(
			font,
			Vector2(signal_x - 2.0, y + lane_h - 4.0),
			state,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			9,
			state_col
		)

		# Veículo em atendimento
		if busy:
			var t: int = int(sim.srv_type[i])
			var vw: float = clampf(veh_h * 1.55 * float(TYPE_LEN[t]), 12.0, service_w - 42.0)
			var vx: float = service_x + service_w * 0.15

			_draw_vehicle(
				Vector2(vx, center_y),
				Vector2(vw, veh_h),
				t,
				true
			)

			# Barra de progresso do atendimento
			var s: float = float(sim.srv_start[i])
			var e: float = float(sim.srv_end[i])
			var frac: float = clampf(
				(sim.clock - s) / maxf(e - s, 0.0001),
				0.0,
				1.0
			)

			draw_rect(
				Rect2(service_x + 5.0, y + lane_h - 5.0, service_w - 10.0, 2.0),
				Color(1, 1, 1, 0.15),
				true
			)
			draw_rect(
				Rect2(service_x + 5.0, y + lane_h - 5.0, (service_w - 10.0) * frac, 2.0),
				Color(0.85, 0.90, 0.95, 0.9),
				true
			)

	# -------------------------------------------------------------------------
	# FILA FIFO
	# -------------------------------------------------------------------------
	var qn: int = sim.queue_size()

	# Espaçamento entre veículos.
	var cell_w: float = maxf(veh_h * 1.8, 28.0)

	# Quantos veículos cabem por faixa.
	var cols: int = maxi(
		1,
		int((road_right - road_left - 16.0) / cell_w)
	)

	var shown: int = mini(qn, cols * lanes)

	for k in range(shown):
		var lane: int = k % lanes
		var col: int = int(float(k) / float(lanes))

		var tt: int = sim.queue_type_at(k)

		var vw2: float = clampf(
			veh_h * 1.55 * float(TYPE_LEN[tt]),
			12.0,
			cell_w - 4.0
		)

		# A cabeça da fila fica mais próxima dos servidores.
		var x: float = road_right - float(col + 1) * cell_w
		x += (cell_w - vw2) * 0.5

		var y2: float = top + float(lane) * lane_h + (lane_h - veh_h) * 0.5

		_draw_vehicle(
			Vector2(x + vw2 * 0.5, y2 + veh_h * 0.5),
			Vector2(vw2, veh_h),
			tt,
			false
		)

	if qn > shown:
		draw_string(
			font,
			Vector2(road_left + 6.0, top + 16.0),
			"+%d veículos na fila" % (qn - shown),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			13,
			Color(1.0, 0.85, 0.5)
		)

	# -------------------------------------------------------------------------
	# RÓTULOS INFERIORES
	# -------------------------------------------------------------------------
	var bottom_y := top + float(lanes) * lane_h + 17.0

	draw_string(
		font,
		Vector2(road_left + 4.0, bottom_y),
		"FILA FIFO  →  ATENDIMENTO  →  SAÍDA",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color(0.75, 0.78, 0.84)
	)


# =============================================================================
# VEÍCULOS
# =============================================================================
# Desenha veículos de cima, apontados para a direita.
# Isso substitui os antigos retângulos simples.
func _draw_vehicle(center: Vector2, vehicle_size: Vector2, type: int, in_service: bool) -> void:
	var col: Color = type_colors[type]
	var ww: float = maxf(vehicle_size.x, 10.0)
	var hh: float = maxf(vehicle_size.y, 8.0)

	var left: float = center.x - ww * 0.5
	var right: float = center.x + ww * 0.5
	var top_y: float = center.y - hh * 0.5
	var bottom_y: float = center.y + hh * 0.5

	# Corpo principal
	draw_rect(
		Rect2(left, top_y, ww, hh),
		col,
		true
	)

	# Frente arredondada visualmente com um pequeno polígono.
	var nose := PackedVector2Array([
		Vector2(right - minf(ww * 0.22, 6.0), top_y),
		Vector2(right, top_y + hh * 0.20),
		Vector2(right, bottom_y - hh * 0.20),
		Vector2(right - minf(ww * 0.22, 6.0), bottom_y)
	])
	draw_colored_polygon(nose, col.lightened(0.06))

	# Janela
	var window_left := left + ww * 0.38
	var window_w := maxf(ww * 0.30, 4.0)

	draw_rect(
		Rect2(window_left, top_y + hh * 0.18, window_w, hh * 0.64),
		Color(0.07, 0.12, 0.16, 0.9),
		true
	)

	# Divisão do vidro
	if window_w > 8.0:
		draw_line(
			Vector2(window_left + window_w * 0.5, top_y + hh * 0.20),
			Vector2(window_left + window_w * 0.5, bottom_y - hh * 0.20),
			Color(0.65, 0.78, 0.85, 0.65),
			1.0
		)

	# Rodas
	var wheel_w := maxf(ww * 0.13, 2.0)
	var wheel_h := maxf(hh * 0.72, 3.0)

	draw_rect(
		Rect2(left + ww * 0.16, top_y - 1.0, wheel_w, wheel_h),
		Color(0.03, 0.03, 0.035),
		true
	)
	draw_rect(
		Rect2(left + ww * 0.16, bottom_y - wheel_h + 1.0, wheel_w, wheel_h),
		Color(0.03, 0.03, 0.035),
		true
	)

	# Luzes dianteiras/traseiras
	if ww >= 18.0:
		draw_rect(
			Rect2(right - 2.0, top_y + hh * 0.18, 2.0, maxf(hh * 0.18, 1.0)),
			Color(1.0, 0.92, 0.55),
			true
		)
		draw_rect(
			Rect2(left, bottom_y - hh * 0.36, 2.0, maxf(hh * 0.18, 1.0)),
			Color(0.95, 0.18, 0.15),
			true
		)

	# Contorno
	draw_rect(
		Rect2(left, top_y, ww, hh),
		Color(1, 1, 1, 0.30),
		false,
		1.0
	)

	# Pequena indicação de que está sendo atendido.
	if in_service:
		draw_circle(
			Vector2(right + 4.0, center.y),
			2.0,
			Color(1.0, 0.95, 0.55)
		)
