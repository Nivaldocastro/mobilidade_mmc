extends RefCounted
## Simulação de eventos discretos de uma fila M/M/c com disciplina FIFO.
##
##  - Chegadas: processo de Poisson (tempos entre chegadas ~ Exponencial(λ))
##  - Atendimento: tempo de serviço ~ Exponencial(μ) em cada servidor
##  - Fila única; o próximo veículo vai para o primeiro servidor livre
##
## Unidades: taxas em veículos/segundo, tempo em segundos.
## λ, μ e c podem ser alterados durante a execução (propriedade "sem memória"
## da exponencial permite re-sortear a próxima chegada quando λ muda).

const MAX_SERVERS := 20

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# parâmetros
var lam: float = 0.2
var mu: float = 1.0 / 6.0
var c: int = 2
var type_weights: Array = [60.0, 10.0, 15.0, 15.0]   # carro, bicicleta, ônibus, caminhão

# estado
var clock: float = 0.0
var next_arrival: float = INF
var queue: Array = []          # cada item: {"t": instante de chegada, "type": tipo}
var q_head: int = 0
var srv_type: Array = []       # -1 = livre; senão tipo do veículo em atendimento
var srv_start: Array = []
var srv_end: Array = []
var srv_arrive: Array = []

# estatísticas
var arrivals: int = 0
var started: int = 0
var served: int = 0
var waited: int = 0
var sum_wq: float = 0.0
var sum_w: float = 0.0
var area_q: float = 0.0
var busy_time: float = 0.0
var cap_time: float = 0.0
var max_queue: int = 0


func _init() -> void:
	rng.randomize()
	reset()


func reset() -> void:
	clock = 0.0
	queue = []
	q_head = 0
	srv_type = []
	srv_start = []
	srv_end = []
	srv_arrive = []
	for i in range(MAX_SERVERS):
		srv_type.append(-1)
		srv_start.append(0.0)
		srv_end.append(INF)
		srv_arrive.append(0.0)
	arrivals = 0
	started = 0
	served = 0
	waited = 0
	sum_wq = 0.0
	sum_w = 0.0
	area_q = 0.0
	busy_time = 0.0
	cap_time = 0.0
	max_queue = 0
	next_arrival = _exp_sample(lam)


# ---------------------------------------------------------------- parâmetros

func set_rates(new_lam: float, new_mu: float) -> void:
	var lam_changed: bool = not is_equal_approx(new_lam, lam)
	lam = maxf(new_lam, 0.0)
	mu = maxf(new_mu, 0.0001)
	if lam_changed:
		next_arrival = clock + _exp_sample(lam)


func set_servers(n: int) -> void:
	c = clampi(n, 1, MAX_SERVERS)
	_fill_idle_servers()   # se c aumentou, servidores novos já puxam da fila
	# se c diminuiu, servidores extras terminam o veículo atual e fecham


func set_mix(car: float, bike: float, bus: float, truck: float) -> void:
	if car + bike + bus + truck > 0.0:
		type_weights = [car, bike, bus, truck]


# ------------------------------------------------------------------- avanço

func advance(dt: float) -> void:
	var target: float = clock + dt
	var guard: int = 0
	while guard < 200000:
		guard += 1
		var t_dep: float = INF
		var dep_i: int = -1
		for i in range(MAX_SERVERS):
			if srv_type[i] >= 0 and srv_end[i] < t_dep:
				t_dep = srv_end[i]
				dep_i = i
		var t_ev: float = minf(next_arrival, t_dep)
		if t_ev > target:
			_integrate(target)
			return
		_integrate(t_ev)
		if next_arrival <= t_dep:
			_on_arrival()
		else:
			_on_departure(dep_i)
	_integrate(target)


func _integrate(to_t: float) -> void:
	var dt: float = to_t - clock
	if dt <= 0.0:
		return
	area_q += float(queue_size()) * dt
	busy_time += float(busy_count()) * dt
	cap_time += float(c) * dt
	clock = to_t


func _on_arrival() -> void:
	arrivals += 1
	var type: int = _sample_type()
	var free_i: int = _find_free_server()
	if free_i >= 0:
		_start_service(free_i, clock, type)
	else:
		queue.append({"t": clock, "type": type})
		max_queue = maxi(max_queue, queue_size())
	next_arrival = clock + _exp_sample(lam)


func _on_departure(i: int) -> void:
	served += 1
	sum_w += clock - float(srv_arrive[i])
	srv_type[i] = -1
	srv_end[i] = INF
	if i < c and queue_size() > 0:
		var v: Dictionary = _pop_queue()
		_start_service(i, float(v["t"]), int(v["type"]))


func _start_service(i: int, arrive_t: float, type: int) -> void:
	srv_type[i] = type
	srv_arrive[i] = arrive_t
	srv_start[i] = clock
	srv_end[i] = clock + _exp_sample(mu)
	var wq: float = clock - arrive_t
	sum_wq += wq
	started += 1
	if wq > 0.000001:
		waited += 1


func _fill_idle_servers() -> void:
	for i in range(c):
		if queue_size() == 0:
			return
		if srv_type[i] < 0:
			var v: Dictionary = _pop_queue()
			_start_service(i, float(v["t"]), int(v["type"]))


func _find_free_server() -> int:
	for i in range(c):
		if srv_type[i] < 0:
			return i
	return -1


func _pop_queue() -> Dictionary:
	var v: Dictionary = queue[q_head]
	q_head += 1
	if q_head > 512 and q_head * 2 > queue.size():
		queue = queue.slice(q_head)
		q_head = 0
	return v


# ---------------------------------------------------------------- utilitários

func _exp_sample(rate: float) -> float:
	if rate <= 0.0:
		return INF
	return -log(maxf(1.0 - rng.randf(), 0.000000000001)) / rate


func _sample_type() -> int:
	var total: float = 0.0
	for wgt in type_weights:
		total += float(wgt)
	var r: float = rng.randf() * total
	var acc: float = 0.0
	for i in range(type_weights.size()):
		acc += float(type_weights[i])
		if r <= acc:
			return i
	return 0


func queue_size() -> int:
	return queue.size() - q_head


func queue_type_at(k: int) -> int:
	return int(queue[q_head + k]["type"])


func busy_count() -> int:
	var n: int = 0
	for i in range(MAX_SERVERS):
		if srv_type[i] >= 0:
			n += 1
	return n


## Quantidade de faixas a desenhar (inclui servidores "fechando" ainda ocupados).
func lanes_visible() -> int:
	var n: int = c
	for i in range(c, MAX_SERVERS):
		if srv_type[i] >= 0:
			n = i + 1
	return n


# --------------------------------------------------------------- estatísticas

func utilization() -> float:
	return busy_time / cap_time if cap_time > 0.0 else 0.0


func avg_lq() -> float:
	return area_q / clock if clock > 0.0 else 0.0


func avg_wq() -> float:
	return sum_wq / float(started) if started > 0 else 0.0


func avg_w() -> float:
	return sum_w / float(served) if served > 0 else 0.0


func p_wait() -> float:
	return float(waited) / float(started) if started > 0 else 0.0
