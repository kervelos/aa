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
