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
