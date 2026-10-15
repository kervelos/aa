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
