# ACIERTA v0.0.0.1 — GUÍA ÚNICA COPIAR/PEGAR

Esta guía sustituye los bloques dispersos de la conversación. **Use solamente el código de este documento.** Cada función aparece una sola vez.

## Antes de empezar

- Motor recomendado para esta revisión: **Godot 4.7.1 Standard (GDScript)**.
- Renderer al crear el proyecto: **Compatibility**.
- Objetivo de esta versión: **Lotto + Lotto Revancha**. Los otros juegos quedan visibles como “Próximamente” y deshabilitados.
- Para reducir errores de ensamblaje, la interfaz se construye desde scripts. Solo hay que crear manualmente una escena mínima: `ui/main/main.tscn`.
- Los datos oficiales, predicciones, evaluaciones, marcas manuales y modelos quedan en archivos separados.

## DOS FORMAS DE USAR ESTA ENTREGA

### Opción A — recomendada
Descomprima `Acierta_v0.0.0.1.zip`, abra Godot y seleccione el `project.godot`. No tiene que copiar 37 archivos a mano.

### Opción B — copiar/pegar manual
Siga los pasos de este documento en orden. Cree el archivo indicado y pegue **todo** su bloque de código.

## PASO 0 — Crear el proyecto en Godot

1. Abra Godot 4.7.1.
2. Pulse **Create / Crear proyecto**.
3. Nombre: `Acierta`.
4. Renderer: **Compatibility**.
5. Cree el proyecto.
6. Cree las carpetas del PASO 1.
7. Reemplace el `project.godot` creado por el del PASO 2.

## PASO 1 — Estructura de carpetas

```text
Acierta_v0.0.0.1/
├── project.godot
├── autoload/
│   ├── app_paths.gd
│   ├── database.gd
│   ├── model_registry.gd
│   ├── prediction_store.gd
│   ├── feedback_store.gd
│   └── evaluation_store.gd
├── core/
│   ├── date_utils.gd
│   ├── game_profile.gd
│   ├── json_file_store.gd
│   ├── statistics_engine.gd
│   ├── combination_score_engine.gd
│   ├── confidence_engine.gd
│   ├── combination_generator.gd
│   ├── prediction_query_service.gd
│   ├── learning_metrics_engine.gd
│   ├── confidence_calibration_engine.gd
│   ├── dashboard_summary_engine.gd
│   ├── backtester.gd
│   ├── weight_optimizer.gd
│   └── project_audit.gd
├── ui/
│   ├── common/
│   │   ├── number_ball.gd
│   │   ├── attention_alert_button.gd
│   │   └── ui_helpers.gd
│   ├── panels/
│   │   ├── home_dashboard_panel.gd
│   │   ├── input_result_panel.gd
│   │   ├── generator_panel.gd
│   │   ├── statistics_panel.gd
│   │   ├── history_panel.gd
│   │   ├── comparison_panel.gd
│   │   ├── backtesting_panel.gd
│   │   └── settings_panel.gd
│   └── main/
│       ├── main.gd
│       └── main.tscn
└── tests/
    ├── lotto_test_fixtures.gd
    ├── smoke_runner.gd
    └── smoke_runner.tscn
```

> No cree `user://acierta` manualmente. Acierta lo crea al ejecutarse.

## PASO 2 — Archivo del proyecto

**Crear:** `project.godot`

```ini
; Engine configuration file.
; Acierta v0.0.0.1

config_version=5

[application]
config/name="Acierta"
config/version="0.0.0.1"
run/main_scene="res://ui/main/main.tscn"

[autoload]
AppPaths="*res://autoload/app_paths.gd"
Database="*res://autoload/database.gd"
ModelRegistry="*res://autoload/model_registry.gd"
PredictionStore="*res://autoload/prediction_store.gd"
FeedbackStore="*res://autoload/feedback_store.gd"
EvaluationStore="*res://autoload/evaluation_store.gd"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/size/window_width_override=1280
window/size/window_height_override=720
window/size/resizable=true
window/stretch/mode="canvas_items"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
```

## PASO 3A — Utilidad de fechas

**Crear:** `core/date_utils.gd`

```gdscript
class_name DateUtils
extends RefCounted

static func normalize_date(text: String) -> String:
    var value := text.strip_edges()
    if value.is_empty():
        return ""
    if value.contains("/"):
        var p := value.split("/")
        if p.size() != 3:
            return ""
        var day := int(p[0])
        var month := int(p[1])
        var year := int(p[2])
        if not _valid_date(year, month, day):
            return ""
        return "%04d-%02d-%02d" % [year, month, day]
    if value.contains("-"):
        var p := value.split("-")
        if p.size() != 3:
            return ""
        var year := int(p[0])
        var month := int(p[1])
        var day := int(p[2])
        if not _valid_date(year, month, day):
            return ""
        return "%04d-%02d-%02d" % [year, month, day]
    return ""

static func today() -> String:
    return Time.get_date_string_from_system()

static func display(iso_date: String) -> String:
    var n := normalize_date(iso_date)
    if n.is_empty():
        return iso_date
    var p := n.split("-")
    return "%s/%s/%s" % [p[2], p[1], p[0]]

static func _valid_date(year: int, month: int, day: int) -> bool:
    if year < 1900 or year > 2200 or month < 1 or month > 12 or day < 1:
        return false
    var days := [31, 28 + (1 if _is_leap(year) else 0), 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    return day <= days[month - 1]

static func _is_leap(year: int) -> bool:
    return year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)
```

## PASO 3B — Perfil Lotto 00–40

**Crear:** `core/game_profile.gd`

```gdscript
class_name GameProfile
extends RefCounted

var id := "lotto_cr"
var title := "Lotto Costa Rica"
var min_number := 0
var max_number := 40
var numbers_per_draw := 5
var display_digits := 2
var suggestion_count := 5

static func lotto_costa_rica() -> GameProfile:
    return GameProfile.new()

static func custom_00_40_six() -> GameProfile:
    var p := GameProfile.new()
    p.id = "custom_00_40_6"
    p.title = "Experimental 6 de 41"
    p.numbers_per_draw = 6
    return p

func is_valid_number(value: int) -> bool:
    return value >= min_number and value <= max_number

func format_number(value: int) -> String:
    return ("%0*d" % [display_digits, value])

func validate_numbers(values: Array) -> Dictionary:
    if values.size() != numbers_per_draw:
        return {"ok": false, "message": "Se requieren exactamente %d números." % numbers_per_draw}
    var seen := {}
    for raw in values:
        var value := int(raw)
        if not is_valid_number(value):
            return {"ok": false, "message": "El número %d está fuera del rango %02d-%02d." % [value, min_number, max_number]}
        if seen.has(value):
            return {"ok": false, "message": "El número %02d está repetido." % value}
        seen[value] = true
    return {"ok": true, "message": ""}
```

## PASO 3C — Persistencia segura JSON

**Crear:** `core/json_file_store.gd`

```gdscript
class_name JsonFileStore
extends RefCounted

static func read_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"ok": false, "message": "Archivo inexistente: %s" % path}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"ok": false, "message": "No se pudo abrir: %s" % path}
    var text := file.get_as_text()
    file.close()
    var json := JSON.new()
    var err := json.parse(text)
    if err != OK:
        return {"ok": false, "message": "JSON inválido en %s: %s" % [path, json.get_error_message()]}
    if typeof(json.data) != TYPE_DICTIONARY:
        return {"ok": false, "message": "El JSON no contiene un Dictionary: %s" % path}
    return {"ok": true, "data": json.data}

static func write_dictionary(path: String, content: Dictionary) -> Dictionary:
    var dir_path := path.get_base_dir()
    var mk := DirAccess.make_dir_recursive_absolute(dir_path)
    if mk != OK and not DirAccess.dir_exists_absolute(dir_path):
        return {"ok": false, "message": "No se pudo crear %s" % dir_path}

    var current_sequence := 0
    if FileAccess.file_exists(path):
        var old := read_dictionary(path)
        if old.get("ok", false):
            current_sequence = int(old["data"].get("_commit", {}).get("sequence", 0))

    var payload := content.duplicate(true)
    payload["_commit"] = {
        "sequence": current_sequence + 1,
        "written_at": Time.get_datetime_string_from_system()
    }

    var tmp := path + ".tmp"
    var bak := path + ".bak"
    var file := FileAccess.open(tmp, FileAccess.WRITE)
    if file == null:
        return {"ok": false, "message": "No se pudo abrir temporal: %s" % tmp}
    if not file.store_string(JSON.stringify(payload, "\t", true, true)):
        file.close()
        return {"ok": false, "message": "No se pudo escribir temporal: %s" % tmp}
    file.flush()
    file.close()

    var verify := read_dictionary(tmp)
    if not verify.get("ok", false):
        DirAccess.remove_absolute(tmp)
        return {"ok": false, "message": "El temporal no superó la verificación."}

    if FileAccess.file_exists(path):
        var copy_err := DirAccess.copy_absolute(path, bak)
        if copy_err != OK:
            DirAccess.remove_absolute(tmp)
            return {"ok": false, "message": "No se pudo crear la copia inmediata .bak"}

    var rename_err := DirAccess.rename_absolute(tmp, path)
    if rename_err != OK:
        return {"ok": false, "message": "No se pudo confirmar la escritura."}

    var final_check := read_dictionary(path)
    if not final_check.get("ok", false):
        return {"ok": false, "message": "El archivo final no pasó la verificación."}
    return {"ok": true, "data": final_check["data"]}

static func recover_dictionary(path: String) -> Dictionary:
    var candidates: Array[Dictionary] = []
    for candidate_path in [path, path + ".tmp", path + ".bak"]:
        if not FileAccess.file_exists(candidate_path):
            continue
        var r := read_dictionary(candidate_path)
        if not r.get("ok", false):
            continue
        candidates.append({
            "path": candidate_path,
            "data": r["data"],
            "sequence": int(r["data"].get("_commit", {}).get("sequence", 0))
        })
    if candidates.is_empty():
        return {"ok": false, "message": "No existe una copia válida de %s" % path}
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["sequence"]) > int(b["sequence"]))
    var winner := candidates[0]
    if str(winner["path"]) != path:
        var copy_err := DirAccess.copy_absolute(str(winner["path"]), path)
        if copy_err != OK:
            return {"ok": false, "message": "No se pudo restaurar %s" % path}
    if FileAccess.file_exists(path + ".tmp"):
        DirAccess.remove_absolute(path + ".tmp")
    var final := read_dictionary(path)
    if not final.get("ok", false):
        return final
    return {"ok": true, "data": final["data"], "recovered": str(winner["path"]) != path}

static func has_any_copy(path: String) -> bool:
    return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".tmp") or FileAccess.file_exists(path + ".bak")

static func write_interrupted_temp_for_test(path: String, content: Dictionary) -> Dictionary:
    if not AppPaths.test_mode:
        return {"ok": false, "message": "Solo disponible en modo de prueba."}
    var current_sequence := 0
    if FileAccess.file_exists(path):
        var current := read_dictionary(path)
        if current.get("ok", false):
            current_sequence = int(current["data"].get("_commit", {}).get("sequence", 0))
    var payload := content.duplicate(true)
    payload["_commit"] = {
        "sequence": current_sequence + 1,
        "written_at": Time.get_datetime_string_from_system()
    }
    var tmp := path + ".tmp"
    var file := FileAccess.open(tmp, FileAccess.WRITE)
    if file == null:
        return {"ok": false, "message": "No se pudo crear temporal de prueba."}
    var ok := file.store_string(JSON.stringify(payload, "\t", true, true))
    file.flush()
    file.close()
    return {"ok": ok}
```

## PASO 4A — Motor estadístico

**Crear:** `core/statistics_engine.gd`

```gdscript
class_name StatisticsEngine
extends RefCounted

enum AnalysisSource { LOTTO_ONLY, REVANCHA_ONLY, BOTH }

static func extract_samples(draws: Array, source: int) -> Array[Dictionary]:
    var sorted := draws.duplicate(true)
    sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if str(a.get("date", "")) == str(b.get("date", "")):
            return str(a.get("draw_number", "")) < str(b.get("draw_number", ""))
        return str(a.get("date", "")) < str(b.get("date", ""))
    )
    var samples: Array[Dictionary] = []
    for draw in sorted:
        if (source == AnalysisSource.LOTTO_ONLY or source == AnalysisSource.BOTH) and bool(draw.get("lotto_enabled", false)):
            samples.append({"record_id": draw.get("record_id", ""), "date": draw.get("date", ""), "draw_number": draw.get("draw_number", ""), "type": "lotto", "numbers": draw.get("lotto", []).duplicate()})
        if (source == AnalysisSource.REVANCHA_ONLY or source == AnalysisSource.BOTH) and bool(draw.get("revancha_enabled", false)):
            samples.append({"record_id": draw.get("record_id", ""), "date": draw.get("date", ""), "draw_number": draw.get("draw_number", ""), "type": "revancha", "numbers": draw.get("revancha", []).duplicate()})
    return samples

static func analyze(draws: Array, source: int, profile: GameProfile = null) -> Dictionary:
    if profile == null:
        profile = GameProfile.lotto_costa_rica()
    var samples := extract_samples(draws, source)
    var total_samples := samples.size()
    var frequency := {}
    var recent_frequency := {}
    var absence := {}
    var pair_frequency := {}
    var trio_frequency := {}
    var monthly_frequency := {}
    var sum_values: Array[float] = []
    var span_values: Array[float] = []
    var even_values: Array[float] = []
    var low_values: Array[float] = []
    var consecutive_values: Array[float] = []
    for n in range(profile.min_number, profile.max_number + 1):
        frequency[n] = 0
        recent_frequency[n] = 0
        absence[n] = total_samples
    for i in range(total_samples):
        var numbers: Array = samples[i]["numbers"].duplicate()
        numbers.sort()
        var month := str(samples[i].get("date", "")).substr(5, 2)
        if not monthly_frequency.has(month):
            monthly_frequency[month] = {}
        for raw in numbers:
            var n := int(raw)
            frequency[n] = int(frequency.get(n, 0)) + 1
            monthly_frequency[month][n] = int(monthly_frequency[month].get(n, 0)) + 1
            absence[n] = total_samples - 1 - i
        for a in range(numbers.size()):
            for b in range(a + 1, numbers.size()):
                var pk := "%02d-%02d" % [int(numbers[a]), int(numbers[b])]
                pair_frequency[pk] = int(pair_frequency.get(pk, 0)) + 1
                for c in range(b + 1, numbers.size()):
                    var tk := "%02d-%02d-%02d" % [int(numbers[a]), int(numbers[b]), int(numbers[c])]
                    trio_frequency[tk] = int(trio_frequency.get(tk, 0)) + 1
        var total := 0
        var evens := 0
        var lows := 0
        var consecutive := 0
        for j in range(numbers.size()):
            total += int(numbers[j])
            if int(numbers[j]) % 2 == 0:
                evens += 1
            if int(numbers[j]) <= 20:
                lows += 1
            if j > 0 and int(numbers[j]) == int(numbers[j - 1]) + 1:
                consecutive += 1
        sum_values.append(float(total))
        span_values.append(float(int(numbers[-1]) - int(numbers[0])) if not numbers.is_empty() else 0.0)
        even_values.append(float(evens))
        low_values.append(float(lows))
        consecutive_values.append(float(consecutive))
    var recent_count := min(10, total_samples)
    for i in range(max(0, total_samples - recent_count), total_samples):
        for raw in samples[i]["numbers"]:
            var n := int(raw)
            recent_frequency[n] = int(recent_frequency.get(n, 0)) + 1
    return {
        "sample_count": total_samples,
        "frequency": frequency,
        "recent_frequency": recent_frequency,
        "absence": absence,
        "pairs": pair_frequency,
        "trios": trio_frequency,
        "monthly": monthly_frequency,
        "shape": {
            "avg_sum": _avg(sum_values),
            "avg_span": _avg(span_values),
            "avg_even": _avg(even_values),
            "avg_low": _avg(low_values),
            "avg_consecutive": _avg(consecutive_values)
        }
    }

static func same_draw_overlap(draws: Array) -> Dictionary:
    var counts := {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
    var total := 0
    for draw in draws:
        if not bool(draw.get("lotto_enabled", false)) or not bool(draw.get("revancha_enabled", false)):
            continue
        total += 1
        var hits := 0
        for n in draw.get("lotto", []):
            if int(n) in draw.get("revancha", []):
                hits += 1
        counts[hits] = int(counts.get(hits, 0)) + 1
    return {"events": total, "overlap_counts": counts}

static func _avg(values: Array[float]) -> float:
    if values.is_empty():
        return 0.0
    var s := 0.0
    for v in values:
        s += v
    return s / values.size()
```

## PASO 4B — Motor de puntuación

**Crear:** `core/combination_score_engine.gd`

