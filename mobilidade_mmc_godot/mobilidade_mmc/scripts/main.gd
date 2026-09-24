extends Control
## Simulador de mobilidade urbana com modelo de filas M/M/c.
## A interface é montada por código para manter o projeto simples (uma única cena).

const MMcModel = preload("res://scripts/mmc_model.gd")
const MMcSimulation = preload("res://scripts/mmc_simulation.gd")
const TrafficDataset = preload("res://scripts/traffic_dataset.gd")
const SimViewScript = preload("res://scripts/sim_view.gd")
const LineChartScript = preload("res://scripts/line_chart.gd")
const DayChartScript = preload("res://scripts/day_chart.gd")

const DEFAULT_DATA_PATH := "res://data/dataset_mobilidade_urbana.txt"
const INTERVAL_S := 900.0   # cada linha do dataset cobre 15 min = 900 s
const SAMPLE_S := 15.0      # amostragem do gráfico da fila (s simulados)
const SITUATION_PT := {"low": "baixo", "normal": "normal", "high": "alto", "heavy": "pesado"}

# ------------------------------------------------------------------ estado
var ds: TrafficDataset = TrafficDataset.new()
var sim: MMcSimulation = MMcSimulation.new()
var theory: Dictionary = {}

var running: bool = true
var use_dataset: bool = true
var lambda_manual: float = 12.0   # veículos/min (modo manual)
var demand_factor: float = 1.0    # multiplicador do λ do dataset
var mu_min: float = 10.0          # veículos/min por servidor
var servers: int = 2
var speed: float = 30.0           # segundos simulados por segundo real

var cur_date: int = -1
var cur_idx: int = 28             # 07:00
var start_offset: float = 0.0     # hora do dia (s) = start_offset + sim.clock
var next_sample: float = 0.0
var stat_timer: float = 0.0

# ---------------------------------------------------------------- widgets
var sim_view: SimViewScript
var line_chart: LineChartScript
var day_chart: DayChartScript
var lambda_ctrl: Dictionary
var mu_ctrl: Dictionary
var servers_ctrl: Dictionary
var speed_ctrl: Dictionary
var factor_ctrl: Dictionary
var pause_btn: Button
var date_option: OptionButton
var interval_slider: HSlider
var interval_label: Label
var info_label: Label
var dataset_check: CheckBox
var dataset_status: Label
var service_label: Label
var lambda_eff_label: Label
var status_label: Label
var clock_label: Label
var stat_labels: Dictionary = {}
var file_dialog: FileDialog


func _ready() -> void:
	_build_ui()
	var err: Error = ds.load_from_file(DEFAULT_DATA_PATH)
	_on_dataset_loaded(err)
	_reset_sim()


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.1)
	if running:
		sim.advance(dt * speed)
		if use_dataset and ds.has_data():
			var idx: int = _current_interval()
			if idx != cur_idx:
				cur_idx = idx
				interval_slider.set_value_no_signal(float(cur_idx))
				_refresh_dataset_ui()
				_apply_params()
		while sim.clock >= next_sample:
			line_chart.add_point(float(sim.queue_size()))
			next_sample += SAMPLE_S
	sim_view.queue_redraw()
	stat_timer += dt
	if stat_timer >= 0.2:
		stat_timer = 0.0
		_update_stats()


# ================================================================== UI

