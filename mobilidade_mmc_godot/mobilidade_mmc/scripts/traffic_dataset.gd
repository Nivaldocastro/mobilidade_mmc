extends RefCounted
## Carrega o dataset de mobilidade urbana (CSV).
## Colunas: Time, Date, Day of the week, CarCount, BikeCount, BusCount,
##          TruckCount, Total, Traffic Situation
## Cada linha = contagem de veículos em um intervalo de 15 minutos.

const WEEKDAYS_PT := {
	"Monday": "Segunda",
	"Tuesday": "Terça",
	"Wednesday": "Quarta",
	"Thursday": "Quinta",
	"Friday": "Sexta",
	"Saturday": "Sábado",
	"Sunday": "Domingo",
}

var rows: Array = []          # todas as linhas (Dictionary)
var dates: Array = []         # dias (Date) únicos, ordenados
var by_date: Dictionary = {}  # Date -> Array de linhas ordenadas por horário
var source_path: String = ""


func clear() -> void:
	rows = []
	dates = []
	by_date = {}
	source_path = ""


func has_data() -> bool:
	return not rows.is_empty()


func load_from_file(path: String) -> Error:
	clear()
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return FileAccess.get_open_error()

	var header: PackedStringArray = f.get_csv_line()
	if header.size() == 0:
		return ERR_INVALID_DATA
	header[0] = header[0].trim_prefix("\uFEFF")   # remove BOM, se houver

	var col: Dictionary = {}
	for i in range(header.size()):
		col[header[i].strip_edges().to_lower()] = i
	var needed: Array = ["time", "date", "day of the week", "carcount", "bikecount",
			"buscount", "truckcount", "total", "traffic situation"]
	for key in needed:
		if not col.has(key):
			return ERR_INVALID_DATA

	while not f.eof_reached():
		var line: PackedStringArray = f.get_csv_line()
		if line.size() < header.size():
			continue
		var row: Dictionary = {
			"minute": _parse_minute(line[int(col["time"])]),
			"date": line[int(col["date"])].to_int(),
			"dow": line[int(col["day of the week"])].strip_edges(),
			"car": line[int(col["carcount"])].to_int(),
			"bike": line[int(col["bikecount"])].to_int(),
			"bus": line[int(col["buscount"])].to_int(),
			"truck": line[int(col["truckcount"])].to_int(),
			"total": line[int(col["total"])].to_int(),
			"situation": line[int(col["traffic situation"])].strip_edges().to_lower(),
		}
		rows.append(row)
		var d: int = int(row["date"])
		if not by_date.has(d):
			by_date[d] = []
		by_date[d].append(row)

	if rows.is_empty():
		return ERR_INVALID_DATA

	dates = by_date.keys()
	dates.sort()
	for d in dates:
		var arr: Array = by_date[d]
		arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["minute"]) < int(b["minute"]))
	source_path = path
	return OK


## Aceita "1900-01-01 00:15:00", "00:15", "12:15 AM" etc. Devolve minutos do dia.
static func _parse_minute(text: String) -> int:
	var t: String = text.strip_edges()
	var upper: String = t.to_upper()
	var token: String = ""
	for part in t.split(" "):
		if ":" in part:
			token = part
	if token == "":
		return 0
	var hm: PackedStringArray = token.split(":")
	var h: int = hm[0].to_int()
	var m: int = hm[1].to_int() if hm.size() > 1 else 0
	if upper.ends_with("PM") and h < 12:
		h += 12
	elif upper.ends_with("AM") and h == 12:
		h = 0
	return h * 60 + m


func get_day(date: int) -> Array:
	if by_date.has(date):
		return by_date[date]
	return []


func day_size(date: int) -> int:
	return get_day(date).size()


func get_row(date: int, idx: int) -> Dictionary:
	var arr: Array = get_day(date)
	if arr.is_empty():
		return {}
	return arr[clampi(idx, 0, arr.size() - 1)]


func weekday_pt(date: int) -> String:
	var arr: Array = get_day(date)
	if arr.is_empty():
		return ""
	var dow: String = str(arr[0]["dow"])
	return str(WEEKDAYS_PT.get(dow, dow))