```gdscript
class_name CombinationScoreEngine
extends RefCounted

const MODEL_VERSION := "score_v1"
const DEFAULT_WEIGHTS := {
    "individual_total": 0.20,
    "individual_recent": 0.20,
    "pairs": 0.20,
    "trios": 0.10,
    "distribution": 0.20,
    "repetition": 0.10
}

var profile: GameProfile
var weights: Dictionary = DEFAULT_WEIGHTS.duplicate(true)

func _init(p: GameProfile = null) -> void:
    profile = p if p != null else GameProfile.lotto_costa_rica()

func get_weights_snapshot() -> Dictionary:
    return weights.duplicate(true)

func set_weights(value: Dictionary) -> Dictionary:
    var validation := validate_weight_profile(value)
    if not validation.get("ok", false):
        return validation
    weights = value.duplicate(true)
    return {"ok": true}

func validate_weight_profile(value: Dictionary) -> Dictionary:
    var sum := 0.0
    for key in DEFAULT_WEIGHTS.keys():
        if not value.has(key):
            return {"ok": false, "message": "Falta peso: %s" % key}
        var w := float(value[key])
        if w < 0.0:
            return {"ok": false, "message": "Peso negativo: %s" % key}
        sum += w
    if abs(sum - 1.0) > 0.001:
        return {"ok": false, "message": "Los pesos deben sumar 1.0"}
    return {"ok": true}

func get_model_signature() -> String:
    return (MODEL_VERSION + "|" + JSON.stringify(weights, "", true, true)).sha256_text()

func prepare_context(draws: Array, source: int) -> Dictionary:
    return {
        "stats": StatisticsEngine.analyze(draws, source, profile),
        "last_numbers": _last_numbers(draws, source)
    }

func score_candidate(numbers: Array, context: Dictionary) -> Dictionary:
    var stats: Dictionary = context.get("stats", {})
    var sample_count := int(stats.get("sample_count", 0))
    if sample_count <= 0:
        return {"score": 0.0, "components": {}, "coverage": 0.0}
    var components := {
        "individual_total": _individual_component(numbers, stats.get("frequency", {}), sample_count),
        "individual_recent": _individual_component(numbers, stats.get("recent_frequency", {}), min(10, sample_count)),
        "pairs": _pair_component(numbers, stats.get("pairs", {}), sample_count),
        "trios": _trio_component(numbers, stats.get("trios", {}), sample_count),
        "distribution": _distribution_component(numbers, stats.get("shape", {})),
        "repetition": _repetition_component(numbers, context.get("last_numbers", []))
    }
    var available := {
        "individual_total": sample_count >= 5,
        "individual_recent": sample_count >= 5,
        "pairs": sample_count >= 10,
        "trios": sample_count >= 20,
        "distribution": sample_count >= 10,
        "repetition": sample_count >= 10
    }
    var score := compose_score_from_components(components, available)
    var active := 0
    for key in available:
        if available[key]:
            active += 1
    return {"score": score, "components": components, "coverage": 100.0 * active / available.size()}

func compose_score_from_components(components: Dictionary, available: Dictionary) -> float:
    var active_weight := 0.0
    for key in weights:
        if bool(available.get(key, false)):
            active_weight += float(weights[key])
    if active_weight <= 0.0:
        return 0.0
    var total := 0.0
    for key in weights:
        if bool(available.get(key, false)):
            total += float(components.get(key, 0.0)) * float(weights[key]) / active_weight
    return clamp(total, 0.0, 100.0)

func _individual_component(numbers: Array, freq: Dictionary, samples: int) -> float:
    if samples <= 0:
        return 50.0
    var expected := float(profile.numbers_per_draw) / float(profile.max_number - profile.min_number + 1)
    var values: Array[float] = []
    for n in numbers:
        var observed := float(freq.get(int(n), 0)) / samples
        values.append(clamp(50.0 + (observed - expected) / max(expected, 0.001) * 25.0, 0.0, 100.0))
    return _avg(values)

func _pair_component(numbers: Array, pairs: Dictionary, samples: int) -> float:
    var values: Array[float] = []
    for a in range(numbers.size()):
        for b in range(a + 1, numbers.size()):
            var key := "%02d-%02d" % [int(numbers[a]), int(numbers[b])]
            values.append(clamp(float(pairs.get(key, 0)) / max(samples, 1) * 500.0, 0.0, 100.0))
    return _avg(values) if not values.is_empty() else 50.0

func _trio_component(numbers: Array, trios: Dictionary, samples: int) -> float:
    var values: Array[float] = []
    for a in range(numbers.size()):
        for b in range(a + 1, numbers.size()):
            for c in range(b + 1, numbers.size()):
                var key := "%02d-%02d-%02d" % [int(numbers[a]), int(numbers[b]), int(numbers[c])]
                values.append(clamp(float(trios.get(key, 0)) / max(samples, 1) * 1000.0, 0.0, 100.0))
    return _avg(values) if not values.is_empty() else 50.0

func _distribution_component(numbers: Array, shape: Dictionary) -> float:
    var sorted := numbers.duplicate()
    sorted.sort()
    var sum := 0.0
    var even := 0.0
    var low := 0.0
    var consecutive := 0.0
    for i in range(sorted.size()):
        sum += int(sorted[i])
        if int(sorted[i]) % 2 == 0: even += 1.0
        if int(sorted[i]) <= 20: low += 1.0
        if i > 0 and int(sorted[i]) == int(sorted[i - 1]) + 1: consecutive += 1.0
    var span := float(int(sorted[-1]) - int(sorted[0]))
    var penalties := [
        abs(sum - float(shape.get("avg_sum", sum))) / 25.0,
        abs(span - float(shape.get("avg_span", span))) / 10.0,
        abs(even - float(shape.get("avg_even", even))) / 2.0,
        abs(low - float(shape.get("avg_low", low))) / 2.0,
        abs(consecutive - float(shape.get("avg_consecutive", consecutive))) / 2.0
    ]
    var p := 0.0
    for v in penalties: p += float(v)
    return clamp(100.0 - p / penalties.size() * 40.0, 0.0, 100.0)

func _repetition_component(numbers: Array, last_numbers: Array) -> float:
    if last_numbers.is_empty():
        return 50.0
    var repeated := 0
    for n in numbers:
        if int(n) in last_numbers: repeated += 1
    return [65.0, 80.0, 65.0, 35.0, 10.0, 0.0][clamp(repeated, 0, 5)]

func _last_numbers(draws: Array, source: int) -> Array:
    var samples := StatisticsEngine.extract_samples(draws, source)
    return [] if samples.is_empty() else samples[-1].get("numbers", []).duplicate()

func _avg(values: Array[float]) -> float:
    if values.is_empty(): return 50.0
    var s := 0.0
    for v in values: s += v
    return s / values.size()
```

## PASO 4C — Confianza relativa y alerta 90+

**Crear:** `core/confidence_engine.gd`

```gdscript
class_name ConfidenceEngine
extends RefCounted

const METHOD_VERSION := "relative_confidence_v1"
const ATTENTION_VERSION := "attention_v1"
const ATTENTION_THRESHOLD := 90.0
const ATTENTION_MIN_EVIDENCE := 80.0

static func evaluate(score: float, sorted_scores: Array[float], coverage: float) -> Dictionary:
    if sorted_scores.is_empty():
        return _gray(score, coverage)
    var mean := 0.0
    for v in sorted_scores: mean += v
    mean /= sorted_scores.size()
    var variance := 0.0
    for v in sorted_scores: variance += pow(v - mean, 2)
    variance /= sorted_scores.size()
    var std := sqrt(variance)
    var minimum := sorted_scores[0]
    var maximum := sorted_scores[-1]
    var below := 0
    for v in sorted_scores:
        if v <= score: below += 1
    var percentile := 100.0 * below / sorted_scores.size()
    var z := (score - mean) / std if std > 0.0001 else 0.0
    var separation := clamp(50.0 + z * 25.0, 0.0, 100.0)
    var relative_index := percentile * 0.4 + separation * 0.4 + coverage * 0.2
    var state := "gray"
    if sorted_scores.size() < 100 or coverage < 50.0 or std < 0.25 or maximum - minimum < 2.0:
        state = "gray"
    elif percentile >= 99.5 and z >= 2.0 and score - mean >= 5.0 and coverage >= 80.0:
        state = "green"
    elif percentile >= 95.0 and z >= 1.0 and score - mean >= 2.0 and coverage >= 60.0:
        state = "yellow"
    elif percentile <= 50.0 or z < 0.0:
        state = "red"
    return {
        "method": METHOD_VERSION,
        "state": state,
        "relative_index": relative_index,
        "percentile": percentile,
        "z_score": z,
        "evidence_coverage": coverage,
        "pool_mean": mean,
        "pool_std": std,
        "pool_min": minimum,
        "pool_max": maximum
    }

static func should_trigger_attention(confidence: Dictionary) -> bool:
    return float(confidence.get("relative_index", 0.0)) >= ATTENTION_THRESHOLD and float(confidence.get("evidence_coverage", 0.0)) >= ATTENTION_MIN_EVIDENCE and str(confidence.get("state", "gray")) in ["green", "yellow"]

static func _gray(score: float, coverage: float) -> Dictionary:
    return {"method": METHOD_VERSION, "state": "gray", "relative_index": 0.0, "percentile": 0.0, "z_score": 0.0, "evidence_coverage": coverage, "pool_mean": score, "pool_std": 0.0, "pool_min": score, "pool_max": score}
```

## PASO 4D — Generador de combinaciones

**Crear:** `core/combination_generator.gd`

```gdscript
class_name CombinationGenerator
extends RefCounted

const MIN_CANDIDATES := 50
const MAX_CANDIDATES := 2500

var profile: GameProfile
var score_engine: CombinationScoreEngine
var active_model: Dictionary = {}

func _init(p: GameProfile = null) -> void:
    profile = p if p != null else GameProfile.lotto_costa_rica()
    score_engine = CombinationScoreEngine.new(profile)

func apply_model(model: Dictionary) -> Dictionary:
    if model.is_empty():
        return {"ok": false, "message": "Modelo vacío."}
    var r := score_engine.set_weights(model.get("weights", {}))
    if not r.get("ok", false):
        return r
    active_model = model.duplicate(true)
    return {"ok": true}

func generate(draws: Array, analysis_source: int, candidate_count: int = 1000, fixed_seed: int = 0) -> Dictionary:
    if draws.size() < 12:
        return {"ok": false, "message": "Se requieren al menos 12 resultados."}
    if active_model.is_empty():
        return {"ok": false, "message": "Debe aplicar un modelo activo."}
    candidate_count = clamp(candidate_count, MIN_CANDIDATES, MAX_CANDIDATES)
    var seed_value := fixed_seed if fixed_seed != 0 else int(Time.get_ticks_usec() & 0x7fffffff)
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var context := score_engine.prepare_context(draws, analysis_source)
    var seen := {}
    var candidates: Array[Dictionary] = []
    var attempts := 0
    while candidates.size() < candidate_count and attempts < candidate_count * 20:
        attempts += 1
        var nums: Array[int] = []
        while nums.size() < profile.numbers_per_draw:
            var n := rng.randi_range(profile.min_number, profile.max_number)
            if n not in nums: nums.append(n)
        nums.sort()
        var key := JSON.stringify(nums)
        if seen.has(key): continue
        seen[key] = true
        var scored := score_engine.score_candidate(nums, context)
        candidates.append({"numbers": nums, "score": float(scored["score"]), "components": scored["components"], "coverage": float(scored["coverage"])})
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
    if candidates.size() < 10:
        return {"ok": false, "message": "No se generaron suficientes candidatos."}
    var scores: Array[float] = []
    for c in candidates: scores.append(float(c["score"]))
    scores.sort()
    for i in range(candidates.size()):
        candidates[i]["rank"] = i + 1
        candidates[i]["confidence"] = ConfidenceEngine.evaluate(float(candidates[i]["score"]), scores, float(candidates[i]["coverage"]))
    var top10 := _diversified(candidates, 10)
    for i in range(top10.size()): top10[i]["display_rank"] = i + 1
    var top5: Array[Dictionary] = []
    for i in range(min(5, top10.size())): top5.append(top10[i].duplicate(true))
    var best: Dictionary = candidates[0].duplicate(true)
    best["display_rank"] = 1
    var alert := {"triggered": false, "version": ConfidenceEngine.ATTENTION_VERSION}
    if ConfidenceEngine.should_trigger_attention(best["confidence"]):
        alert = {
            "triggered": true,
            "version": ConfidenceEngine.ATTENTION_VERSION,
            "rank": 1,
            "numbers": best["numbers"].duplicate(),
            "score": best["score"],
            "relative_index": best["confidence"].get("relative_index", 0.0),
            "state": best["confidence"].get("state", "gray"),
            "message": "POSIBLE COMBINACIÓN"
        }
    var mean := 0.0
    for v in scores: mean += v
    mean /= scores.size()
    var variance := 0.0
    for v in scores: variance += pow(v - mean, 2)
    variance /= scores.size()
    return {
        "ok": true,
        "generated_at": Time.get_datetime_string_from_system(),
        "database_version": Database.get_database_version(),
        "analysis_source": analysis_source,
        "model_id": active_model.get("model_id", ""),
        "model_label": active_model.get("label", ""),
        "model_version": active_model.get("model_version", CombinationScoreEngine.MODEL_VERSION),
        "model_signature": active_model.get("signature", ""),
        "model_weights": active_model.get("weights", {}).duplicate(true),
        "generation_seed": seed_value,
        "candidate_count": candidates.size(),
        "pool_statistics": {"minimum": scores[0], "maximum": scores[-1], "mean": mean, "std": sqrt(variance)},
        "confidence_method": ConfidenceEngine.METHOD_VERSION,
        "attention_alert": alert,
        "best": best,
        "top_5": top5,
        "top_10": top10
    }

func _diversified(candidates: Array[Dictionary], wanted: int) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for max_shared in [3, 4, 5]:
        for candidate in candidates:
            if candidate in result: continue
            var allowed := true
            for chosen in result:
                var shared := 0
                for n in candidate["numbers"]:
                    if n in chosen["numbers"]: shared += 1
                if shared > max_shared:
                    allowed = false
                    break
            if allowed:
                result.append(candidate.duplicate(true))
                if result.size() >= wanted: return result
    return result
```

## PASO 5A — Rutas de datos

**Crear:** `autoload/app_paths.gd`

```gdscript
extends Node

const NORMAL_ROOT := "user://acierta"
const TEST_ROOT := "user://acierta_test"

var test_mode := false

func _ready() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument == "--acierta-test" or argument == "--acierta-test-reset":
            test_mode = true
    if test_mode and not OS.is_debug_build():
        push_error("ACIERTA: modo de prueba rechazado en compilación Release.")
        test_mode = false
    if test_mode and "--acierta-test-reset" in OS.get_cmdline_user_args():
        reset_test_root()
    DirAccess.make_dir_recursive_absolute(lotto_dir())

func root_dir() -> String:
    return TEST_ROOT if test_mode else NORMAL_ROOT

func games_dir() -> String:
    return root_dir() + "/games"

func lotto_dir() -> String:
    return games_dir() + "/lotto"

func lotto_file(filename: String) -> String:
    return lotto_dir() + "/" + filename

func reset_test_root() -> bool:
    if not test_mode or not OS.is_debug_build():
        return false
    if not DirAccess.dir_exists_absolute(TEST_ROOT):
        return true
    return _remove_tree(TEST_ROOT)

func _remove_tree(path: String) -> bool:
    var directory := DirAccess.open(path)
    if directory == null:
        return false
    for filename in directory.get_files():
        if DirAccess.remove_absolute(path + "/" + filename) != OK:
            return false
    for folder_name in directory.get_directories():
        if not _remove_tree(path + "/" + folder_name):
            return false
    return DirAccess.remove_absolute(path) == OK
```

## PASO 5B — Base de resultados oficiales

**Crear:** `autoload/database.gd`

