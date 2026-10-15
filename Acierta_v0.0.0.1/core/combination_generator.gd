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