func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)

	var root_box: HBoxContainer = HBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	margin.add_child(root_box)

	# ---------------- painel esquerdo (controles)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(390, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_box.add_child(scroll)

	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	scroll.add_child(left)

	var title: Label = Label.new()
	title.text = "Mobilidade urbana - Simulador M/M/c"
	title.add_theme_font_size_override("font_size", 18)
	left.add_child(title)

	# --- modelo
	var sec_model: VBoxContainer = _section(left, "Parâmetros do modelo M/M/c")
	lambda_ctrl = _add_param(sec_model, "Taxa média de chegada λ (veículos/min)",
			0.0, 60.0, 0.1, lambda_manual, true, _on_lambda_changed)
	lambda_eff_label = _add_label(sec_model, "")
	mu_ctrl = _add_param(sec_model, "Taxa média de atendimento μ por servidor (veículos/min)",
			0.5, 60.0, 0.1, mu_min, true, _on_mu_changed)
	service_label = _add_label(sec_model, "")
	servers_ctrl = _add_param(sec_model, "Número de servidores c (faixas / cabines)",
			1.0, 20.0, 1.0, float(servers), false, _on_servers_changed)
	speed_ctrl = _add_param(sec_model, "Velocidade da simulação (segundos simulados por segundo real)",
			1.0, 600.0, 1.0, speed, false, _on_speed_changed)

	var btn_row: HBoxContainer = HBoxContainer.new()
	sec_model.add_child(btn_row)
	pause_btn = Button.new()
	pause_btn.text = "Pausar"
	pause_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_btn.pressed.connect(_on_pause_pressed)
	btn_row.add_child(pause_btn)
	var reset_btn: Button = Button.new()
	reset_btn.text = "Reiniciar"
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.pressed.connect(_reset_sim)
	btn_row.add_child(reset_btn)

	# --- dataset
	var sec_data: VBoxContainer = _section(left, "Dataset de tráfego")
	dataset_status = _add_label(sec_data, "")
	dataset_check = CheckBox.new()
	dataset_check.text = "Seguir dataset (λ = Total / 15 min)"
	dataset_check.button_pressed = use_dataset
	dataset_check.toggled.connect(_on_dataset_toggled)
	sec_data.add_child(dataset_check)

	_add_label(sec_data, "Dia do dataset")
	date_option = OptionButton.new()
	date_option.item_selected.connect(_on_date_selected)
	sec_data.add_child(date_option)

	_add_label(sec_data, "Intervalo de 15 min (também dá para clicar no gráfico de barras)")
	var int_row: HBoxContainer = HBoxContainer.new()
	sec_data.add_child(int_row)
	interval_slider = HSlider.new()
	interval_slider.min_value = 0.0
	interval_slider.max_value = 95.0
	interval_slider.step = 1.0
	interval_slider.value = float(cur_idx)
	interval_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interval_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	interval_slider.value_changed.connect(_on_interval_changed)
	int_row.add_child(interval_slider)
	interval_label = Label.new()
	interval_label.custom_minimum_size = Vector2(52, 0)
	int_row.add_child(interval_label)

	info_label = _add_label(sec_data, "")

	factor_ctrl = _add_param(sec_data, "Multiplicador do λ do dataset (× demanda)",
			0.1, 5.0, 0.05, demand_factor, true, _on_factor_changed)

	var data_btns: HBoxContainer = HBoxContainer.new()
	sec_data.add_child(data_btns)
	var copy_btn: Button = Button.new()
	copy_btn.text = "Copiar λ do intervalo"
	copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_btn.pressed.connect(_on_copy_lambda_pressed)
	data_btns.add_child(copy_btn)
	var load_btn: Button = Button.new()
	load_btn.text = "Carregar CSV..."
	load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_btn.pressed.connect(_on_load_pressed)
	data_btns.add_child(load_btn)

	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Escolha um CSV com o mesmo formato do dataset"
	file_dialog.filters = PackedStringArray(["*.csv, *.txt ; Dataset (CSV/TXT)"])
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)

	# ---------------- painel direito (visualização)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	root_box.add_child(right)

	sim_view = SimViewScript.new()
	sim_view.sim = sim
	sim_view.custom_minimum_size = Vector2(480, 240)
	sim_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sim_view)

	var charts: HBoxContainer = HBoxContainer.new()
	charts.custom_minimum_size = Vector2(0, 170)
	charts.add_theme_constant_override("separation", 8)
	right.add_child(charts)

	line_chart = LineChartScript.new()
	line_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_chart.custom_minimum_size = Vector2(200, 0)
	line_chart.sample_seconds = SAMPLE_S
	charts.add_child(line_chart)

	day_chart = DayChartScript.new()
	day_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_chart.custom_minimum_size = Vector2(200, 0)
	day_chart.interval_picked.connect(_on_day_chart_picked)
	charts.add_child(day_chart)

	var sec_stats: VBoxContainer = _section(right, "Resultados: teoria (Erlang C) x simulação")
	status_label = _add_label(sec_stats, "")
	clock_label = _add_label(sec_stats, "")
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 2)
	sec_stats.add_child(grid)
	for head in ["Métrica", "Teórico (regime estacionário)", "Simulado"]:
		var hl: Label = Label.new()
		hl.text = head
		hl.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
		grid.add_child(hl)
	var rows_def: Array = [
		["rho", "Utilização ρ"],
		["pw", "P(esperar) - Erlang C"],
		["lq", "Fila média Lq (veículos)"],
		["wq", "Espera média Wq (s)"],
		["w", "Tempo médio no sistema W (s)"],
		["l", "Nº médio no sistema L"],
		["queue", "Fila atual / máxima"],
		["count", "Chegadas / atendidos"],
	]
	for rd in rows_def:
		var name_l: Label = Label.new()
		name_l.text = str(rd[1])
		var th_l: Label = Label.new()
		var sim_l: Label = Label.new()
		grid.add_child(name_l)
		grid.add_child(th_l)
		grid.add_child(sim_l)
		stat_labels[str(rd[0])] = [th_l, sim_l]
	_add_label(sec_stats, "Obs.: no modo dataset o λ muda a cada 15 min simulados; a coluna teórica usa o λ atual.")