```gdscript
extends Node

signal database_loaded
signal database_error(message: String)
signal draw_added(draw: Dictionary)
signal draw_updated(draw: Dictionary)
signal database_changed(database_version: int)

var database: Dictionary = {}

func _ready() -> void:
    _load_or_create_database()

func _database_path() -> String:
    return AppPaths.lotto_file("results.json")

func _create_empty_database() -> Dictionary:
    return {
        "schema_version": 1,
        "database_version": 0,
        "next_record_id": 1,
        "draws": []
    }

func _load_or_create_database() -> void:
    var path := _database_path()
    if not JsonFileStore.has_any_copy(path):
        var r := JsonFileStore.write_dictionary(path, _create_empty_database())
        if not r.get("ok", false):
            database_error.emit(str(r.get("message", "No se pudo crear results.json")))
            return
        database = r["data"].duplicate(true)
        database_loaded.emit()
        return
    var recovered := JsonFileStore.recover_dictionary(path)
    if not recovered.get("ok", false):
        database_error.emit(str(recovered.get("message", "No se pudo recuperar results.json")))
        return
    var loaded: Dictionary = recovered["data"]
    var validation := _validate_database_structure(loaded)
    if not validation.get("ok", false):
        database_error.emit(str(validation.get("message", "Estructura inválida")))
        return
    database = loaded.duplicate(true)
    database_loaded.emit()

func _validate_database_structure(value: Dictionary) -> Dictionary:
    for key in ["schema_version", "database_version", "next_record_id", "draws"]:
        if not value.has(key):
            return {"ok": false, "message": "results.json no contiene %s" % key}
    if typeof(value["draws"]) != TYPE_ARRAY:
        return {"ok": false, "message": "draws debe ser Array"}
    return {"ok": true}

func get_all_draws() -> Array:
    return database.get("draws", []).duplicate(true)

func get_database_version() -> int:
    return int(database.get("database_version", 0))

func get_draw_by_id(record_id: String) -> Dictionary:
    for draw in database.get("draws", []):
        if str(draw.get("record_id", "")) == record_id:
            return draw.duplicate(true)
    return {}

func get_draw_by_identity(date: String, draw_number: String, profile_id: String = "lotto_cr") -> Dictionary:
    var normalized := DateUtils.normalize_date(date)
    for draw in database.get("draws", []):
        if str(draw.get("date", "")) == normalized and str(draw.get("draw_number", "")) == draw_number and str(draw.get("profile_id", "")) == profile_id:
            return draw.duplicate(true)
    return {}

func has_result_for_target(date: String, draw_number: String, profile_id: String, target_type: String) -> bool:
    return not get_target_result(date, draw_number, profile_id, target_type).is_empty()

func get_target_result(date: String, draw_number: String, profile_id: String, target_type: String) -> Dictionary:
    var draw := get_draw_by_identity(date, draw_number, profile_id)
    if draw.is_empty():
        return {}
    var enabled_key := "lotto_enabled" if target_type == "lotto" else "revancha_enabled"
    var numbers_key := "lotto" if target_type == "lotto" else "revancha"
    if not bool(draw.get(enabled_key, false)):
        return {}
    return {
        "record_id": str(draw.get("record_id", "")),
        "revision": int(draw.get("revision", 1)),
        "date": str(draw.get("date", "")),
        "draw_number": str(draw.get("draw_number", "")),
        "profile_id": str(draw.get("profile_id", "lotto_cr")),
        "type": target_type,
        "numbers": draw.get(numbers_key, []).duplicate()
    }

func add_draw(input: Dictionary) -> Dictionary:
    var validation := _validate_draw_input(input)
    if not validation.get("ok", false):
        return {"ok": false, "error": "validation", "message": validation.get("message", "Datos inválidos")}
    var normalized := _normalize_input(input)
    if not get_draw_by_identity(normalized["date"], normalized["draw_number"], normalized["profile_id"]).is_empty():
        return {"ok": false, "error": "duplicate", "message": "El sorteo ya existe."}
    var working := database.duplicate(true)
    var sequence := int(working.get("next_record_id", 1))
    var now := Time.get_datetime_string_from_system()
    var draw := normalized.duplicate(true)
    draw["record_id"] = "DRAW-%06d" % sequence
    draw["revision"] = 1
    draw["created_at"] = now
    draw["updated_at"] = now
    working["draws"].append(draw)
    working["next_record_id"] = sequence + 1
    working["database_version"] = int(working.get("database_version", 0)) + 1
    var commit := JsonFileStore.write_dictionary(_database_path(), working)
    if not commit.get("ok", false):
        return {"ok": false, "error": "storage", "message": commit.get("message", "No se pudo guardar")}
    database = commit["data"].duplicate(true)
    draw_added.emit(draw.duplicate(true))
    database_changed.emit(get_database_version())
    return {"ok": true, "draw": draw.duplicate(true)}

func add_draws_batch(inputs: Array) -> Dictionary:
    if inputs.is_empty():
        return {"ok": false, "message": "No hay registros para importar."}
    var normalized_batch: Array[Dictionary] = []
    var batch_keys := {}
    for raw in inputs:
        var validation := _validate_draw_input(raw)
        if not validation.get("ok", false):
            return {"ok": false, "message": validation.get("message", "Registro inválido")}
        var item := _normalize_input(raw)
        var key := "%s|%s|%s" % [item["profile_id"], item["date"], item["draw_number"]]
        if batch_keys.has(key):
            return {"ok": false, "message": "Duplicado dentro del lote: %s" % key}
        if not get_draw_by_identity(item["date"], item["draw_number"], item["profile_id"]).is_empty():
            return {"ok": false, "message": "Ya existe el sorteo %s." % item["draw_number"]}
        batch_keys[key] = true
        normalized_batch.append(item)

    var working := database.duplicate(true)
    var sequence := int(working.get("next_record_id", 1))
    var now := Time.get_datetime_string_from_system()
    var added: Array[Dictionary] = []
    for item in normalized_batch:
        var draw := item.duplicate(true)
        draw["record_id"] = "DRAW-%06d" % sequence
        draw["revision"] = 1
        draw["created_at"] = now
        draw["updated_at"] = now
        working["draws"].append(draw)
        added.append(draw)
        sequence += 1
    working["next_record_id"] = sequence
    working["database_version"] = int(working.get("database_version", 0)) + 1
    var commit := JsonFileStore.write_dictionary(_database_path(), working)
    if not commit.get("ok", false):
        return {"ok": false, "message": commit.get("message", "No se pudo importar")}
    database = commit["data"].duplicate(true)
    for draw in added:
        draw_added.emit(draw.duplicate(true))
    database_changed.emit(get_database_version())
    return {"ok": true, "count": added.size()}

func update_draw(record_id: String, input: Dictionary) -> Dictionary:
    var validation := _validate_draw_input(input)
    if not validation.get("ok", false):
        return {"ok": false, "message": validation.get("message", "Datos inválidos")}
    var normalized := _normalize_input(input)
    var working := database.duplicate(true)
    var index := -1
    for i in range(working["draws"].size()):
        if str(working["draws"][i].get("record_id", "")) == record_id:
            index = i
            break
    if index < 0:
        return {"ok": false, "message": "Registro inexistente."}
    for draw in working["draws"]:
        if str(draw.get("record_id", "")) == record_id:
            continue
        if str(draw.get("date", "")) == normalized["date"] and str(draw.get("draw_number", "")) == normalized["draw_number"] and str(draw.get("profile_id", "")) == normalized["profile_id"]:
            return {"ok": false, "message": "La corrección produciría un sorteo duplicado."}
    var old: Dictionary = working["draws"][index]
    var updated := normalized.duplicate(true)
    updated["record_id"] = record_id
    updated["revision"] = int(old.get("revision", 1)) + 1
    updated["created_at"] = str(old.get("created_at", ""))
    updated["updated_at"] = Time.get_datetime_string_from_system()
    working["draws"][index] = updated
    working["database_version"] = int(working.get("database_version", 0)) + 1
    var commit := JsonFileStore.write_dictionary(_database_path(), working)
    if not commit.get("ok", false):
        return {"ok": false, "message": commit.get("message", "No se pudo actualizar")}
    database = commit["data"].duplicate(true)
    draw_updated.emit(updated.duplicate(true))
    database_changed.emit(get_database_version())
    return {"ok": true, "draw": updated.duplicate(true)}

func _normalize_input(input: Dictionary) -> Dictionary:
    var lotto: Array[int] = []
    var revancha: Array[int] = []
    if bool(input.get("lotto_enabled", false)):
        for v in input.get("lotto", []):
            lotto.append(int(v))
        lotto.sort()
    if bool(input.get("revancha_enabled", false)):
        for v in input.get("revancha", []):
            revancha.append(int(v))
        revancha.sort()
    return {
        "date": DateUtils.normalize_date(str(input.get("date", ""))),
        "draw_number": str(input.get("draw_number", "")).strip_edges(),
        "profile_id": str(input.get("profile_id", "lotto_cr")),
        "lotto_enabled": bool(input.get("lotto_enabled", false)),
        "lotto": lotto,
        "revancha_enabled": bool(input.get("revancha_enabled", false)),
        "revancha": revancha
    }

func _validate_draw_input(input: Dictionary) -> Dictionary:
    var date := DateUtils.normalize_date(str(input.get("date", "")))
    if date.is_empty():
        return {"ok": false, "message": "Fecha inválida. Use AAAA-MM-DD o DD/MM/AAAA."}
    var draw_number := str(input.get("draw_number", "")).strip_edges()
    if draw_number.is_empty():
        return {"ok": false, "message": "Falta el número de sorteo."}
    var lotto_enabled := bool(input.get("lotto_enabled", false))
    var revancha_enabled := bool(input.get("revancha_enabled", false))
    if not lotto_enabled and not revancha_enabled:
        return {"ok": false, "message": "Active Lotto, Revancha o ambas."}
    var profile := GameProfile.lotto_costa_rica()
    if lotto_enabled:
        var r := profile.validate_numbers(input.get("lotto", []))
        if not r.get("ok", false):
            return {"ok": false, "message": "Lotto: %s" % r.get("message", "")}
    if revancha_enabled:
        var r := profile.validate_numbers(input.get("revancha", []))
        if not r.get("ok", false):
            return {"ok": false, "message": "Revancha: %s" % r.get("message", "")}
    return {"ok": true}

func reload_for_tests() -> bool:
    if not AppPaths.test_mode:
        return false
    _load_or_create_database()
    return true
```

## PASO 5C — Registro de modelos

**Crear:** `autoload/model_registry.gd`

```gdscript
extends Node

signal models_changed
signal model_error(message: String)

const STATUS_ACTIVE := "active"
const STATUS_CANDIDATE := "candidate"
const STATUS_RETIRED := "retired"
const STATUS_REJECTED := "rejected"

var data: Dictionary = {}

func _ready() -> void:
    _load_or_create()

func _models_path() -> String:
    return AppPaths.lotto_file("models.json")

func _create_initial_data() -> Dictionary:
    var engine := CombinationScoreEngine.new(GameProfile.lotto_costa_rica())
    var now := Time.get_datetime_string_from_system()
    return {
        "schema_version": 1,
        "next_model_sequence": 2,
        "active_model_id": "MODEL-000001",
        "models": [{
            "model_id": "MODEL-000001",
            "label": "Modelo inicial",
            "status": STATUS_ACTIVE,
            "model_version": CombinationScoreEngine.MODEL_VERSION,
            "signature": engine.get_model_signature(),
            "weights": engine.get_weights_snapshot(),
            "origin": "initial",
            "created_at": now,
            "promoted_at": now,
            "retired_at": "",
            "parent_model_id": "",
            "promotion_eligible": false,
            "optimizer_snapshot": {}
        }]
    }

func _load_or_create() -> void:
    var path := _models_path()
    if not JsonFileStore.has_any_copy(path):
        var r := JsonFileStore.write_dictionary(path, _create_initial_data())
        if not r.get("ok", false):
            model_error.emit(str(r.get("message", "No se pudo crear models.json")))
            return
        data = r["data"].duplicate(true)
        models_changed.emit()
        return
    var r := JsonFileStore.recover_dictionary(path)
    if not r.get("ok", false):
        model_error.emit(str(r.get("message", "No se pudo recuperar models.json")))
        return
    data = r["data"].duplicate(true)
    _validate_active()

func get_all_models() -> Array:
    return data.get("models", []).duplicate(true)

func get_model_by_id(model_id: String) -> Dictionary:
    for model in data.get("models", []):
        if str(model.get("model_id", "")) == model_id:
            return model.duplicate(true)
    return {}

func get_active_model() -> Dictionary:
    return get_model_by_id(str(data.get("active_model_id", "")))

func register_candidate(label: String, weights: Dictionary, optimizer_snapshot: Dictionary = {}, promotion_eligible: bool = false) -> Dictionary:
    var engine := CombinationScoreEngine.new(GameProfile.lotto_costa_rica())
    var validation := engine.validate_weight_profile(weights)
    if not validation.get("ok", false): return validation
    engine.set_weights(weights)
    var working := data.duplicate(true)
    var sequence := int(working.get("next_model_sequence", 2))
    var model := {
        "model_id": "MODEL-%06d" % sequence,
        "label": label.strip_edges() if not label.strip_edges().is_empty() else "Modelo candidato",
        "status": STATUS_CANDIDATE,
        "model_version": CombinationScoreEngine.MODEL_VERSION,
        "signature": engine.get_model_signature(),
        "weights": weights.duplicate(true),
        "origin": "optimizer",
        "created_at": Time.get_datetime_string_from_system(),
        "promoted_at": "",
        "retired_at": "",
        "parent_model_id": str(working.get("active_model_id", "")),
        "promotion_eligible": promotion_eligible,
        "optimizer_snapshot": optimizer_snapshot.duplicate(true)
    }
    working["models"].append(model)
    working["next_model_sequence"] = sequence + 1
    var commit := _commit(working)
    if not commit.get("ok", false): return commit
    return {"ok": true, "model": model.duplicate(true)}

func promote_candidate(model_id: String) -> Dictionary:
    var working := data.duplicate(true)
    var found := false
    var now := Time.get_datetime_string_from_system()
    for i in range(working["models"].size()):
        var model: Dictionary = working["models"][i]
        if str(model.get("model_id", "")) == model_id:
            if str(model.get("status", "")) != STATUS_CANDIDATE:
                return {"ok": false, "message": "Solo se puede promover un candidato."}
            found = true
    if not found: return {"ok": false, "message": "Modelo inexistente."}
    for i in range(working["models"].size()):
        var model: Dictionary = working["models"][i]
        if str(model.get("status", "")) == STATUS_ACTIVE:
            model["status"] = STATUS_RETIRED
            model["retired_at"] = now
            working["models"][i] = model
        elif str(model.get("model_id", "")) == model_id:
            model["status"] = STATUS_ACTIVE
            model["promoted_at"] = now
            working["models"][i] = model
    working["active_model_id"] = model_id
    return _commit(working)

func reject_candidate(model_id: String) -> Dictionary:
    var working := data.duplicate(true)
    for i in range(working["models"].size()):
        var model: Dictionary = working["models"][i]
        if str(model.get("model_id", "")) == model_id and str(model.get("status", "")) == STATUS_CANDIDATE:
            model["status"] = STATUS_REJECTED
            working["models"][i] = model
            return _commit(working)
    return {"ok": false, "message": "Candidato inexistente."}

func _commit(working: Dictionary) -> Dictionary:
    var r := JsonFileStore.write_dictionary(_models_path(), working)
    if not r.get("ok", false):
        model_error.emit(str(r.get("message", "Error guardando modelos")))
        return r
    data = r["data"].duplicate(true)
    models_changed.emit()
    return {"ok": true}

func _validate_active() -> void:
    var count := 0
    for model in data.get("models", []):
        if str(model.get("status", "")) == STATUS_ACTIVE: count += 1
    if count != 1 or get_active_model().is_empty():
        model_error.emit("models.json debe contener exactamente un modelo activo válido.")

func reload_for_tests() -> bool:
    if not AppPaths.test_mode: return false
    _load_or_create()
    return true
```

## PASO 5D — Predicciones congeladas

**Crear:** `autoload/prediction_store.gd`

