extends Node

signal models_changed
signal model_error(message: String)

const STATUS_ACTIVE := "active"
const STATUS_CANDIDATE := "candidate"
const STATUS_RETIRED := "retired"
const STATUS_REJECTED := "rejected"

var data: Dictionary = {}

func _ready() -> void:
    _load_or_create()

func _models_path() -> String:
    return AppPaths.lotto_file("models.json")

func _create_initial_data() -> Dictionary:
    var engine := CombinationScoreEngine.new(GameProfile.lotto_costa_rica())
    var now := Time.get_datetime_string_from_system()
    return {
        "schema_version": 1,
        "next_model_sequence": 2,
        "active_model_id": "MODEL-000001",
        "models": [{
            "model_id": "MODEL-000001",
            "label": "Modelo inicial",
            "status": STATUS_ACTIVE,
            "model_version": CombinationScoreEngine.MODEL_VERSION,
            "signature": engine.get_model_signature(),
            "weights": engine.get_weights_snapshot(),
            "origin": "initial",
            "created_at": now,
            "promoted_at": now,
            "retired_at": "",
            "parent_model_id": "",
            "promotion_eligible": false,
            "optimizer_snapshot": {}
        }]
    }

func _load_or_create() -> void:
    var path := _models_path()
    if not JsonFileStore.has_any_copy(path):
        var r := JsonFileStore.write_dictionary(path, _create_initial_data())
        if not r.get("ok", false):
            model_error.emit(str(r.get("message", "No se pudo crear models.json")))
            return
        data = r["data"].duplicate(true)
        models_changed.emit()
        return
    var r := JsonFileStore.recover_dictionary(path)
    if not r.get("ok", false):
        model_error.emit(str(r.get("message", "No se pudo recuperar models.json")))
        return
    data = r["data"].duplicate(true)
    _validate_active()

func get_all_models() -> Array:
    return data.get("models", []).duplicate(true)

func get_model_by_id(model_id: String) -> Dictionary:
    for model in data.get("models", []):
        if str(model.get("model_id", "")) == model_id:
            return model.duplicate(true)
    return {}

func get_active_model() -> Dictionary:
    return get_model_by_id(str(data.get("active_model_id", "")))

func register_candidate(label: String, weights: Dictionary, optimizer_snapshot: Dictionary = {}, promotion_eligible: bool = false) -> Dictionary:
    var engine := CombinationScoreEngine.new(GameProfile.lotto_costa_rica())
    var validation := engine.validate_weight_profile(weights)
    if not validation.get("ok", false): return validation
    engine.set_weights(weights)
    var working := data.duplicate(true)
    var sequence := int(working.get("next_model_sequence", 2))
    var model := {
        "model_id": "MODEL-%06d" % sequence,
        "label": label.strip_edges() if not label.strip_edges().is_empty() else "Modelo candidato",
        "status": STATUS_CANDIDATE,
        "model_version": CombinationScoreEngine.MODEL_VERSION,
        "signature": engine.get_model_signature(),
        "weights": weights.duplicate(true),
        "origin": "optimizer",
        "created_at": Time.get_datetime_string_from_system(),
        "promoted_at": "",
        "retired_at": "",
        "parent_model_id": str(working.get("active_model_id", "")),
        "promotion_eligible": promotion_eligible,
        "optimizer_snapshot": optimizer_snapshot.duplicate(true)
    }
    working["models"].append(model)
    working["next_model_sequence"] = sequence + 1
    var commit := _commit(working)
    if not commit.get("ok", false): return commit
    return {"ok": true, "model": model.duplicate(true)}

func promote_candidate(model_id: String) -> Dictionary:
    var working := data.duplicate(true)
    var found := false
    var now := Time.get_datetime_string_from_system()
    for i in range(working["models"].size()):
        var model: Dictionary = working["models"][i]
        if str(model.get("model_id", "")) == model_id:
            if str(model.get("status", "")) != STATUS_CANDIDATE:
                return {"ok": false, "message": "Solo se puede promover un candidato."}
            found = true
    if not found: return {"ok": false, "message": "Modelo inexistente."}
    for i in range(working["models"].size()):
        var model: Dictionary = working["models"][i]
        if str(model.get("status", "")) == STATUS_ACTIVE:
            model["status"] = STATUS_RETIRED
            model["retired_at"] = now
            working["models"][i] = model
        elif str(model.get("model_id", "")) == model_id:
            model["status"] = STATUS_ACTIVE
            model["promoted_at"] = now
            working["models"][i] = model
    working["active_model_id"] = model_id
    return _commit(working)

func reject_candidate(model_id: String) -> Dictionary:
    var working := data.duplicate(true)
    for i in range(working["models"].size()):
        var model: Dictionary = working["models"][i]
        if str(model.get("model_id", "")) == model_id and str(model.get("status", "")) == STATUS_CANDIDATE:
            model["status"] = STATUS_REJECTED
            working["models"][i] = model
            return _commit(working)
    return {"ok": false, "message": "Candidato inexistente."}

func _commit(working: Dictionary) -> Dictionary:
    var r := JsonFileStore.write_dictionary(_models_path(), working)
    if not r.get("ok", false):
        model_error.emit(str(r.get("message", "Error guardando modelos")))
        return r
    data = r["data"].duplicate(true)
    models_changed.emit()
    return {"ok": true}

func _validate_active() -> void:
    var count := 0
    for model in data.get("models", []):
        if str(model.get("status", "")) == STATUS_ACTIVE: count += 1
    if count != 1 or get_active_model().is_empty():
        model_error.emit("models.json debe contener exactamente un modelo activo válido.")

func reload_for_tests() -> bool:
    if not AppPaths.test_mode: return false
    _load_or_create()
    return true
