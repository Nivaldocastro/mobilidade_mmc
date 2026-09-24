extends Control
## Barras com o Total de veículos por intervalo de 15 min do dia selecionado.
## Cor = "Traffic Situation". Linha tracejada = capacidade c·μ (veículos / 15 min).
## Clique/arraste para escolher o intervalo.

signal interval_picked(idx: int)

const PAD_L := 38.0
const PAD_R := 10.0
const PAD_T := 24.0
const PAD_B := 20.0
const SITUATION_COLORS := {
	"low": Color(0.37, 0.82, 0.48),
	"normal": Color(0.31, 0.64, 1.0),
	"high": Color(1.0, 0.70, 0.28),
	"heavy": Color(0.88, 0.39, 0.36),
}

var rows: Array = []
var current_idx: int = 0
var capacity: float = -1.0     # c · μ · 15  (veículos por intervalo)
var title: String = "Dataset: veículos por intervalo de 15 min (cor = situação do tráfego)"


func _draw() -> void:
	var font: Font = get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.10, 0.12), true)
	draw_string(font, Vector2(8, 16), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, 12, Color(0.92, 0.92, 0.96))

	var n: int = rows.size()
	var pw: float = size.x - PAD_L - PAD_R
	var ph: float = size.y - PAD_T - PAD_B
	if n == 0 or pw <= 20.0 or ph <= 20.0:
		return

	var ymax: float = 1.0
	for r in rows:
		ymax = maxf(ymax, float(r["total"]))
	ymax = ceilf(ymax * 1.1)

	for g in range(5):
		var gy: float = PAD_T + ph - ph * float(g) / 4.0
		draw_line(Vector2(PAD_L, gy), Vector2(PAD_L + pw, gy), Color(1, 1, 1, 0.08), 1.0)
		draw_string(font, Vector2(4, gy + 4.0), "%d" % int(round(ymax * float(g) / 4.0)),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.7, 0.75))

	var bw: float = pw / float(n)
	for i in range(n):
		var r: Dictionary = rows[i]
		var col: Color = SITUATION_COLORS.get(str(r["situation"]), Color(0.6, 0.6, 0.6))
		var bh: float = ph * float(r["total"]) / ymax
		draw_rect(Rect2(PAD_L + bw * float(i), PAD_T + ph - bh, maxf(bw - 1.0, 1.0), bh), col, true)

	# marcador do intervalo atual
	var mx: float = PAD_L + bw * float(current_idx)
	draw_rect(Rect2(mx - 1.0, PAD_T, bw + 2.0, ph), Color(1, 1, 1, 0.18), true)
	draw_line(Vector2(mx + bw * 0.5, PAD_T), Vector2(mx + bw * 0.5, PAD_T + ph), Color(1, 1, 1, 0.9), 1.5)

	# capacidade do sistema
	if capacity > 0.0 and capacity <= ymax:
		var cy: float = PAD_T + ph - ph * capacity / ymax
		draw_dashed_line(Vector2(PAD_L, cy), Vector2(PAD_L + pw, cy), Color(1, 1, 1, 0.85), 1.5, 6.0)
		draw_string(font, Vector2(PAD_L + 6.0, cy - 4.0), "capacidade c·μ = %.0f" % capacity,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9))
	elif capacity > ymax:
		draw_string(font, Vector2(PAD_L + 6.0, PAD_T + 12.0), "capacidade c·μ = %.0f (acima do gráfico)" % capacity,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.7))

	for hr in [0, 6, 12, 18, 24]:
		var hx: float = PAD_L + pw * float(hr) / 24.0
		draw_string(font, Vector2(hx - 6.0, size.y - 5.0), "%dh" % hr, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.7, 0.75))


func _gui_input(event: InputEvent) -> void:
	var active: bool = false
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			active = true
			pos = mb.position
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			active = true
			pos = mm.position
	if active and rows.size() > 0:
		var pw: float = size.x - PAD_L - PAD_R
		var idx: int = clampi(int((pos.x - PAD_L) / (pw / float(rows.size()))), 0, rows.size() - 1)
		interval_picked.emit(idx)