```gdscript
extends Node

signal predictions_changed
signal prediction_saved(prediction: Dictionary)
signal prediction_error(message: String)

const MODE_REAL := "real"
const MODE_PRETRAINING := "pretraining"

var data: Dictionary = {}

func _ready() -> void:
    _load_or_create()

func _path() -> String:
    return AppPaths.lotto_file("predictions.json")

func _empty() -> Dictionary:
    return {"schema_version": 1, "next_pred_sequence": 1, "next_test_sequence": 1, "predictions": []}

func _load_or_create() -> void:
    if not JsonFileStore.has_any_copy(_path()):
        var r := JsonFileStore.write_dictionary(_path(), _empty())
        if not r.get("ok", false): prediction_error.emit(str(r.get("message", "No se pudo crear predictions.json"))); return
        data = r["data"].duplicate(true)
        predictions_changed.emit()
        return
    var r := JsonFileStore.recover_dictionary(_path())
    if not r.get("ok", false): prediction_error.emit(str(r.get("message", "No se pudo recuperar predictions.json"))); return
    data = r["data"].duplicate(true)
    call_deferred("refresh_training_integrity")

func get_all_predictions() -> Array:
    return data.get("predictions", []).duplicate(true)

func get_prediction_by_id(prediction_id: String) -> Dictionary:
    for p in data.get("predictions", []):
        if str(p.get("prediction_id", "")) == prediction_id: return p.duplicate(true)
    return {}

func save_generation(mode: String, generation: Dictionary, target_date: String, target_draw_number: String, target_type: String) -> Dictionary:
    if mode not in [MODE_REAL, MODE_PRETRAINING]: return {"ok": false, "message": "Modo inválido."}
    if not generation.get("ok", false): return {"ok": false, "message": "La generación no es válida."}
    var date := DateUtils.normalize_date(target_date)
    var draw_number := target_draw_number.strip_edges()
    if date.is_empty() or draw_number.is_empty() or target_type not in ["lotto", "revancha"]:
        return {"ok": false, "message": "Objetivo inválido."}
    if int(generation.get("database_version", -1)) != Database.get_database_version():
        return {"ok": false, "message": "La base cambió. Genere nuevamente."}
    if Database.has_result_for_target(date, draw_number, "lotto_cr", target_type):
        return {"ok": false, "message": "El resultado objetivo ya está cargado."}
    if _has_future_training_data(date, draw_number):
        return {"ok": false, "message": "Hay resultados posteriores al objetivo. Prueba histórica bloqueada por fuga temporal."}
    if mode == MODE_REAL and _real_exists(date, draw_number, target_type):
        return {"ok": false, "message": "Ya existe una predicción real para este objetivo."}
    var snapshot := _build_training_snapshot(int(generation.get("analysis_source", StatisticsEngine.AnalysisSource.LOTTO_ONLY)))
    var working := data.duplicate(true)
    var id := ""
    if mode == MODE_REAL:
        var seq := int(working.get("next_pred_sequence", 1)); id = "PRED-%06d" % seq; working["next_pred_sequence"] = seq + 1
    else:
        var seq := int(working.get("next_test_sequence", 1)); id = "TEST-%06d" % seq; working["next_test_sequence"] = seq + 1
    var prediction := {
        "prediction_id": id,
        "mode": mode,
        "target": {"date": date, "draw_number": draw_number, "type": target_type, "profile_id": "lotto_cr"},
        "created_at": Time.get_datetime_string_from_system(),
        "database_version_used": Database.get_database_version(),
        "analysis_source": int(generation.get("analysis_source", 0)),
        "model_id": generation.get("model_id", ""),
        "model_label": generation.get("model_label", ""),
        "model_version": generation.get("model_version", ""),
        "model_signature": generation.get("model_signature", ""),
        "model_weights": generation.get("model_weights", {}).duplicate(true),
        "generation_seed": int(generation.get("generation_seed", 0)),
        "candidate_count": int(generation.get("candidate_count", 0)),
        "pool_statistics": generation.get("pool_statistics", {}).duplicate(true),
        "confidence_method": generation.get("confidence_method", ""),
        "attention_alert": generation.get("attention_alert", {}).duplicate(true),
        "best": generation.get("best", {}).duplicate(true),
        "top_5": generation.get("top_5", []).duplicate(true),
        "top_10": generation.get("top_10", []).duplicate(true),
        "training_snapshot": snapshot,
        "training_integrity": {"state": "clean", "affected_by_correction": false, "checked_at": Time.get_datetime_string_from_system(), "issues": []},
        "affected_by_data_correction": false
    }
    working["predictions"].append(prediction)
    var commit := _commit(working)
    if not commit.get("ok", false): return commit
    prediction_saved.emit(prediction.duplicate(true))
    return {"ok": true, "prediction": prediction.duplicate(true)}

func refresh_training_integrity() -> void:
    if data.is_empty(): return
    var working := data.duplicate(true)
    var changed := false
    for i in range(working.get("predictions", []).size()):
        var p: Dictionary = working["predictions"][i]
        var issues: Array[String] = []
        for item in p.get("training_snapshot", {}).get("records", []):
            var current := Database.get_draw_by_id(str(item.get("record_id", "")))
            if current.is_empty():
                issues.append("Falta %s" % item.get("record_id", "")); continue
            var current_hash := _relevant_hash(current, int(p.get("analysis_source", 0)))
            if current_hash != str(item.get("content_hash", "")):
                issues.append("Cambió %s" % item.get("record_id", ""))
        var affected := not issues.is_empty()
        if bool(p.get("affected_by_data_correction", false)) != affected or p.get("training_integrity", {}).get("issues", []) != issues:
            p["affected_by_data_correction"] = affected
            p["training_integrity"] = {"state": "affected" if affected else "clean", "affected_by_correction": affected, "checked_at": Time.get_datetime_string_from_system(), "issues": issues}
            working["predictions"][i] = p
            changed = true
    if changed: _commit(working)

func _build_training_snapshot(source: int) -> Dictionary:
    var records: Array[Dictionary] = []
    for draw in Database.get_all_draws():
        records.append({"record_id": draw.get("record_id", ""), "revision": int(draw.get("revision", 1)), "date": draw.get("date", ""), "draw_number": draw.get("draw_number", ""), "content_hash": _relevant_hash(draw, source)})
    return {"database_version": Database.get_database_version(), "analysis_source": source, "record_count": records.size(), "records": records, "fingerprint": JSON.stringify(records, "", true, true).sha256_text()}

func _relevant_hash(draw: Dictionary, source: int) -> String:
    var relevant := {"record_id": draw.get("record_id", ""), "date": draw.get("date", ""), "draw_number": draw.get("draw_number", ""), "profile_id": draw.get("profile_id", "lotto_cr")}
    if source == StatisticsEngine.AnalysisSource.LOTTO_ONLY or source == StatisticsEngine.AnalysisSource.BOTH:
        relevant["lotto_enabled"] = draw.get("lotto_enabled", false); relevant["lotto"] = draw.get("lotto", [])
    if source == StatisticsEngine.AnalysisSource.REVANCHA_ONLY or source == StatisticsEngine.AnalysisSource.BOTH:
        relevant["revancha_enabled"] = draw.get("revancha_enabled", false); relevant["revancha"] = draw.get("revancha", [])
    return JSON.stringify(relevant, "", true, true).sha256_text()

func _has_future_training_data(target_date: String, target_draw_number: String) -> bool:
    if not str(target_draw_number).is_valid_int():
        for draw in Database.get_all_draws():
            if str(draw.get("date", "")) >= target_date: return true
        return false
    var target_num := int(target_draw_number)
    for draw in Database.get_all_draws():
        var d := str(draw.get("date", ""))
        var n := str(draw.get("draw_number", ""))
        if d > target_date: return true
        if d == target_date and n.is_valid_int() and int(n) >= target_num: return true
    return false

func _real_exists(date: String, draw_number: String, target_type: String) -> bool:
    for p in data.get("predictions", []):
        var t: Dictionary = p.get("target", {})
        if str(p.get("mode", "")) == MODE_REAL and str(t.get("date", "")) == date and str(t.get("draw_number", "")) == draw_number and str(t.get("type", "")) == target_type:
            return true
    return false

func _commit(working: Dictionary) -> Dictionary:
    var r := JsonFileStore.write_dictionary(_path(), working)
    if not r.get("ok", false): prediction_error.emit(str(r.get("message", "Error guardando predicciones"))); return r
    data = r["data"].duplicate(true)
    predictions_changed.emit()
    return {"ok": true}

func reload_for_tests() -> bool:
    if not AppPaths.test_mode: return false
    _load_or_create(); return true
```

## PASO 5E — Marcas manuales

**Crear:** `autoload/feedback_store.gd`

```gdscript
extends Node

signal feedback_changed
signal feedback_saved(feedback: Dictionary)
signal feedback_error(message: String)

var data: Dictionary = {}

func _ready() -> void:
    _load_or_create()

func _path() -> String:
    return AppPaths.lotto_file("manual_feedback.json")

func _empty() -> Dictionary:
    return {"schema_version": 1, "next_feedback_sequence": 1, "feedback": []}

func _load_or_create() -> void:
    if not JsonFileStore.has_any_copy(_path()):
        var r := JsonFileStore.write_dictionary(_path(), _empty())
        if not r.get("ok", false): feedback_error.emit(str(r.get("message", "No se pudo crear manual_feedback.json"))); return
        data = r["data"].duplicate(true)
        feedback_changed.emit()
        return
    var r := JsonFileStore.recover_dictionary(_path())
    if not r.get("ok", false): feedback_error.emit(str(r.get("message", "No se pudo recuperar manual_feedback.json"))); return
    data = r["data"].duplicate(true)

func get_all_feedback() -> Array:
    return data.get("feedback", []).duplicate(true)

func get_feedback_for_prediction(prediction_id: String) -> Dictionary:
    for f in data.get("feedback", []):
        if str(f.get("prediction_id", "")) == prediction_id: return f.duplicate(true)
    return {}

func can_edit_feedback(prediction_id: String) -> Dictionary:
    var p := PredictionStore.get_prediction_by_id(prediction_id)
    if p.is_empty(): return {"ok": false, "message": "Predicción inexistente."}
    if str(p.get("mode", "")) != PredictionStore.MODE_PRETRAINING:
        return {"ok": false, "message": "El feedback manual solo se permite en preentrenamiento."}
    var t: Dictionary = p.get("target", {})
    if Database.has_result_for_target(str(t.get("date", "")), str(t.get("draw_number", "")), str(t.get("profile_id", "lotto_cr")), str(t.get("type", "lotto"))):
        return {"ok": false, "message": "El resultado oficial ya está cargado. Las marcas están bloqueadas."}
    return {"ok": true}

func save_feedback(prediction_id: String, combinations: Array) -> Dictionary:
    var permission := can_edit_feedback(prediction_id)
    if not permission.get("ok", false): return permission
    var working := data.duplicate(true)
    var existing_index := -1
    for i in range(working["feedback"].size()):
        if str(working["feedback"][i].get("prediction_id", "")) == prediction_id:
            existing_index = i; break
    var now := Time.get_datetime_string_from_system()
    var feedback: Dictionary
    if existing_index >= 0:
        feedback = working["feedback"][existing_index]
        feedback["revision"] = int(feedback.get("revision", 1)) + 1
        feedback["updated_at"] = now
        feedback["combinations"] = combinations.duplicate(true)
        working["feedback"][existing_index] = feedback
    else:
        var seq := int(working.get("next_feedback_sequence", 1))
        feedback = {"feedback_id": "FDBK-%06d" % seq, "prediction_id": prediction_id, "revision": 1, "created_at": now, "updated_at": now, "combinations": combinations.duplicate(true)}
        working["feedback"].append(feedback)
        working["next_feedback_sequence"] = seq + 1
    var r := JsonFileStore.write_dictionary(_path(), working)
    if not r.get("ok", false): return r
    data = r["data"].duplicate(true)
    feedback_saved.emit(feedback.duplicate(true))
    feedback_changed.emit()
    return {"ok": true, "feedback": feedback.duplicate(true)}

func reload_for_tests() -> bool:
    if not AppPaths.test_mode: return false
    _load_or_create(); return true
```

## PASO 5F — Evaluaciones oficiales

**Crear:** `autoload/evaluation_store.gd`

```gdscript
extends Node

signal evaluations_changed
signal evaluation_created(evaluation: Dictionary)
signal evaluation_updated(evaluation: Dictionary)
signal evaluation_error(message: String)

const STATUS_VERIFIED := "verified"

var data: Dictionary = {}

func _ready() -> void:
    _load_or_create()
    Database.draw_added.connect(_on_draw_changed)
    Database.draw_updated.connect(_on_draw_changed)
    call_deferred("reconcile_all")

func _path() -> String:
    return AppPaths.lotto_file("evaluations.json")

func _empty() -> Dictionary:
    return {"schema_version": 1, "next_evaluation_sequence": 1, "evaluations": []}

func _load_or_create() -> void:
    if not JsonFileStore.has_any_copy(_path()):
        var r := JsonFileStore.write_dictionary(_path(), _empty())
        if not r.get("ok", false): evaluation_error.emit(str(r.get("message", "No se pudo crear evaluations.json"))); return
        data = r["data"].duplicate(true)
        evaluations_changed.emit()
        return
    var r := JsonFileStore.recover_dictionary(_path())
    if not r.get("ok", false): evaluation_error.emit(str(r.get("message", "No se pudo recuperar evaluations.json"))); return
    data = r["data"].duplicate(true)

func get_all_evaluations() -> Array:
    return data.get("evaluations", []).duplicate(true)

func get_evaluation_for_prediction(prediction_id: String) -> Dictionary:
    for e in data.get("evaluations", []):
        if str(e.get("prediction_id", "")) == prediction_id: return e.duplicate(true)
    return {}

func reconcile_all() -> void:
    for p in PredictionStore.get_all_predictions():
        var t: Dictionary = p.get("target", {})
        var official := Database.get_target_result(str(t.get("date", "")), str(t.get("draw_number", "")), str(t.get("profile_id", "lotto_cr")), str(t.get("type", "lotto")))
        if not official.is_empty(): _reconcile_prediction(p, official)

func _on_draw_changed(_draw: Dictionary) -> void:
    reconcile_all()
    PredictionStore.refresh_training_integrity()

func _reconcile_prediction(prediction: Dictionary, official: Dictionary) -> void:
    var pid := str(prediction.get("prediction_id", ""))
    var existing := get_evaluation_for_prediction(pid)
    if not existing.is_empty() and int(existing.get("result_revision", 0)) == int(official.get("revision", 0)) and str(existing.get("status", "")) == STATUS_VERIFIED:
        return
    var eval := _build_official_evaluation(prediction, official)
    var working := data.duplicate(true)
    var created := existing.is_empty()
    if created:
        var seq := int(working.get("next_evaluation_sequence", 1))
        eval["evaluation_id"] = "EVAL-%06d" % seq
        eval["revision"] = 1
        working["evaluations"].append(eval)
        working["next_evaluation_sequence"] = seq + 1
    else:
        eval["evaluation_id"] = existing.get("evaluation_id", "")
        eval["revision"] = int(existing.get("revision", 1)) + 1
        for i in range(working["evaluations"].size()):
            if str(working["evaluations"][i].get("prediction_id", "")) == pid:
                working["evaluations"][i] = eval; break
    var r := JsonFileStore.write_dictionary(_path(), working)
    if not r.get("ok", false): evaluation_error.emit(str(r.get("message", "No se pudo guardar evaluación"))); return
    data = r["data"].duplicate(true)
    if created: evaluation_created.emit(eval.duplicate(true))
    else: evaluation_updated.emit(eval.duplicate(true))
    evaluations_changed.emit()

func _build_official_evaluation(prediction: Dictionary, official: Dictionary) -> Dictionary:
    var official_numbers: Array = official.get("numbers", []).duplicate(); official_numbers.sort()
    var best := _evaluate_candidate(prediction.get("best", {}), official_numbers)
    var top5 := _evaluate_list(prediction.get("top_5", []), official_numbers)
    var top10 := _evaluate_list(prediction.get("top_10", []), official_numbers)
    return {
        "prediction_id": prediction.get("prediction_id", ""),
        "status": STATUS_VERIFIED,
        "result_record_id": official.get("record_id", ""),
        "result_revision": int(official.get("revision", 1)),
        "evaluated_at": Time.get_datetime_string_from_system(),
        "database_version_verified": Database.get_database_version(),
        "official_numbers": official_numbers,
        "best": best,
        "top_5": top5,
        "top_10": top10,
        "summary": _summary(best, top5, top10),
        "manual_comparison": _manual_comparison(str(prediction.get("prediction_id", "")), top10)
    }

func _evaluate_candidate(candidate: Dictionary, official_numbers: Array) -> Dictionary:
    var hits: Array[int] = []
    for raw in candidate.get("numbers", []):
        var n := int(raw)
        if n in official_numbers: hits.append(n)
    hits.sort()
    return {"display_rank": int(candidate.get("display_rank", candidate.get("rank", 0))), "numbers": candidate.get("numbers", []).duplicate(), "hits": hits, "hit_count": hits.size(), "exact_match": hits.size() == 5, "score": float(candidate.get("score", 0.0))}

func _evaluate_list(candidates: Array, official_numbers: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for c in candidates: result.append(_evaluate_candidate(c, official_numbers))
    return result

func _best_hit_count(values: Array) -> int:
    var best := 0
    for e in values: best = max(best, int(e.get("hit_count", 0)))
    return best

func _summary(best: Dictionary, top5: Array, top10: Array) -> Dictionary:
    var h5 := _best_hit_count(top5); var h10 := _best_hit_count(top10)
    return {"best_combination_hits": int(best.get("hit_count", 0)), "top_5_best_hits": h5, "top_10_best_hits": h10, "top_5_at_least_2": h5 >= 2, "top_5_at_least_3": h5 >= 3, "top_5_at_least_4": h5 >= 4, "top_5_exact_5": h5 == 5, "top_10_at_least_2": h10 >= 2, "top_10_at_least_3": h10 >= 3, "top_10_at_least_4": h10 >= 4, "top_10_exact_5": h10 == 5}

func _manual_comparison(prediction_id: String, top10: Array) -> Dictionary:
    var feedback := FeedbackStore.get_feedback_for_prediction(prediction_id)
    if feedback.is_empty(): return {"available": false}
    var details: Array[Dictionary] = []
    var all_match := true
    for manual in feedback.get("combinations", []):
        var rank := int(manual.get("display_rank", 0))
        var official: Dictionary = {}
        for e in top10:
            if int(e.get("display_rank", 0)) == rank: official = e; break
        var mh := manual.get("hits", []).duplicate(); mh.sort()
        var oh := official.get("hits", []).duplicate(); oh.sort()
        var matches := mh == oh
        if not matches: all_match = false
        details.append({"display_rank": rank, "manual_hits": mh, "manual_hit_count": mh.size(), "official_hits": oh, "official_hit_count": oh.size(), "matches": matches})
    return {"available": true, "matches": all_match, "details": details}

func reload_for_tests() -> bool:
    if not AppPaths.test_mode: return false
    _load_or_create(); return true
```

## PASO 6A — Vista unificada de predicciones

**Crear:** `core/prediction_query_service.gd`

```gdscript
class_name PredictionQueryService
extends RefCounted

static func get_all() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for prediction in PredictionStore.get_all_predictions():
        var joined := prediction.duplicate(true)
        var pid := str(joined.get("prediction_id", ""))
        var feedback := FeedbackStore.get_feedback_for_prediction(pid)
        var evaluation := EvaluationStore.get_evaluation_for_prediction(pid)
        joined["manual_evaluation"] = feedback
        joined["official_evaluation"] = evaluation
        joined["status"] = "verified" if not evaluation.is_empty() else ("manual_review" if not feedback.is_empty() else "pending")
        result.append(joined)
    return result

static func get_by_id(prediction_id: String) -> Dictionary:
    for p in get_all():
        if str(p.get("prediction_id", "")) == prediction_id:
            return p
    return {}
```

## PASO 6B — Métricas de aprendizaje

**Crear:** `core/learning_metrics_engine.gd`

