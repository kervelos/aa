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
