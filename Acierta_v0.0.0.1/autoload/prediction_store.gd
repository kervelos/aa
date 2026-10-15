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