```gdscript
class_name LearningMetricsEngine
extends RefCounted

static func build(mode_filter: String = "all", target_filter: String = "all", model_signature: String = "") -> Dictionary:
    var verified: Array[Dictionary] = []
    for p in PredictionQueryService.get_all():
        if str(p.get("status", "")) != "verified":
            continue
        if bool(p.get("affected_by_data_correction", false)):
            continue
        if mode_filter != "all" and str(p.get("mode", "")) != mode_filter:
            continue
        var t: Dictionary = p.get("target", {})
        if target_filter != "all" and str(t.get("type", "")) != target_filter:
            continue
        if not model_signature.is_empty() and str(p.get("model_signature", "")) != model_signature:
            continue
        verified.append(p)
    verified.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("created_at", "")) < str(b.get("created_at", "")))
    var seen := {}
    var independent: Array[Dictionary] = []
    var repeats := 0
    for p in verified:
        var t: Dictionary = p.get("target", {})
        var key := "%s|%s|%s|%s" % [t.get("date", ""), t.get("draw_number", ""), t.get("type", ""), p.get("model_signature", "")]
        if seen.has(key):
            repeats += 1
            continue
        seen[key] = true
        independent.append(p)
    var best_sum := 0.0
    var top5_2 := 0
    var top5_3 := 0
    var top5_4 := 0
    var top5_5 := 0
    for p in independent:
        var s: Dictionary = p.get("official_evaluation", {}).get("summary", {})
        best_sum += float(s.get("best_combination_hits", 0))
        var h := int(s.get("top_5_best_hits", 0))
        if h >= 2:
            top5_2 += 1
        if h >= 3:
            top5_3 += 1
        if h >= 4:
            top5_4 += 1
        if h == 5:
            top5_5 += 1
    var count := independent.size()
    return {
        "verified_available": verified.size(),
        "independent_runs": count,
        "repeated_runs_excluded": repeats,
        "average_hits": best_sum / count if count > 0 else 0.0,
        "at_least_2_percent": 100.0 * top5_2 / count if count > 0 else 0.0,
        "at_least_3_percent": 100.0 * top5_3 / count if count > 0 else 0.0,
        "at_least_4_percent": 100.0 * top5_4 / count if count > 0 else 0.0,
        "exact_5_percent": 100.0 * top5_5 / count if count > 0 else 0.0,
        "maturity": _maturity(count)
    }

static func _maturity(count: int) -> String:
    if count == 0:
        return "SIN EVALUACIONES"
    if count < 5:
        return "MUY BAJA"
    if count < 10:
        return "INICIAL"
    if count < 20:
        return "LIMITADA"
    if count < 40:
        return "EN DESARROLLO"
    return "MÁS AMPLIA"
```

## PASO 6C — Calibración de confianza

**Crear:** `core/confidence_calibration_engine.gd`

```gdscript
class_name ConfidenceCalibrationEngine
extends RefCounted

static func build(mode_filter: String = "all", target_filter: String = "all", model_signature: String = "") -> Dictionary:
    var buckets := {"green": [], "yellow": [], "gray": [], "red": []}
    var seen := {}
    var independent_draws := 0
    var values := PredictionQueryService.get_all()
    values.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("created_at", "")) < str(b.get("created_at", "")))
    for p in values:
        if str(p.get("status", "")) != "verified" or bool(p.get("affected_by_data_correction", false)):
            continue
        if mode_filter != "all" and str(p.get("mode", "")) != mode_filter:
            continue
        var t: Dictionary = p.get("target", {})
        if target_filter != "all" and str(t.get("type", "")) != target_filter:
            continue
        if not model_signature.is_empty() and str(p.get("model_signature", "")) != model_signature:
            continue
        var key := "%s|%s|%s|%s" % [t.get("date", ""), t.get("draw_number", ""), t.get("type", ""), p.get("model_signature", "")]
        if seen.has(key):
            continue
        seen[key] = true
        independent_draws += 1
        var best: Dictionary = p.get("best", {})
        var conf: Dictionary = best.get("confidence", {})
        var state := str(conf.get("state", "gray"))
        if not buckets.has(state):
            state = "gray"
        var hits := int(p.get("official_evaluation", {}).get("best", {}).get("hit_count", 0))
        buckets[state].append(hits)
    var result_buckets := {}
    for state in buckets:
        var arr: Array = buckets[state]
        var sum := 0.0
        var at2 := 0
        for h in arr:
            sum += int(h)
            if int(h) >= 2:
                at2 += 1
        result_buckets[state] = {
            "draws": arr.size(),
            "average_hits": sum / arr.size() if not arr.is_empty() else 0.0,
            "at_least_2_percent": 100.0 * at2 / arr.size() if not arr.is_empty() else 0.0
        }
    return {"independent_draws": independent_draws, "maturity": _maturity(independent_draws), "buckets": result_buckets}

static func _maturity(count: int) -> String:
    if count < 10:
        return "INSUFICIENTE"
    if count < 20:
        return "PRELIMINAR"
    if count < 40:
        return "LIMITADA"
    return "MÁS ÚTIL"
```

## PASO 6D — Resumen del inicio

**Crear:** `core/dashboard_summary_engine.gd`

```gdscript
class_name DashboardSummaryEngine
extends RefCounted

static func build() -> Dictionary:
    var draws := Database.get_all_draws()
    var predictions := PredictionQueryService.get_all()
    var pretraining := 0
    var real := 0
    var verified := 0
    var alerts := 0
    var latest_alert: Dictionary = {}
    for p in predictions:
        if str(p.get("mode", "")) == PredictionStore.MODE_PRETRAINING:
            pretraining += 1
        if str(p.get("mode", "")) == PredictionStore.MODE_REAL:
            real += 1
        if str(p.get("status", "")) == "verified" and not bool(p.get("affected_by_data_correction", false)):
            verified += 1
        if p.get("attention_alert", {}).get("triggered", false):
            alerts += 1
            latest_alert = {
                "prediction_id": p.get("prediction_id", ""),
                "relative_index": p.get("attention_alert", {}).get("relative_index", 0.0)
            }
    var real_metrics := LearningMetricsEngine.build(PredictionStore.MODE_REAL)
    var pretraining_metrics := LearningMetricsEngine.build(PredictionStore.MODE_PRETRAINING)
    var primary := real_metrics if int(real_metrics.get("independent_runs", 0)) > 0 else pretraining_metrics
    var calibration := ConfidenceCalibrationEngine.build(PredictionStore.MODE_REAL if int(real_metrics.get("independent_runs", 0)) > 0 else PredictionStore.MODE_PRETRAINING)
    return {
        "draw_count": draws.size(),
        "database_version": Database.get_database_version(),
        "maturity_label": _maturity(draws.size()),
        "pretraining_count": pretraining,
        "real_count": real,
        "verified_count": verified,
        "alert_count": alerts,
        "primary_performance": primary,
        "calibration_status": calibration.get("maturity", "INSUFICIENTE"),
        "latest_attention_alert": latest_alert
    }

static func _maturity(count: int) -> String:
    if count < 5:
        return "INSUFICIENTE"
    if count < 10:
        return "EXPLORATORIO"
    if count < 12:
        return "PRELIMINAR"
    if count < 20:
        return "ENTRENAMIENTO INICIAL"
    if count < 40:
        return "EN DESARROLLO"
    return "VALIDACIÓN MÁS AMPLIA"
```

## PASO 6E — Backtesting cronológico

**Crear:** `core/backtester.gd`

```gdscript
class_name Backtester
extends RefCounted

const WARMUP := 12
const CANDIDATES := 250
const SEED_BASE := 17041

static func run(draws: Array, source: int, target_type: String, weights: Dictionary) -> Dictionary:
    var sorted := draws.duplicate(true)
    sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if str(a.get("date", "")) == str(b.get("date", "")): return str(a.get("draw_number", "")) < str(b.get("draw_number", ""))
        return str(a.get("date", "")) < str(b.get("date", ""))
    )
    if sorted.size() <= WARMUP:
        return {"ok": true, "cases": 0, "average_best_hits": 0.0, "top5_at_least_2": 0.0, "top5_at_least_3": 0.0}
    var hits_sum := 0
    var at2 := 0
    var at3 := 0
    var cases := 0
    for i in range(WARMUP, sorted.size()):
        var target: Dictionary = sorted[i]
        var enabled := bool(target.get("lotto_enabled" if target_type == "lotto" else "revancha_enabled", false))
        if not enabled: continue
        var training := sorted.slice(0, i)
        var engine := CombinationScoreEngine.new(GameProfile.lotto_costa_rica())
        if not engine.set_weights(weights).get("ok", false): return {"ok": false, "message": "Pesos inválidos."}
        var model := {"model_id": "BACKTEST", "label": "Backtest", "model_version": CombinationScoreEngine.MODEL_VERSION, "signature": engine.get_model_signature(), "weights": weights}
        var generator := CombinationGenerator.new(GameProfile.lotto_costa_rica())
        generator.apply_model(model)
        var gen := generator.generate(training, source, CANDIDATES, SEED_BASE + i)
        if not gen.get("ok", false): continue
        var official: Array = target.get("lotto" if target_type == "lotto" else "revancha", [])
        var best_hits := _hits(gen["best"]["numbers"], official)
        var top5_best := 0
        for c in gen["top_5"]: top5_best = max(top5_best, _hits(c["numbers"], official))
        hits_sum += best_hits
        if top5_best >= 2: at2 += 1
        if top5_best >= 3: at3 += 1
        cases += 1
    if cases == 0: return {"ok": true, "cases": 0, "average_best_hits": 0.0, "top5_at_least_2": 0.0, "top5_at_least_3": 0.0}
    return {"ok": true, "cases": cases, "average_best_hits": float(hits_sum) / cases, "top5_at_least_2": 100.0 * at2 / cases, "top5_at_least_3": 100.0 * at3 / cases}

static func _hits(a: Array, b: Array) -> int:
    var count := 0
    for n in a:
        if int(n) in b: count += 1
    return count
```

## PASO 6F — Comparador de pesos

**Crear:** `core/weight_optimizer.gd`

```gdscript
class_name WeightOptimizer
extends RefCounted

const PROFILES := {
    "baseline": {"individual_total":0.20,"individual_recent":0.20,"pairs":0.20,"trios":0.10,"distribution":0.20,"repetition":0.10},
    "recent": {"individual_total":0.15,"individual_recent":0.30,"pairs":0.15,"trios":0.05,"distribution":0.20,"repetition":0.15},
    "individual": {"individual_total":0.30,"individual_recent":0.20,"pairs":0.15,"trios":0.05,"distribution":0.20,"repetition":0.10},
    "distribution": {"individual_total":0.15,"individual_recent":0.20,"pairs":0.15,"trios":0.05,"distribution":0.35,"repetition":0.10},
    "relations_light": {"individual_total":0.25,"individual_recent":0.25,"pairs":0.10,"trios":0.05,"distribution":0.25,"repetition":0.10}
}

static func compare(draws: Array, source: int, target_type: String) -> Dictionary:
    var rows: Array[Dictionary] = []
    for name in PROFILES:
        var result := Backtester.run(draws, source, target_type, PROFILES[name])
        if not result.get("ok", false): continue
        var objective := float(result.get("average_best_hits", 0.0)) * 10.0 + float(result.get("top5_at_least_2", 0.0)) * 0.5 + float(result.get("top5_at_least_3", 0.0))
        rows.append({"name": name, "weights": PROFILES[name].duplicate(true), "result": result, "objective": objective})
    rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["objective"]) > float(b["objective"]))
    return {"ok": true, "rows": rows, "best": {} if rows.is_empty() else rows[0]}
```

## PASO 6G — Revisión interna austera

**Crear:** `core/project_audit.gd`

```gdscript
class_name ProjectAudit
extends RefCounted

static func run() -> Dictionary:
    var errors: Array[String] = []
    var ids := {}
    var identities := {}
    var profile := GameProfile.lotto_costa_rica()
    for draw in Database.get_all_draws():
        var rid := str(draw.get("record_id", ""))
        if rid.is_empty() or ids.has(rid): errors.append("record_id duplicado o vacío: %s" % rid)
        ids[rid] = true
        var key := "%s|%s|%s" % [draw.get("profile_id", ""), draw.get("date", ""), draw.get("draw_number", "")]
        if identities.has(key): errors.append("sorteo duplicado: %s" % key)
        identities[key] = true
        if bool(draw.get("lotto_enabled", false)) and not profile.validate_numbers(draw.get("lotto", [])).get("ok", false): errors.append("Lotto inválido en %s" % rid)
        if bool(draw.get("revancha_enabled", false)) and not profile.validate_numbers(draw.get("revancha", [])).get("ok", false): errors.append("Revancha inválida en %s" % rid)
    var active := 0
    for model in ModelRegistry.get_all_models():
        if str(model.get("status", "")) == ModelRegistry.STATUS_ACTIVE: active += 1
    if active != 1: errors.append("Debe existir exactamente un modelo activo.")
    var pred_ids := {}
    for p in PredictionStore.get_all_predictions():
        var pid := str(p.get("prediction_id", ""))
        if pred_ids.has(pid): errors.append("prediction_id duplicado: %s" % pid)
        pred_ids[pid] = true
        if p.has("official_evaluation") or p.has("manual_evaluation"): errors.append("predictions.json mezcla capas en %s" % pid)
    var eval_counts := {}
    for e in EvaluationStore.get_all_evaluations():
        var pid := str(e.get("prediction_id", "")); eval_counts[pid] = int(eval_counts.get(pid, 0)) + 1
        if not pred_ids.has(pid): errors.append("Evaluación huérfana: %s" % pid)
    for pid in eval_counts:
        if int(eval_counts[pid]) > 1: errors.append("Evaluación redundante: %s" % pid)
    var fb_counts := {}
    for f in FeedbackStore.get_all_feedback():
        var pid := str(f.get("prediction_id", "")); fb_counts[pid] = int(fb_counts.get(pid, 0)) + 1
        if not pred_ids.has(pid): errors.append("Feedback huérfano: %s" % pid)
    for pid in fb_counts:
        if int(fb_counts[pid]) > 1: errors.append("Feedback redundante: %s" % pid)
    return {"ok": errors.is_empty(), "errors": errors}
```

## PASO 7A — Bolas numéricas

**Crear:** `ui/common/number_ball.gd`

```gdscript
class_name NumberBall
extends Button

enum State { NORMAL, SELECTED, HIT, WARNING, ERROR }

var number_value := -1
var state := State.NORMAL

func _init() -> void:
    custom_minimum_size = Vector2(44, 44)
    disabled = true

func set_number(value: int) -> void:
    number_value = value
    text = "%02d" % value

func set_state(value: int) -> void:
    state = value
    match state:
        State.HIT: modulate = Color(0.55, 1.0, 0.55)
        State.WARNING: modulate = Color(1.0, 0.9, 0.45)
        State.ERROR: modulate = Color(1.0, 0.55, 0.55)
        State.SELECTED: modulate = Color(0.65, 0.8, 1.0)
        _: modulate = Color.WHITE
```

## PASO 7B — Botón de alerta

**Crear:** `ui/common/attention_alert_button.gd`

```gdscript
class_name AttentionAlertButton
extends Button

var _tween: Tween

func _init() -> void:
    text = "★ POSIBLE COMBINACIÓN"
    custom_minimum_size = Vector2(220, 48)
    disabled = true
    visible = false

func start_attention(duration: float = 15.0) -> void:
    stop_attention()
    visible = true
    modulate = Color(0.55, 1.0, 0.55, 1.0)
    _tween = create_tween()
    var cycles := max(1, int(duration / 1.5))
    _tween.set_loops(cycles)
    _tween.tween_property(self, "modulate:a", 0.35, 0.75)
    _tween.tween_property(self, "modulate:a", 1.0, 0.75)
    _tween.finished.connect(func(): modulate.a = 1.0)

func stop_attention() -> void:
    if _tween != null and _tween.is_valid():
        _tween.kill()
    _tween = null
    modulate.a = 1.0
```

## PASO 7C — Ayudantes UI

**Crear:** `ui/common/ui_helpers.gd`

```gdscript
class_name UIHelpers
extends RefCounted

static func clear_children(node: Node) -> void:
    for child in node.get_children():
        child.queue_free()

static func title(text: String) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 24)
    return label

static func section(text: String) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 18)
    return label

static func make_button(text: String) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size.y = 44
    return b

static func format_numbers(numbers: Array) -> String:
    var parts := PackedStringArray()
    for n in numbers: parts.append("%02d" % int(n))
    return "  ".join(parts)

static func add_balls(container: Container, numbers: Array, hits: Array = []) -> void:
    clear_children(container)
    for n in numbers:
        var b := NumberBall.new()
        b.set_number(int(n))
        if int(n) in hits: b.set_state(NumberBall.State.HIT)
        container.add_child(b)
```

## PASO 8A — Inicio / Dashboard

**Crear:** `ui/panels/home_dashboard_panel.gd`

```gdscript
class_name HomeDashboardPanel
extends Control

var output: RichTextLabel

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
    root.add_child(UIHelpers.title("INICIO"))
    output = RichTextLabel.new(); output.bbcode_enabled = true; output.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(output)
    Database.database_changed.connect(func(_v: int): refresh())
    PredictionStore.predictions_changed.connect(refresh)
    FeedbackStore.feedback_changed.connect(refresh)
    EvaluationStore.evaluations_changed.connect(refresh)
    ModelRegistry.models_changed.connect(refresh)
    refresh()

func refresh() -> void:
    var s := DashboardSummaryEngine.build(); var model := ModelRegistry.get_active_model(); var p: Dictionary = s.get("primary_performance", {})
    var lines := PackedStringArray()
    lines.append("[b]ACIERTA v0.0.0.1 · Lotto / Lotto Revancha[/b]")
    lines.append("\nResultados oficiales: %d" % int(s.get("draw_count", 0)))
    lines.append("Versión lógica de base: %d" % int(s.get("database_version", 0)))
    lines.append("Madurez: %s" % s.get("maturity_label", ""))
    lines.append("Modelo activo: %s · %s" % [model.get("model_id", "—"), model.get("label", "")])
    lines.append("\nPruebas: %d · Predicciones reales: %d · Verificadas limpias: %d" % [int(s.get("pretraining_count", 0)), int(s.get("real_count", 0)), int(s.get("verified_count", 0))])
    if p.is_empty(): lines.append("Rendimiento: todavía sin evaluaciones suficientes.")
    else: lines.append("Rendimiento: promedio mejor %.2f aciertos · Top5 ≥2 %.1f%% · Top5 ≥3 %.1f%%" % [float(p.get("average_hits", 0.0)), float(p.get("at_least_2_percent", 0.0)), float(p.get("at_least_3_percent", 0.0))])
    lines.append("Calibración: %s" % s.get("calibration_status", "Insuficiente"))
    var alert: Dictionary = s.get("latest_attention_alert", {})
    if not alert.is_empty(): lines.append("\n[b]★ ALERTA 90+ histórica[/b] %s · índice %.1f/100" % [alert.get("prediction_id", ""), float(alert.get("relative_index", 0.0))])
    lines.append("\n[color=gray]El score y el índice relativo comparan candidatos del modelo; no son probabilidades de ganar.[/color]")
    output.text = "\n".join(lines)
```

