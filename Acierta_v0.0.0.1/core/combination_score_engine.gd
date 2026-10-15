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
