extends RefCounted
## Fórmulas analíticas do modelo de filas M/M/c (Erlang C).
##
## Convenção de unidades: taxas em veículos/SEGUNDO, tempos devolvidos em SEGUNDOS.
##   lam = λ  (taxa média de chegada)
##   mu  = μ  (taxa média de atendimento de UM servidor)
##   c   = número de servidores
##   a   = λ/μ  (carga oferecida, em Erlangs)
##   ρ   = a/c  (utilização por servidor; o sistema só é estável se ρ < 1)


static func compute(lam: float, mu: float, c: int) -> Dictionary:
	var res: Dictionary = {
		"stable": false,
		"a": 0.0,
		"rho": 0.0,
		"p0": 0.0,   # probabilidade de sistema vazio
		"pw": 0.0,   # probabilidade de esperar (fórmula C de Erlang)
		"lq": 0.0,   # nº médio de veículos na fila
		"wq": 0.0,   # tempo médio de espera na fila (s)
		"w": 0.0,    # tempo médio no sistema (s)
		"l": 0.0,    # nº médio de veículos no sistema
	}
	if mu <= 0.0 or c < 1:
		return res

	var a: float = lam / mu
	var rho: float = a / float(c)
	res["a"] = a
	res["rho"] = rho

	if lam <= 0.0:
		res["stable"] = true
		res["p0"] = 1.0
		res["w"] = 1.0 / mu
		return res
	if rho >= 1.0:
		return res   # instável: as médias tendem ao infinito

	# soma_{k=0}^{c-1} a^k / k!   (calculada de forma iterativa, sem overflow)
	var term: float = 1.0
	var acc: float = 1.0
	for k in range(1, c):
		term *= a / float(k)
		acc += term
	var term_c: float = term * a / float(c)      # a^c / c!
	var last: float = term_c / (1.0 - rho)
	var p0: float = 1.0 / (acc + last)
	var pw: float = last * p0
	var lq: float = pw * rho / (1.0 - rho)
	var wq: float = lq / lam                       # Lei de Little
	var w: float = wq + 1.0 / mu

	res["stable"] = true
	res["p0"] = p0
	res["pw"] = pw
	res["lq"] = lq
	res["wq"] = wq
	res["w"] = w
	res["l"] = lam * w
	return res