## PASO 8B — Ingresar resultado

**Crear:** `ui/panels/input_result_panel.gd`

```gdscript
class_name InputResultPanel
extends Control

var date_edit: LineEdit
var draw_edit: LineEdit
var lotto_check: CheckButton
var revancha_check: CheckButton
var lotto_fields: Array[LineEdit] = []
var revancha_fields: Array[LineEdit] = []
var status_label: Label
var bulk_text: TextEdit

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_theme_constant_override("separation", 10); add_child(root)
    root.add_child(UIHelpers.title("INGRESAR RESULTADO"))
    var tabs := TabContainer.new(); tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(tabs)
    _build_manual(tabs)
    _build_bulk(tabs)
    status_label = Label.new(); status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; root.add_child(status_label)

func _build_manual(tabs: TabContainer) -> void:
    var manual := VBoxContainer.new(); manual.name = "Manual"; manual.add_theme_constant_override("separation", 8); tabs.add_child(manual)
    var date_row := HBoxContainer.new(); manual.add_child(date_row)
    date_row.add_child(Label.new()); date_row.get_child(0).text = "Fecha (AAAA-MM-DD o DD/MM/AAAA):"
    date_edit = LineEdit.new(); date_edit.text = DateUtils.today(); date_edit.custom_minimum_size.x = 180; date_row.add_child(date_edit)
    date_row.add_child(Label.new()); date_row.get_child(2).text = "Sorteo:"
    draw_edit = LineEdit.new(); draw_edit.custom_minimum_size.x = 140; date_row.add_child(draw_edit)

    lotto_check = CheckButton.new(); lotto_check.text = "LOTTO"; lotto_check.button_pressed = true; manual.add_child(lotto_check)
    var lotto_row := HBoxContainer.new(); manual.add_child(lotto_row)
    for i in range(5):
        var e := _number_field(); lotto_fields.append(e); lotto_row.add_child(e)

    revancha_check = CheckButton.new(); revancha_check.text = "LOTTO REVANCHA"; revancha_check.button_pressed = true; manual.add_child(revancha_check)
    var rev_row := HBoxContainer.new(); manual.add_child(rev_row)
    for i in range(5):
        var e := _number_field(); revancha_fields.append(e); rev_row.add_child(e)

    var actions := HBoxContainer.new(); manual.add_child(actions)
    var save := UIHelpers.make_button("GUARDAR"); save.pressed.connect(_save_manual); actions.add_child(save)
    var clear := UIHelpers.make_button("LIMPIAR"); clear.pressed.connect(_clear_manual); actions.add_child(clear)

func _build_bulk(tabs: TabContainer) -> void:
    var bulk := VBoxContainer.new(); bulk.name = "Importar lote"; tabs.add_child(bulk)
    var help := Label.new(); help.text = "Una línea por sorteo:\nAAAA-MM-DD|SORTEO|01 02 03 04 05|06 07 08 09 10\nLa Revancha puede dejarse vacía."; help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; bulk.add_child(help)
    bulk_text = TextEdit.new(); bulk_text.size_flags_vertical = Control.SIZE_EXPAND_FILL; bulk.add_child(bulk_text)
    var import_button := UIHelpers.make_button("IMPORTAR TODO"); import_button.pressed.connect(_import_bulk); bulk.add_child(import_button)

func _number_field() -> LineEdit:
    var e := LineEdit.new(); e.custom_minimum_size = Vector2(64, 44); e.max_length = 2; e.placeholder_text = "00"; return e

func _collect(fields: Array[LineEdit]) -> Array[int]:
    var values: Array[int] = []
    for e in fields:
        if e.text.strip_edges().is_empty(): continue
        if not e.text.strip_edges().is_valid_int(): return []
        values.append(int(e.text))
    return values

func _save_manual() -> void:
    var record := {
        "date": date_edit.text,
        "draw_number": draw_edit.text,
        "profile_id": "lotto_cr",
        "lotto_enabled": lotto_check.button_pressed,
        "lotto": _collect(lotto_fields),
        "revancha_enabled": revancha_check.button_pressed,
        "revancha": _collect(revancha_fields)
    }
    var r := Database.add_draw(record)
    status_label.text = "Guardado: %s" % r.get("draw", {}).get("record_id", "") if r.get("ok", false) else "ERROR: %s" % r.get("message", "No se pudo guardar")
    if r.get("ok", false): _clear_numbers_only()

func _clear_manual() -> void:
    draw_edit.clear(); _clear_numbers_only(); status_label.text = ""

func _clear_numbers_only() -> void:
    for e in lotto_fields: e.clear()
    for e in revancha_fields: e.clear()

func _import_bulk() -> void:
    var batch: Array[Dictionary] = []
    var line_number := 0
    for raw_line in bulk_text.text.split("\n"):
        line_number += 1
        var line := raw_line.strip_edges()
        if line.is_empty(): continue
        var parts := line.split("|")
        if parts.size() < 3 or parts.size() > 4:
            status_label.text = "ERROR línea %d: formato inválido." % line_number; return
        var lotto := _parse_number_text(str(parts[2]))
        var revancha := _parse_number_text(str(parts[3])) if parts.size() == 4 and not str(parts[3]).strip_edges().is_empty() else []
        batch.append({"date": str(parts[0]), "draw_number": str(parts[1]).strip_edges(), "profile_id": "lotto_cr", "lotto_enabled": true, "lotto": lotto, "revancha_enabled": not revancha.is_empty(), "revancha": revancha})
    var r := Database.add_draws_batch(batch)
    status_label.text = "Importados %d sorteos." % int(r.get("count", 0)) if r.get("ok", false) else "ERROR: %s" % r.get("message", "No se pudo importar")
    if r.get("ok", false): bulk_text.clear()

func _parse_number_text(text: String) -> Array[int]:
    var clean := text.replace(",", " ").replace(";", " ")
    var result: Array[int] = []
    for part in clean.split(" ", false):
        if part.strip_edges().is_valid_int(): result.append(int(part))
    return result
```

## PASO 8C — Generar

**Crear:** `ui/panels/generator_panel.gd`

```gdscript
class_name GeneratorPanel
extends Control

var profile := GameProfile.lotto_costa_rica()
var generator: CombinationGenerator
var last_generation: Dictionary = {}
var saved_prediction_id := ""

var mode_option: OptionButton
var source_option: OptionButton
var target_option: OptionButton
var target_date: LineEdit
var target_draw: LineEdit
var candidate_spin: SpinBox
var generate_button: Button
var save_button: Button
var feedback_button: Button
var status_label: Label
var best_label: RichTextLabel
var top_label: RichTextLabel
var alert_button: AttentionAlertButton
var feedback_dialog: ConfirmationDialog
var feedback_content: VBoxContainer
var feedback_fields: Dictionary = {}

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    generator = CombinationGenerator.new(profile)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_theme_constant_override("separation", 8); add_child(root)
    root.add_child(UIHelpers.title("GENERAR"))
    var controls := GridContainer.new(); controls.columns = 4; root.add_child(controls)
    controls.add_child(_label("Modo")); mode_option = OptionButton.new(); mode_option.add_item("PREDICCIÓN REAL"); mode_option.set_item_metadata(0, PredictionStore.MODE_REAL); mode_option.add_item("PRUEBA / PREENTRENAMIENTO"); mode_option.set_item_metadata(1, PredictionStore.MODE_PRETRAINING); mode_option.select(1); controls.add_child(mode_option)
    controls.add_child(_label("Fuente")); source_option = OptionButton.new(); source_option.add_item("LOTTO"); source_option.set_item_metadata(0, StatisticsEngine.AnalysisSource.LOTTO_ONLY); source_option.add_item("REVANCHA"); source_option.set_item_metadata(1, StatisticsEngine.AnalysisSource.REVANCHA_ONLY); source_option.add_item("AMBOS"); source_option.set_item_metadata(2, StatisticsEngine.AnalysisSource.BOTH); controls.add_child(source_option)
    controls.add_child(_label("Objetivo")); target_option = OptionButton.new(); target_option.add_item("LOTTO"); target_option.set_item_metadata(0, "lotto"); target_option.add_item("REVANCHA"); target_option.set_item_metadata(1, "revancha"); controls.add_child(target_option)
    controls.add_child(_label("Fecha objetivo")); target_date = LineEdit.new(); target_date.text = DateUtils.today(); controls.add_child(target_date)
    controls.add_child(_label("Sorteo objetivo")); target_draw = LineEdit.new(); controls.add_child(target_draw)
    controls.add_child(_label("Candidatos")); candidate_spin = SpinBox.new(); candidate_spin.min_value = 50; candidate_spin.max_value = 2500; candidate_spin.step = 50; candidate_spin.value = 1000; controls.add_child(candidate_spin)

    var actions := HBoxContainer.new(); root.add_child(actions)
    generate_button = UIHelpers.make_button("GENERAR"); generate_button.pressed.connect(_generate); actions.add_child(generate_button)
    save_button = UIHelpers.make_button("GUARDAR TEST/PRED"); save_button.disabled = true; save_button.pressed.connect(_save); actions.add_child(save_button)
    feedback_button = UIHelpers.make_button("MARCAR ACIERTOS"); feedback_button.disabled = true; feedback_button.pressed.connect(_open_feedback); actions.add_child(feedback_button)
    alert_button = AttentionAlertButton.new(); actions.add_child(alert_button)
    status_label = Label.new(); status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; root.add_child(status_label)
    best_label = RichTextLabel.new(); best_label.bbcode_enabled = true; best_label.custom_minimum_size.y = 120; root.add_child(best_label)
    top_label = RichTextLabel.new(); top_label.bbcode_enabled = true; top_label.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(top_label)
    _build_feedback_dialog()
    Database.database_changed.connect(_on_database_changed)
    ModelRegistry.models_changed.connect(_on_model_changed)
    EvaluationStore.evaluations_changed.connect(_on_evaluations_changed)

func _label(text: String) -> Label:
    var l := Label.new(); l.text = text + ":"; return l

func _generate() -> void:
    if Database.get_all_draws().size() < 12:
        status_label.text = "Se requieren al menos 12 resultados históricos."; return
    if DateUtils.normalize_date(target_date.text).is_empty() or target_draw.text.strip_edges().is_empty():
        status_label.text = "Complete fecha y sorteo objetivo."; return
    var model := ModelRegistry.get_active_model()
    var applied := generator.apply_model(model)
    if not applied.get("ok", false): status_label.text = str(applied.get("message", "No se pudo aplicar modelo")); return
    status_label.text = "Generando..."
    var result := generator.generate(Database.get_all_draws(), int(source_option.get_item_metadata(source_option.selected)), int(candidate_spin.value))
    if not result.get("ok", false): last_generation = {}; status_label.text = str(result.get("message", "No se pudo generar")); return
    last_generation = result.duplicate(true); saved_prediction_id = ""; save_button.disabled = false; feedback_button.disabled = true; _show_generation(); status_label.text = "Generación lista. Revise y guarde si corresponde."

func _show_generation() -> void:
    var best: Dictionary = last_generation.get("best", {}); var conf: Dictionary = best.get("confidence", {})
    best_label.text = "[b]MEJOR PUNTUADA[/b]\n%s\nScore %.2f / 100 · Índice relativo %.1f / 100 · Percentil %.1f · Estado %s" % [UIHelpers.format_numbers(best.get("numbers", [])), float(best.get("score", 0.0)), float(conf.get("relative_index", 0.0)), float(conf.get("percentile", 0.0)), str(conf.get("state", "gray")).to_upper()]
    var lines := PackedStringArray(["[b]TOP 10[/b]"])
    for c in last_generation.get("top_10", []):
        var cc: Dictionary = c.get("confidence", {})
        lines.append("#%d  %s   score %.2f   %s %.1f" % [int(c.get("display_rank", 0)), UIHelpers.format_numbers(c.get("numbers", [])), float(c.get("score", 0.0)), str(cc.get("state", "gray")).to_upper(), float(cc.get("relative_index", 0.0))])
    top_label.text = "\n".join(lines)
    if last_generation.get("attention_alert", {}).get("triggered", false): alert_button.start_attention(15.0)
    else: alert_button.stop_attention(); alert_button.visible = false

func _save() -> void:
    if last_generation.is_empty(): return
    var mode := str(mode_option.get_item_metadata(mode_option.selected)); var target_type := str(target_option.get_item_metadata(target_option.selected))
    var r := PredictionStore.save_generation(mode, last_generation, target_date.text, target_draw.text, target_type)
    if not r.get("ok", false): status_label.text = "ERROR: %s" % r.get("message", "No se pudo guardar"); return
    saved_prediction_id = str(r.get("prediction", {}).get("prediction_id", "")); save_button.disabled = true; feedback_button.disabled = mode != PredictionStore.MODE_PRETRAINING; status_label.text = "%s guardada correctamente." % saved_prediction_id

func _build_feedback_dialog() -> void:
    feedback_dialog = ConfirmationDialog.new()
    feedback_dialog.title = "Marcas provisionales"
    feedback_dialog.confirmed.connect(_save_feedback)
    add_child(feedback_dialog)

    feedback_content = VBoxContainer.new()
    feedback_content.custom_minimum_size = Vector2(680, 430)
    feedback_dialog.add_child(feedback_content)

func _open_feedback() -> void:
    if saved_prediction_id.is_empty(): return
    var permission := FeedbackStore.can_edit_feedback(saved_prediction_id)
    if not permission.get("ok", false): status_label.text = str(permission.get("message", "Feedback bloqueado")); feedback_button.disabled = true; return
    UIHelpers.clear_children(feedback_content)
    feedback_fields.clear()
    var info := Label.new(); info.text = "Escriba SOLO los números que usted considera acertados. Ejemplo: 11 17"; feedback_content.add_child(info)
    var p := PredictionStore.get_prediction_by_id(saved_prediction_id)
    var existing := FeedbackStore.get_feedback_for_prediction(saved_prediction_id)
    var existing_by_rank := {}
    for entry in existing.get("combinations", []): existing_by_rank[int(entry.get("display_rank", 0))] = entry.get("hits", [])
    for c in p.get("top_10", []):
        var rank := int(c.get("display_rank", 0)); var row := HBoxContainer.new(); feedback_content.add_child(row)
        var l := Label.new(); l.text = "#%d  %s  →" % [rank, UIHelpers.format_numbers(c.get("numbers", []))]; l.custom_minimum_size.x = 360; row.add_child(l)
        var e := LineEdit.new(); e.placeholder_text = "aciertos"; if existing_by_rank.has(rank): e.text = " ".join(_to_strings(existing_by_rank[rank])); row.add_child(e); feedback_fields[rank] = {"field": e, "allowed": c.get("numbers", []).duplicate()}
    feedback_dialog.popup_centered(Vector2i(720, 520))

func _save_feedback() -> void:
    var combinations: Array[Dictionary] = []
    for rank in feedback_fields:
        var info: Dictionary = feedback_fields[rank]; var hits := _parse_numbers(info["field"].text)
        for n in hits:
            if n not in info["allowed"]: status_label.text = "ERROR: el número %02d no pertenece a la combinación #%d." % [n, int(rank)]; return
        combinations.append({"display_rank": int(rank), "hits": hits, "hit_count": hits.size()})
    var r := FeedbackStore.save_feedback(saved_prediction_id, combinations)
    status_label.text = "Marcas provisionales guardadas." if r.get("ok", false) else "ERROR: %s" % r.get("message", "No se pudo guardar feedback")

func _parse_numbers(text: String) -> Array[int]:
    var result: Array[int] = []
    for part in text.replace(",", " ").split(" ", false):
        if part.strip_edges().is_valid_int():
            var n := int(part)
            if n not in result: result.append(n)
    result.sort(); return result

func _to_strings(values: Array) -> PackedStringArray:
    var result := PackedStringArray(); for v in values: result.append("%02d" % int(v)); return result

func _on_database_changed(_version: int) -> void:
    if not last_generation.is_empty(): last_generation = {}; saved_prediction_id = ""; save_button.disabled = true; feedback_button.disabled = true; status_label.text = "La base cambió. Genere nuevamente."

func _on_model_changed() -> void:
    if not last_generation.is_empty(): last_generation = {}; saved_prediction_id = ""; save_button.disabled = true; feedback_button.disabled = true; status_label.text = "El modelo cambió. Genere nuevamente."

func _on_evaluations_changed() -> void:
    if saved_prediction_id.is_empty(): return
    var e := EvaluationStore.get_evaluation_for_prediction(saved_prediction_id)
    if e.is_empty(): return
    feedback_button.disabled = true
    var s: Dictionary = e.get("summary", {})
    status_label.text = "Resultado verificado · Top5 %d/5 · Top10 %d/5" % [int(s.get("top_5_best_hits", 0)), int(s.get("top_10_best_hits", 0))]
```

