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
