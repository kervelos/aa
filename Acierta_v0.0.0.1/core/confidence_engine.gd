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