## PASO 8D — Estadísticas

**Crear:** `ui/panels/statistics_panel.gd`

```gdscript
class_name StatisticsPanel
extends Control

var source: OptionButton
var output: RichTextLabel

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
    root.add_child(UIHelpers.title("ESTADÍSTICAS"))
    var row := HBoxContainer.new(); root.add_child(row)
    source = OptionButton.new(); source.add_item("LOTTO"); source.set_item_metadata(0, StatisticsEngine.AnalysisSource.LOTTO_ONLY); source.add_item("REVANCHA"); source.set_item_metadata(1, StatisticsEngine.AnalysisSource.REVANCHA_ONLY); source.add_item("AMBOS"); source.set_item_metadata(2, StatisticsEngine.AnalysisSource.BOTH); row.add_child(source)
    var refresh := UIHelpers.make_button("CALCULAR"); refresh.pressed.connect(_refresh); row.add_child(refresh)
    output = RichTextLabel.new(); output.bbcode_enabled = true; output.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(output)
    Database.database_changed.connect(func(_v: int): _refresh())
    _refresh()

func _refresh() -> void:
    var s := StatisticsEngine.analyze(Database.get_all_draws(), int(source.get_item_metadata(source.selected)), GameProfile.lotto_costa_rica())
    var lines := PackedStringArray()
    lines.append("[b]Muestras:[/b] %d" % int(s.get("sample_count", 0)))
    lines.append("\n[b]Frecuencia por número[/b]")
    for n in range(0, 41): lines.append("%02d: %d" % [n, int(s.get("frequency", {}).get(n, 0))])
    lines.append("\n[b]Forma promedio[/b]")
    var shape: Dictionary = s.get("shape", {})
    lines.append("Suma %.2f | Rango %.2f | Pares %.2f | Bajos 00-20 %.2f | Consecutivos %.2f" % [shape.get("avg_sum",0.0), shape.get("avg_span",0.0), shape.get("avg_even",0.0), shape.get("avg_low",0.0), shape.get("avg_consecutive",0.0)])
    var overlap := StatisticsEngine.same_draw_overlap(Database.get_all_draws())
    lines.append("\n[b]Solapamiento Lotto/Revancha mismo sorteo:[/b] %s" % str(overlap.get("overlap_counts", {})))
    output.text = "\n".join(lines)
```

## PASO 8E — Historial

**Crear:** `ui/panels/history_panel.gd`

```gdscript
class_name HistoryPanel
extends Control

var result_list: ItemList
var result_detail: RichTextLabel
var prediction_list: ItemList
var prediction_detail: RichTextLabel
var _result_ids: Array[String] = []
var _prediction_ids: Array[String] = []
var _edit_dialog: ConfirmationDialog
var _edit_date: LineEdit
var _edit_draw: LineEdit
var _edit_lotto: LineEdit
var _edit_revancha: LineEdit
var _editing_id := ""

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
    root.add_child(UIHelpers.title("HISTORIAL"))
    var tabs := TabContainer.new(); tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(tabs)
    _build_results_tab(tabs)
    _build_predictions_tab(tabs)
    _build_edit_dialog()
    Database.draw_added.connect(func(_d: Dictionary): refresh_results())
    Database.draw_updated.connect(func(_d: Dictionary): refresh_results())
    PredictionStore.predictions_changed.connect(refresh_predictions)
    FeedbackStore.feedback_changed.connect(refresh_predictions)
    EvaluationStore.evaluations_changed.connect(refresh_predictions)
    refresh_results(); refresh_predictions()

func _build_results_tab(tabs: TabContainer) -> void:
    var page := VBoxContainer.new(); page.name = "Resultados oficiales"; tabs.add_child(page)
    var split := HSplitContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL; page.add_child(split)
    result_list = ItemList.new(); result_list.custom_minimum_size.x = 360; result_list.item_selected.connect(_show_result); split.add_child(result_list)
    result_detail = RichTextLabel.new(); result_detail.bbcode_enabled = true; split.add_child(result_detail)
    var edit := UIHelpers.make_button("EDITAR RESULTADO SELECCIONADO"); edit.pressed.connect(_open_edit); page.add_child(edit)

func _build_predictions_tab(tabs: TabContainer) -> void:
    var page := VBoxContainer.new(); page.name = "Predicciones y pruebas"; tabs.add_child(page)
    var split := HSplitContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL; page.add_child(split)
    prediction_list = ItemList.new(); prediction_list.custom_minimum_size.x = 420; prediction_list.item_selected.connect(_show_prediction); split.add_child(prediction_list)
    prediction_detail = RichTextLabel.new(); prediction_detail.bbcode_enabled = true; split.add_child(prediction_detail)

func _build_edit_dialog() -> void:
    _edit_dialog = ConfirmationDialog.new(); _edit_dialog.title = "Corregir resultado"; _edit_dialog.confirmed.connect(_save_edit); add_child(_edit_dialog)
    var box := VBoxContainer.new(); _edit_dialog.add_child(box)
    _edit_date = LineEdit.new(); _edit_date.placeholder_text = "Fecha"; box.add_child(_labeled("Fecha", _edit_date))
    _edit_draw = LineEdit.new(); _edit_draw.placeholder_text = "Sorteo"; box.add_child(_labeled("Sorteo", _edit_draw))
    _edit_lotto = LineEdit.new(); _edit_lotto.placeholder_text = "03 11 17 28 35"; box.add_child(_labeled("Lotto", _edit_lotto))
    _edit_revancha = LineEdit.new(); _edit_revancha.placeholder_text = "05 11 19 28 40 o vacío"; box.add_child(_labeled("Revancha", _edit_revancha))

func _labeled(label_text: String, field: Control) -> HBoxContainer:
    var row := HBoxContainer.new(); var l := Label.new(); l.text = label_text + ":"; l.custom_minimum_size.x = 100; row.add_child(l); field.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(field); return row

func refresh_results() -> void:
    _result_ids.clear(); result_list.clear()
    var draws := Database.get_all_draws()
    draws.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("date", "")) > str(b.get("date", "")))
    for d in draws:
        _result_ids.append(str(d.get("record_id", "")))
        result_list.add_item("%s · #%s · rev.%d" % [DateUtils.display(str(d.get("date", ""))), d.get("draw_number", ""), int(d.get("revision", 1))])
    if not draws.is_empty(): result_list.select(0); _show_result(0)
    else: result_detail.text = "Sin resultados."

func _show_result(index: int) -> void:
    if index < 0 or index >= _result_ids.size(): return
    var d := Database.get_draw_by_id(_result_ids[index])
    result_detail.text = "[b]%s · Sorteo %s[/b]\nID %s · revisión %d\n\nLOTTO\n%s\n\nREVANCHA\n%s" % [DateUtils.display(str(d.get("date",""))), d.get("draw_number",""), d.get("record_id",""), int(d.get("revision",1)), UIHelpers.format_numbers(d.get("lotto",[])) if d.get("lotto_enabled",false) else "—", UIHelpers.format_numbers(d.get("revancha",[])) if d.get("revancha_enabled",false) else "—"]

func _open_edit() -> void:
    var selected := result_list.get_selected_items()
    if selected.is_empty(): return
    var d := Database.get_draw_by_id(_result_ids[selected[0]])
    _editing_id = str(d.get("record_id", "")); _edit_date.text = str(d.get("date", "")); _edit_draw.text = str(d.get("draw_number", "")); _edit_lotto.text = " ".join(_string_numbers(d.get("lotto", []))); _edit_revancha.text = " ".join(_string_numbers(d.get("revancha", []))) if d.get("revancha_enabled", false) else ""; _edit_dialog.popup_centered(Vector2i(620, 280))

func _save_edit() -> void:
    var lotto := _parse_numbers(_edit_lotto.text); var rev := _parse_numbers(_edit_revancha.text)
    var r := Database.update_draw(_editing_id, {"date": _edit_date.text, "draw_number": _edit_draw.text, "profile_id": "lotto_cr", "lotto_enabled": not lotto.is_empty(), "lotto": lotto, "revancha_enabled": not rev.is_empty(), "revancha": rev})
    if not r.get("ok", false): push_error("Corrección rechazada: %s" % r.get("message", ""))

func refresh_predictions() -> void:
    _prediction_ids.clear(); prediction_list.clear()
    var values := PredictionQueryService.get_all()
    values.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("created_at", "")) > str(b.get("created_at", "")))
    for p in values:
        var t: Dictionary = p.get("target", {})
        _prediction_ids.append(str(p.get("prediction_id", "")))
        prediction_list.add_item("%s · %s #%s · %s%s" % [p.get("prediction_id",""), str(t.get("type","lotto")).to_upper(), t.get("draw_number",""), str(p.get("status","pending")).to_upper(), " · ★90+" if p.get("attention_alert",{}).get("triggered",false) else ""])
    if not values.is_empty(): prediction_list.select(0); _show_prediction(0)
    else: prediction_detail.text = "Sin predicciones ni pruebas."

func _show_prediction(index: int) -> void:
    if index < 0 or index >= _prediction_ids.size(): return
    var p := PredictionQueryService.get_by_id(_prediction_ids[index]); var t: Dictionary = p.get("target", {}); var best: Dictionary = p.get("best", {}); var text := "[b]%s[/b] · %s\nObjetivo: %s · sorteo %s · %s\nModelo: %s\nMejor: %s · score %.2f\n" % [p.get("prediction_id",""), str(p.get("mode","")), DateUtils.display(str(t.get("date",""))), t.get("draw_number",""), str(t.get("type","lotto")).to_upper(), p.get("model_id",""), UIHelpers.format_numbers(best.get("numbers",[])), float(best.get("score",0.0))]
    var eval: Dictionary = p.get("official_evaluation", {})
    if not eval.is_empty():
        var s: Dictionary = eval.get("summary", {}); text += "\n[b]OFICIAL[/b] %s\nMejor %d/5 · Top5 %d/5 · Top10 %d/5" % [UIHelpers.format_numbers(eval.get("official_numbers",[])), int(s.get("best_combination_hits",0)), int(s.get("top_5_best_hits",0)), int(s.get("top_10_best_hits",0))]
    var feedback: Dictionary = p.get("manual_evaluation", {})
    if not feedback.is_empty(): text += "\n\nMarca provisional guardada: %s" % feedback.get("feedback_id", "")
    if p.get("affected_by_data_correction", false): text += "\n\n[color=yellow]AFECTADA POR CORRECCIÓN DEL HISTÓRICO[/color]"
    prediction_detail.text = text

func _parse_numbers(text: String) -> Array[int]:
    var result: Array[int] = []
    for part in text.replace(",", " ").split(" ", false):
        if part.strip_edges().is_valid_int(): result.append(int(part))
    return result

func _string_numbers(values: Array) -> PackedStringArray:
    var result := PackedStringArray(); for v in values: result.append("%02d" % int(v)); return result
```

## PASO 8F — Comparar

**Crear:** `ui/panels/comparison_panel.gd`

```gdscript
class_name ComparisonPanel
extends Control

var selector: OptionButton
var output: RichTextLabel
var predictions: Array[Dictionary] = []

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
    root.add_child(UIHelpers.title("COMPARAR"))
    selector = OptionButton.new(); selector.item_selected.connect(_show_selected); root.add_child(selector)
    output = RichTextLabel.new(); output.bbcode_enabled = true; output.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(output)
    PredictionStore.predictions_changed.connect(refresh)
    FeedbackStore.feedback_changed.connect(refresh)
    EvaluationStore.evaluations_changed.connect(refresh)
    refresh()

func refresh() -> void:
    predictions.clear(); selector.clear()
    for p in PredictionQueryService.get_all():
        if str(p.get("status", "")) == "verified": predictions.append(p)
    for p in predictions:
        var t: Dictionary = p.get("target", {})
        selector.add_item("%s · %s #%s" % [p.get("prediction_id", ""), str(t.get("type", "lotto")).to_upper(), t.get("draw_number", "")])
    if predictions.is_empty(): output.text = "No hay predicciones verificadas."; return
    selector.select(0); _show_selected(0)

func _show_selected(index: int) -> void:
    if index < 0 or index >= predictions.size(): return
    var p := predictions[index]; var e: Dictionary = p.get("official_evaluation", {}); var s: Dictionary = e.get("summary", {})
    var lines := PackedStringArray()
    lines.append("[b]%s[/b]" % p.get("prediction_id", ""))
    lines.append("Resultado oficial: %s" % UIHelpers.format_numbers(e.get("official_numbers", [])))
    var best: Dictionary = e.get("best", {})
    lines.append("\n[b]Mejor puntuada[/b]\n%s\nAciertos: %s (%d/5)" % [UIHelpers.format_numbers(best.get("numbers", [])), UIHelpers.format_numbers(best.get("hits", [])), int(best.get("hit_count", 0))])
    lines.append("\n[b]Top 5[/b] mejor: %d/5" % int(s.get("top_5_best_hits", 0)))
    for row in e.get("top_5", []): lines.append("#%d %s  → %d/5  [%s]" % [int(row.get("display_rank", 0)), UIHelpers.format_numbers(row.get("numbers", [])), int(row.get("hit_count", 0)), UIHelpers.format_numbers(row.get("hits", []))])
    lines.append("\n[b]Top 10[/b] mejor: %d/5" % int(s.get("top_10_best_hits", 0)))
    var manual: Dictionary = e.get("manual_comparison", {})
    lines.append("\nMarca provisional: %s" % ("sin marca" if not manual.get("available", false) else ("COINCIDE" if manual.get("matches", false) else "DIFIERE DEL OFICIAL")))
    output.text = "\n".join(lines)
```

## PASO 8G — Backtesting UI

**Crear:** `ui/panels/backtesting_panel.gd`

```gdscript
class_name BacktestingPanel
extends Control

var source: OptionButton
var target: OptionButton
var output: RichTextLabel

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
    root.add_child(UIHelpers.title("BACKTESTING"))
    var row := HBoxContainer.new(); root.add_child(row)
    source = OptionButton.new(); source.add_item("LOTTO"); source.set_item_metadata(0, StatisticsEngine.AnalysisSource.LOTTO_ONLY); source.add_item("REVANCHA"); source.set_item_metadata(1, StatisticsEngine.AnalysisSource.REVANCHA_ONLY); row.add_child(source)
    target = OptionButton.new(); target.add_item("LOTTO"); target.set_item_metadata(0, "lotto"); target.add_item("REVANCHA"); target.set_item_metadata(1, "revancha"); row.add_child(target)
    var validate := UIHelpers.make_button("VALIDAR SCORE"); validate.pressed.connect(_validate); row.add_child(validate)
    var optimize := UIHelpers.make_button("OPTIMIZAR PESOS"); optimize.pressed.connect(_optimize); row.add_child(optimize)
    var calibration := UIHelpers.make_button("CALIBRACIÓN"); calibration.pressed.connect(_calibrate); row.add_child(calibration)
    output = RichTextLabel.new(); output.bbcode_enabled = true; output.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(output)

func _validate() -> void:
    var model := ModelRegistry.get_active_model()
    var r := Backtester.run(Database.get_all_draws(), int(source.get_item_metadata(source.selected)), str(target.get_item_metadata(target.selected)), model.get("weights", CombinationScoreEngine.DEFAULT_WEIGHTS))
    output.text = "[b]VALIDACIÓN CRONOLÓGICA[/b]\nCasos fuera de muestra: %d\nPromedio mejor combinación: %.2f\nTop5 ≥2: %.1f%%\nTop5 ≥3: %.1f%%\n\nCon 12 resultados hay 0 casos futuros; el primer caso aparece al cargar el #13." % [int(r.get("cases", 0)), float(r.get("average_best_hits", 0.0)), float(r.get("top5_at_least_2", 0.0)), float(r.get("top5_at_least_3", 0.0))]

func _optimize() -> void:
    var r := WeightOptimizer.compare(Database.get_all_draws(), int(source.get_item_metadata(source.selected)), str(target.get_item_metadata(target.selected)))
    var lines := PackedStringArray(["[b]COMPARACIÓN DE PERFILES[/b]"])
    for row in r.get("rows", []):
        var result: Dictionary = row.get("result", {})
        lines.append("%s · objetivo %.2f · casos %d · promedio %.2f · ≥2 %.1f%% · ≥3 %.1f%%" % [row.get("name", ""), float(row.get("objective", 0.0)), int(result.get("cases", 0)), float(result.get("average_best_hits", 0.0)), float(result.get("top5_at_least_2", 0.0)), float(result.get("top5_at_least_3", 0.0))])
    lines.append("\nNo se promueve ningún modelo automáticamente. Use CONFIGURACIÓN para registrar/promover manualmente.")
    output.text = "\n".join(lines)


func _calibrate() -> void:
    var model := ModelRegistry.get_active_model()
    var result := ConfidenceCalibrationEngine.build(
        "all",
        str(target.get_item_metadata(target.selected)),
        str(model.get("signature", ""))
    )
    var lines := PackedStringArray()
    lines.append("[b]CALIBRACIÓN HISTÓRICA[/b]")
    lines.append("Sorteos independientes: %d · madurez %s" % [int(result.get("independent_draws", 0)), result.get("maturity", "")])
    for state in ["green", "yellow", "gray", "red"]:
        var b: Dictionary = result.get("buckets", {}).get(state, {})
        lines.append("%s: %d sorteos · promedio %.2f · ≥2 %.1f%%" % [state.to_upper(), int(b.get("draws", 0)), float(b.get("average_hits", 0.0)), float(b.get("at_least_2_percent", 0.0))])
    output.text = "\n".join(lines)
```