func _section(parent: Control, title_text: String) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var m: MarginContainer = MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		m.add_theme_constant_override(side, 8)
	panel.add_child(m)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	m.add_child(v)
	var t: Label = Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
	v.add_child(t)
	return v


func _add_label(parent: Control, text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(280, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


## Cria "rótulo + slider + caixa numérica" sincronizados. Devolve {"slider", "spin"}.
func _add_param(parent: Control, title_text: String, min_v: float, max_v: float, step: float,
		val: float, allow_greater: bool, on_change: Callable) -> Dictionary:
	_add_label(parent, title_text)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var slider: HSlider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.value = val
	spin.allow_greater = allow_greater
	spin.custom_minimum_size = Vector2(96, 0)
	row.add_child(spin)

	slider.value_changed.connect(func(v: float) -> void:
		spin.set_value_no_signal(v)
		on_change.call(v)
	)
	spin.value_changed.connect(func(v: float) -> void:
		slider.set_value_no_signal(v)
		on_change.call(v)
	)
	return {"slider": slider, "spin": spin}


# ============================================================== callbacks

func _on_lambda_changed(v: float) -> void:
	lambda_manual = v
	_apply_params()


func _on_mu_changed(v: float) -> void:
	mu_min = maxf(v, 0.1)
	_apply_params()


func _on_servers_changed(v: float) -> void:
	servers = int(v)
	_apply_params()


func _on_speed_changed(v: float) -> void:
	speed = maxf(v, 1.0)


func _on_factor_changed(v: float) -> void:
	demand_factor = v
	_apply_params()


func _on_pause_pressed() -> void:
	running = not running
	pause_btn.text = "Pausar" if running else "Continuar"


func _on_dataset_toggled(on: bool) -> void:
	if on and not ds.has_data():
		dataset_check.set_pressed_no_signal(false)
		return
	use_dataset = on
	if on:
		# a hora simulada passa a partir do intervalo escolhido
		start_offset = float(cur_idx) * INTERVAL_S - sim.clock
	_update_enabled_states()
	_apply_params()


func _on_date_selected(index: int) -> void:
	cur_date = int(ds.dates[index])
	interval_slider.max_value = float(maxi(ds.day_size(cur_date) - 1, 0))
	cur_idx = mini(cur_idx, ds.day_size(cur_date) - 1)
	_refresh_dataset_ui()
	_apply_params()


func _on_interval_changed(v: float) -> void:
	cur_idx = int(v)
	start_offset = float(cur_idx) * INTERVAL_S - sim.clock
	_refresh_dataset_ui()
	_apply_params()


func _on_day_chart_picked(idx: int) -> void:
	interval_slider.value = float(idx)   # dispara _on_interval_changed


func _on_copy_lambda_pressed() -> void:
	var row: Dictionary = ds.get_row(cur_date, cur_idx)
	if row.is_empty():
		return
	lambda_manual = snappedf(float(row["total"]) / 15.0, 0.1)
	lambda_ctrl["slider"].set_value_no_signal(lambda_manual)
	lambda_ctrl["spin"].set_value_no_signal(lambda_manual)
	use_dataset = false
	dataset_check.set_pressed_no_signal(false)
	_update_enabled_states()
	_apply_params()


func _on_load_pressed() -> void:
	file_dialog.popup_centered_ratio(0.6)


func _on_file_selected(path: String) -> void:
	var err: Error = ds.load_from_file(path)
	_on_dataset_loaded(err)
	_reset_sim()


# =============================================================== lógica

func _on_dataset_loaded(err: Error) -> void:
	if err != OK or not ds.has_data():
		dataset_status.text = "Não foi possível carregar o dataset (erro %d). Use 'Carregar CSV...' ou o modo manual." % err
		use_dataset = false
		dataset_check.set_pressed_no_signal(false)
		date_option.clear()
		day_chart.rows = []
		day_chart.queue_redraw()
		_update_enabled_states()
		_refresh_dataset_ui()
		return

	dataset_status.text = "%d linhas | %d dias | arquivo: %s" % [ds.rows.size(), ds.dates.size(), ds.source_path.get_file()]
	date_option.clear()
	for d in ds.dates:
		date_option.add_item("Dia %d (%s)" % [int(d), ds.weekday_pt(int(d))])
	date_option.select(0)
	cur_date = int(ds.dates[0])
	interval_slider.max_value = float(maxi(ds.day_size(cur_date) - 1, 0))
	cur_idx = clampi(cur_idx, 0, maxi(ds.day_size(cur_date) - 1, 0))
	interval_slider.set_value_no_signal(float(cur_idx))
	_update_enabled_states()
	_refresh_dataset_ui()


func _update_enabled_states() -> void:
	var manual: bool = not use_dataset
	lambda_ctrl["slider"].editable = manual
	lambda_ctrl["spin"].editable = manual
	factor_ctrl["slider"].editable = use_dataset
	factor_ctrl["spin"].editable = use_dataset


func _current_interval() -> int:
	var tod: float = fposmod(start_offset + sim.clock, 86400.0)
	return clampi(int(tod / INTERVAL_S), 0, maxi(ds.day_size(cur_date) - 1, 0))


func _reset_sim() -> void:
	sim.reset()
	start_offset = float(cur_idx) * INTERVAL_S
	next_sample = 0.0
	line_chart.clear_data()
	_apply_params()
	_update_stats()


## Lê a interface/dataset e envia λ, μ, c e a mistura de veículos para a simulação.
func _apply_params() -> void:
	var row: Dictionary = ds.get_row(cur_date, cur_idx)
	var lam_min: float = lambda_manual
	if use_dataset and not row.is_empty():
		lam_min = float(row["total"]) / 15.0 * demand_factor
	if not row.is_empty():
		sim.set_mix(float(row["car"]), float(row["bike"]), float(row["bus"]), float(row["truck"]))

	var lam_s: float = lam_min / 60.0
	var mu_s: float = mu_min / 60.0
	sim.set_rates(lam_s, mu_s)
	sim.set_servers(servers)
	theory = MMcModel.compute(lam_s, mu_s, servers)

	if use_dataset and not row.is_empty():
		lambda_eff_label.text = "λ em uso (dataset x %.2f): %.2f veíc/min" % [demand_factor, lam_min]
	else:
		lambda_eff_label.text = "λ em uso (manual): %.2f veíc/min" % lam_min
	service_label.text = "Tempo médio de atendimento 1/μ = %.1f s por veículo" % (60.0 / mu_min)

	line_chart.ref_line = float(theory["lq"]) if bool(theory["stable"]) else -1.0
	line_chart.queue_redraw()
	day_chart.capacity = float(servers) * mu_min * 15.0
	day_chart.queue_redraw()


@warning_ignore("integer_division")
func _fmt_minute(m: int) -> String:
	return "%02d:%02d" % [m / 60, m % 60]


func _refresh_dataset_ui() -> void:
	var row: Dictionary = ds.get_row(cur_date, cur_idx)
	if row.is_empty():
		interval_label.text = "--:--"
		info_label.text = "Nenhum dado carregado: use o modo manual ou carregue um CSV."
		return
	var total: int = int(row["total"])
	var sit: String = str(row["situation"])
	interval_label.text = _fmt_minute(int(row["minute"]))
	info_label.text = "%s, dia %d, %s\nCarros %d | Bicicletas %d | Ônibus %d | Caminhões %d\nTotal: %d veículos em 15 min  =>  λ = %.2f veíc/min\nSituação do tráfego: %s" % [
		ds.weekday_pt(cur_date), cur_date, _fmt_minute(int(row["minute"])),
		int(row["car"]), int(row["bike"]), int(row["bus"]), int(row["truck"]),
		total, float(total) / 15.0, str(SITUATION_PT.get(sit, sit))]
	day_chart.rows = ds.get_day(cur_date)
	day_chart.current_idx = cur_idx
	day_chart.queue_redraw()


@warning_ignore("integer_division")
func _update_stats() -> void:
	var stable: bool = bool(theory.get("stable", false))
	var rho_t: float = float(theory.get("rho", 0.0))

	stat_labels["rho"][0].text = "%.1f %%" % (rho_t * 100.0)
	stat_labels["rho"][1].text = "%.1f %%" % (minf(sim.utilization(), 1.0) * 100.0)

	if stable:
		stat_labels["pw"][0].text = "%.1f %%" % (float(theory["pw"]) * 100.0)
		stat_labels["lq"][0].text = "%.2f" % float(theory["lq"])
		stat_labels["wq"][0].text = "%.1f" % float(theory["wq"])
		stat_labels["w"][0].text = "%.1f" % float(theory["w"])
		stat_labels["l"][0].text = "%.2f" % float(theory["l"])
	else:
		for key in ["pw", "lq", "wq", "w", "l"]:
			stat_labels[key][0].text = "instável"
	stat_labels["pw"][1].text = "%.1f %%" % (sim.p_wait() * 100.0)
	stat_labels["lq"][1].text = "%.2f" % sim.avg_lq()
	stat_labels["wq"][1].text = "%.1f" % sim.avg_wq()
	stat_labels["w"][1].text = "%.1f" % sim.avg_w()
	stat_labels["l"][1].text = "%.2f" % (sim.avg_lq() + sim.utilization() * float(sim.c))
	stat_labels["queue"][0].text = "-"
	stat_labels["queue"][1].text = "%d / %d" % [sim.queue_size(), sim.max_queue]
	stat_labels["count"][0].text = "-"
	stat_labels["count"][1].text = "%d / %d" % [sim.arrivals, sim.served]

	if stable:
		var c_min: int = int(floor(float(theory["a"]))) + 1
		status_label.text = "Sistema ESTÁVEL (ρ < 1). Mínimo de servidores para estabilidade: %d." % c_min
		status_label.add_theme_color_override("font_color", Color(0.45, 0.85, 0.5))
	else:
		var c_need: int = int(floor(float(theory.get("a", 0.0)))) + 1
		status_label.text = "Sistema INSTÁVEL (ρ >= 1): a fila cresce sem limite. Use pelo menos c = %d ou reduza λ / aumente μ." % c_need
		status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))

	var tod: int = int(fposmod(start_offset + sim.clock, 86400.0))
	clock_label.text = "Hora simulada: %02d:%02d:%02d   |   decorrido: %.1f min" % [
		tod / 3600, (tod % 3600) / 60, tod % 60, sim.clock / 60.0]
