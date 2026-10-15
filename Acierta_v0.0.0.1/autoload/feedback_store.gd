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