## PASO 8H — Configuración

**Crear:** `ui/panels/settings_panel.gd`

```gdscript
class_name SettingsPanel
extends Control

var models_list: ItemList
var output: Label
var audit_output: RichTextLabel
var _model_ids: Array[String] = []

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
    root.add_child(UIHelpers.title("CONFIGURACIÓN"))
    output = Label.new(); output.text = "Versión 0.0.0.1\nDatos: %s" % AppPaths.lotto_dir(); root.add_child(output)
    root.add_child(UIHelpers.section("MODELOS"))
    models_list = ItemList.new(); models_list.custom_minimum_size.y = 180; root.add_child(models_list)
    var actions := HBoxContainer.new(); root.add_child(actions)
    var create := UIHelpers.make_button("CREAR CANDIDATO RECIENTE"); create.pressed.connect(_create_candidate); actions.add_child(create)
    var promote := UIHelpers.make_button("PROMOVER SELECCIONADO"); promote.pressed.connect(_promote); actions.add_child(promote)
    var audit := UIHelpers.make_button("REVISIÓN AUSTERA"); audit.pressed.connect(_audit); actions.add_child(audit)
    audit_output = RichTextLabel.new(); audit_output.bbcode_enabled = true; audit_output.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(audit_output)
    ModelRegistry.models_changed.connect(refresh); refresh()

func refresh() -> void:
    _model_ids.clear(); models_list.clear()
    for m in ModelRegistry.get_all_models():
        _model_ids.append(str(m.get("model_id", "")))
        models_list.add_item("%s · %s · %s" % [m.get("model_id", ""), str(m.get("status", "")).to_upper(), m.get("label", "")])

func _create_candidate() -> void:
    var weights := WeightOptimizer.PROFILES["recent"].duplicate(true)
    var r := ModelRegistry.register_candidate("Perfil reciente", weights, {"created_from": "settings"}, false)
    audit_output.text = "Candidato creado: %s" % r.get("model", {}).get("model_id", "") if r.get("ok", false) else "ERROR: %s" % r.get("message", "")

func _promote() -> void:
    var selected := models_list.get_selected_items(); if selected.is_empty(): return
    var r := ModelRegistry.promote_candidate(_model_ids[selected[0]])
    audit_output.text = "Modelo promovido." if r.get("ok", false) else "ERROR: %s" % r.get("message", "")

func _audit() -> void:
    var r := ProjectAudit.run()
    audit_output.text = "[color=green][b]SIN ERRORES CRÍTICOS[/b][/color]" if r.get("ok", false) else "[color=red][b]ERRORES[/b][/color]\n- " + "\n- ".join(PackedStringArray(r.get("errors", [])))
```

## PASO 9A — Main

**Crear:** `ui/main/main.gd`

```gdscript
extends Control

var view_container: MarginContainer
var views: Dictionary = {}
var draw_count_label: Label
var db_label: Label
var version_label: Label
var active_view := "home"

func _ready() -> void:
    get_window().min_size = Vector2i(854, 480)
    get_window().max_size = Vector2i(1920, 1080)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_ui()
    Database.database_changed.connect(_on_database_changed)
    Database.database_error.connect(_on_database_error)
    _update_status()
    _show_view("home")

func _build_ui() -> void:
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_theme_constant_override("separation", 6); add_child(root)

    var header := HBoxContainer.new(); header.custom_minimum_size.y = 52; root.add_child(header)
    var title := Label.new(); title.text = "ACIERTA"; title.add_theme_font_size_override("font_size", 28); header.add_child(title)
    var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(spacer)
    var profile := Label.new(); profile.text = "Lotto / Lotto Revancha"; header.add_child(profile)
    var date := Label.new(); date.text = "   " + DateUtils.display(DateUtils.today()); header.add_child(date)

    var game_tabs := HBoxContainer.new(); root.add_child(game_tabs)
    var lotto := UIHelpers.make_button("LOTTO"); lotto.disabled = false; game_tabs.add_child(lotto)
    for text in ["3 MONAZOS · PRÓXIMAMENTE", "NUEVOS TIEMPOS · PRÓXIMAMENTE", "CHANCES · PRÓXIMAMENTE", "LOTERÍA NACIONAL · PRÓXIMAMENTE"]:
        var b := UIHelpers.make_button(text); b.disabled = true; game_tabs.add_child(b)

    var content := HSplitContainer.new(); content.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(content)
    var sidebar := VBoxContainer.new(); sidebar.custom_minimum_size.x = 220; sidebar.add_theme_constant_override("separation", 6); content.add_child(sidebar)
    var nav := {
        "home": "INICIO",
        "input": "INGRESAR RESULTADO",
        "generate": "GENERAR",
        "statistics": "ESTADÍSTICAS",
        "history": "HISTORIAL",
        "compare": "COMPARAR",
        "backtest": "BACKTESTING",
        "settings": "CONFIGURACIÓN"
    }
    for key in nav:
        var button := UIHelpers.make_button(nav[key]); button.pressed.connect(_show_view.bind(key)); sidebar.add_child(button)
    var side_spacer := Control.new(); side_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; sidebar.add_child(side_spacer)

    view_container = MarginContainer.new(); view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL; view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL; view_container.add_theme_constant_override("margin_left", 14); view_container.add_theme_constant_override("margin_right", 14); view_container.add_theme_constant_override("margin_top", 8); view_container.add_theme_constant_override("margin_bottom", 8); content.add_child(view_container)

    views = {
        "home": HomeDashboardPanel.new(),
        "input": InputResultPanel.new(),
        "generate": GeneratorPanel.new(),
        "statistics": StatisticsPanel.new(),
        "history": HistoryPanel.new(),
        "compare": ComparisonPanel.new(),
        "backtest": BacktestingPanel.new(),
        "settings": SettingsPanel.new()
    }
    for key in views:
        var view: Control = views[key]; view.visible = false; view_container.add_child(view)

    var status := HBoxContainer.new(); status.custom_minimum_size.y = 34; root.add_child(status)
    draw_count_label = Label.new(); status.add_child(draw_count_label)
    var status_spacer := Control.new(); status_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; status.add_child(status_spacer)
    db_label = Label.new(); status.add_child(db_label)
    version_label = Label.new(); status.add_child(version_label)

func _show_view(key: String) -> void:
    if not views.has(key): return
    active_view = key
    for k in views: views[k].visible = k == key

func _update_status() -> void:
    draw_count_label.text = "Resultados: %d" % Database.get_all_draws().size()
    db_label.text = "Base: v%d   " % Database.get_database_version()
    version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0.1"))

func _on_database_changed(_version: int) -> void:
    _update_status()

func _on_database_error(message: String) -> void:
    db_label.text = "BASE: ERROR   "
    push_error("ACIERTA DATABASE: %s" % message)
```

## PASO 9B — Escena principal

**Crear:** `ui/main/main.tscn`

```ini
[gd_scene load_steps=2 format=3]

[ext_resource path="res://ui/main/main.gd" type="Script" id="1"]

[node name="Main" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
```

## PASO 10A — Datos sintéticos de prueba

**Crear:** `tests/lotto_test_fixtures.gd`

```gdscript
class_name LottoTestFixtures
extends RefCounted

static func make_draw(index: int) -> Dictionary:
    var lotto: Array[int] = []
    var revancha: Array[int] = []
    for offset in range(5):
        lotto.append((index * 3 + offset * 7) % 41)
        revancha.append((index * 5 + offset * 9 + 2) % 41)
    lotto.sort()
    revancha.sort()
    return {
        "date": "2026-01-%02d" % index,
        "draw_number": str(1000 + index),
        "profile_id": "lotto_cr",
        "lotto_enabled": true,
        "lotto": lotto,
        "revancha_enabled": true,
        "revancha": revancha
    }

static func make_draws(first: int, last: int) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for index in range(first, last + 1):
        result.append(make_draw(index))
    return result
```

## PASO 10B — Smoke test

**Crear:** `tests/smoke_runner.gd`

```gdscript
extends Node

var passed := 0
var failed := 0
var failures: Array[String] = []

func _ready() -> void:
    if not AppPaths.test_mode:
        push_error("Ejecute con -- --acierta-test-reset")
        get_tree().quit(2)
        return
    await get_tree().process_frame
    _run()

func _run() -> void:
    _check("01 base vacía", Database.get_all_draws().size() == 0)
    _check("02 un modelo activo", not ModelRegistry.get_active_model().is_empty())

    var batch := Database.add_draws_batch(LottoTestFixtures.make_draws(1, 12))
    _check("03 importar 12", batch.get("ok", false))
    _check("04 draw_count 12", Database.get_all_draws().size() == 12)
    _check("05 database_version 1", Database.get_database_version() == 1)

    var generator := CombinationGenerator.new(GameProfile.lotto_costa_rica())
    _check("06 aplicar modelo", generator.apply_model(ModelRegistry.get_active_model()).get("ok", false))
    var generation := generator.generate(Database.get_all_draws(), StatisticsEngine.AnalysisSource.LOTTO_ONLY, 250, 17041)
    _check("07 generar con 12", generation.get("ok", false))
    _check("08 top10", generation.get("top_10", []).size() == 10)

    var saved := PredictionStore.save_generation(PredictionStore.MODE_PRETRAINING, generation, "2026-01-13", "1013", "lotto")
    _check("09 guardar TEST13", saved.get("ok", false))
    var pid := str(saved.get("prediction", {}).get("prediction_id", ""))
    var best_numbers: Array = saved.get("prediction", {}).get("best", {}).get("numbers", [])
    var feedback := [{"display_rank": 1, "hits": [best_numbers[0], best_numbers[1]], "hit_count": 2}]
    _check("10 feedback previo", FeedbackStore.save_feedback(pid, feedback).get("ok", false))

    _check("11 cargar resultado13", Database.add_draw(LottoTestFixtures.make_draw(13)).get("ok", false))
    EvaluationStore.reconcile_all()
    var evaluation := EvaluationStore.get_evaluation_for_prediction(pid)
    _check("12 evaluación automática", not evaluation.is_empty())
    _check("13 feedback posterior bloqueado", not FeedbackStore.can_edit_feedback(pid).get("ok", true))

    var eval_count := EvaluationStore.get_all_evaluations().size()
    for _i in range(10):
        EvaluationStore.reconcile_all()
    _check("14 reconcile x10 no duplica", EvaluationStore.get_all_evaluations().size() == eval_count)

    var old_eval_id := str(evaluation.get("evaluation_id", ""))
    var old_eval_revision := int(evaluation.get("revision", 1))
    var draw13 := Database.get_draw_by_identity("2026-01-13", "1013")
    var corrected := draw13.duplicate(true)
    var replacement := 40
    while replacement in corrected["lotto"]:
        replacement -= 1
    corrected["lotto"][0] = replacement
    corrected["lotto"].sort()
    _check("15 corregir objetivo", Database.update_draw(str(draw13.get("record_id", "")), corrected).get("ok", false))
    EvaluationStore.reconcile_all()
    var evaluation2 := EvaluationStore.get_evaluation_for_prediction(pid)
    _check("16 mismo evaluation_id", str(evaluation2.get("evaluation_id", "")) == old_eval_id)
    _check("17 revisión evaluación sube", int(evaluation2.get("revision", 0)) == old_eval_revision + 1)

    var path := AppPaths.lotto_file("results.json")
    var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
    if file != null:
        file.store_string("{ JSON CORTADO ")
        file.flush()
        file.close()
    _check("18 tmp corrupto no rompe", Database.reload_for_tests())
    _check("19 principal preservado", Database.get_all_draws().size() == 13)

    var raw := JsonFileStore.read_dictionary(path)
    if raw.get("ok", false):
        var future := raw["data"].duplicate(true)
        future["recovery_marker"] = "OK"
        _check("20 crear tmp válido interrumpido", JsonFileStore.write_interrupted_temp_for_test(path, future).get("ok", false))
        _check("21 recargar desde tmp válido", Database.reload_for_tests())
        var recovered := JsonFileStore.read_dictionary(path)
        _check("22 tmp válido recuperado", recovered.get("ok", false) and str(recovered["data"].get("recovery_marker", "")) == "OK")

    var audit := ProjectAudit.run()
    _check("23 revisión austera", audit.get("ok", false), str(audit.get("errors", [])))

    print("ACIERTA SMOKE: PASS=%d FAIL=%d" % [passed, failed])
    for item in failures:
        print("FAIL: ", item)
    get_tree().quit(0 if failed == 0 else 1)

func _check(name: String, condition: bool, detail: String = "") -> void:
    if condition:
        passed += 1
        print("PASS: ", name)
    else:
        failed += 1
        failures.append(name + (" · " + detail if not detail.is_empty() else ""))
```

## PASO 10C — Escena smoke test

**Crear:** `tests/smoke_runner.tscn`

```ini
[gd_scene load_steps=2 format=3]

[ext_resource path="res://tests/smoke_runner.gd" type="Script" id="1"]

[node name="SmokeRunner" type="Node"]
script = ExtResource("1")
```

## PASO 11 — Abrir el proyecto y comprobar Autoload

Abra `project.godot`. En **Project Settings → Globals → Autoload** debe verse, en este orden:

```text
1. AppPaths
2. Database
3. ModelRegistry
4. PredictionStore
5. FeedbackStore
6. EvaluationStore
```

No agregue otro Autoload.

## PASO 12 — Primera ejecución

Pulse **F6/F5**. Debe abrir Acierta con estas secciones:

```text
INICIO
INGRESAR RESULTADO
GENERAR
ESTADÍSTICAS
HISTORIAL
COMPARAR
BACKTESTING
CONFIGURACIÓN
```

En el primer arranque se crean automáticamente, dentro de `user://acierta/games/lotto/`:

```text
results.json
models.json
predictions.json
manual_feedback.json
evaluations.json
```

## PASO 13 — Prueba funcional corta en orden

### A. Cargar 12 históricos
En **INGRESAR RESULTADO → Importar lote**, use una línea por sorteo:

```text
AAAA-MM-DD|SORTEO|01 02 03 04 05|06 07 08 09 10
```

La cuarta columna puede quedar vacía si ese registro no tiene Revancha. Importe 12 sorteos.

### B. Generar el histórico #13
En **GENERAR**:

```text
Modo: PRUEBA / PREENTRENAMIENTO
Fuente: LOTTO
Objetivo: LOTTO
Fecha objetivo: fecha real del #13
Sorteo objetivo: número del #13
Candidatos: 1000
```

Pulse **GENERAR** y después **GUARDAR TEST/PRED**. Debe crear `TEST-000001`.

### C. Marca provisional
Pulse **MARCAR ACIERTOS**. Escriba solo los números que considera acertados en cada combinación y confirme. Esto se guarda en `manual_feedback.json`; todavía no cuenta como resultado oficial.

### D. Ingresar el resultado real #13
Vaya a **INGRESAR RESULTADO** y guarde el #13. `EvaluationStore` debe crear automáticamente la evaluación. Después de esto las marcas manuales quedan bloqueadas.

### E. Revisar
- **HISTORIAL:** debe aparecer el TEST como `VERIFIED`.
- **COMPARAR:** debe mostrar resultado oficial y aciertos.
- **INICIO:** debe actualizar resultados, pruebas y verificadas.
- **BACKTESTING:** con 13 sorteos ya existe 1 caso cronológico fuera de muestra.

### F. Persistencia
Cierre la ventana y vuelva a abrir Acierta. Los resultados, TEST, feedback y evaluación deben seguir ahí sin duplicarse.

## PASO 14 — Recuperación tras cierre/crash

No hay que pulsar nada. Cada guardado importante usa temporal + `flush()` + copia `.bak`. Al arrancar se elige la copia JSON válida con commit más reciente. La memoria se reconstruye desde disco; no se concatena con la memoria anterior.

## PASO 15 — Smoke test opcional

La revisión manual en Godot es la prueba definitiva. Si quiere ejecutar también el test automático desde consola, use el ejecutable de Godot 4.7.1 y esta forma:

```text
Godot_v4.7.1-stable_win64.exe --headless --path "RUTA\Acierta_v0.0.0.1" res://tests/smoke_runner.tscn -- --acierta-test-reset
```

El test utiliza `user://acierta_test`, nunca los datos normales de `user://acierta`.

## PASO 16 — Criterio para declarar v0.0.0.1 estable

No agregue otro juego todavía. Primero compruebe manualmente:

```text
[ ] abre sin error rojo
[ ] guarda Lotto
[ ] guarda Lotto + Revancha
[ ] rechaza repetidos y 41
[ ] importa 12 en lote
[ ] genera TEST #13
[ ] guarda feedback antes del resultado
[ ] carga #13 y evalúa automáticamente
[ ] bloquea feedback después del resultado
[ ] Historial y Comparar muestran lo mismo
[ ] cerrar/abrir no duplica datos
[ ] CONFIGURACIÓN → REVISIÓN AUSTERA no reporta errores
```

Cuando esa lista pase en Godot, **v0.0.0.1 queda cerrada** y entonces sí conviene comenzar la siguiente pestaña de lotería reutilizando esta base.

## Simplificaciones deliberadas para terminar esta versión

Se eliminaron piezas redundantes que no eran necesarias para la primera versión estable: `RecoveryManager` separado, `ComparisonEngine` separado, `ScoreValidator` separado, calendarios/selectores personalizados y backups históricos ilimitados. La recuperación vive en `JsonFileStore`, la comparación oficial en `EvaluationStore`, la validación cronológica en `Backtester` y se mantiene una copia `.bak` inmediata.
