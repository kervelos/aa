extends Node

signal database_loaded
signal database_error(message: String)
signal draw_added(draw: Dictionary)
signal draw_updated(draw: Dictionary)
signal database_changed(database_version: int)

var database: Dictionary = {}

func _ready() -> void:
    _load_or_create_database()

func _database_path() -> String:
    return AppPaths.lotto_file("results.json")

func _create_empty_database() -> Dictionary:
    return {
        "schema_version": 1,
        "database_version": 0,
        "next_record_id": 1,
        "draws": []
    }

func _load_or_create_database() -> void:
    var path := _database_path()
    if not JsonFileStore.has_any_copy(path):
        var r := JsonFileStore.write_dictionary(path, _create_empty_database())
        if not r.get("ok", false):
            database_error.emit(str(r.get("message", "No se pudo crear results.json")))
            return
        database = r["data"].duplicate(true)
        database_loaded.emit()
        return
    var recovered := JsonFileStore.recover_dictionary(path)
    if not recovered.get("ok", false):
        database_error.emit(str(recovered.get("message", "No se pudo recuperar results.json")))
        return
    var loaded: Dictionary = recovered["data"]
    var validation := _validate_database_structure(loaded)
    if not validation.get("ok", false):
        database_error.emit(str(validation.get("message", "Estructura inválida")))
        return
    database = loaded.duplicate(true)
    database_loaded.emit()

func _validate_database_structure(value: Dictionary) -> Dictionary:
    for key in ["schema_version", "database_version", "next_record_id", "draws"]:
        if not value.has(key):
            return {"ok": false, "message": "results.json no contiene %s" % key}
    if typeof(value["draws"]) != TYPE_ARRAY:
        return {"ok": false, "message": "draws debe ser Array"}
    return {"ok": true}

func get_all_draws() -> Array:
    return database.get("draws", []).duplicate(true)

func get_database_version() -> int:
    return int(database.get("database_version", 0))

func get_draw_by_id(record_id: String) -> Dictionary:
    for draw in database.get("draws", []):
        if str(draw.get("record_id", "")) == record_id:
            return draw.duplicate(true)
    return {}

func get_draw_by_identity(date: String, draw_number: String, profile_id: String = "lotto_cr") -> Dictionary:
    var normalized := DateUtils.normalize_date(date)
    for draw in database.get("draws", []):
        if str(draw.get("date", "")) == normalized and str(draw.get("draw_number", "")) == draw_number and str(draw.get("profile_id", "")) == profile_id:
            return draw.duplicate(true)
    return {}

func has_result_for_target(date: String, draw_number: String, profile_id: String, target_type: String) -> bool:
    return not get_target_result(date, draw_number, profile_id, target_type).is_empty()

func get_target_result(date: String, draw_number: String, profile_id: String, target_type: String) -> Dictionary:
    var draw := get_draw_by_identity(date, draw_number, profile_id)
    if draw.is_empty():
        return {}
    var enabled_key := "lotto_enabled" if target_type == "lotto" else "revancha_enabled"
    var numbers_key := "lotto" if target_type == "lotto" else "revancha"
    if not bool(draw.get(enabled_key, false)):
        return {}
    return {
        "record_id": str(draw.get("record_id", "")),
        "revision": int(draw.get("revision", 1)),
        "date": str(draw.get("date", "")),
        "draw_number": str(draw.get("draw_number", "")),
        "profile_id": str(draw.get("profile_id", "lotto_cr")),
        "type": target_type,
        "numbers": draw.get(numbers_key, []).duplicate()
    }

func add_draw(input: Dictionary) -> Dictionary:
    var validation := _validate_draw_input(input)
    if not validation.get("ok", false):
        return {"ok": false, "error": "validation", "message": validation.get("message", "Datos inválidos")}
    var normalized := _normalize_input(input)
    if not get_draw_by_identity(normalized["date"], normalized["draw_number"], normalized["profile_id"]).is_empty():
        return {"ok": false, "error": "duplicate", "message": "El sorteo ya existe."}
    var working := database.duplicate(true)
    var sequence := int(working.get("next_record_id", 1))
    var now := Time.get_datetime_string_from_system()
    var draw := normalized.duplicate(true)
    draw["record_id"] = "DRAW-%06d" % sequence
    draw["revision"] = 1
    draw["created_at"] = now
    draw["updated_at"] = now
    working["draws"].append(draw)
    working["next_record_id"] = sequence + 1
    working["database_version"] = int(working.get("database_version", 0)) + 1
    var commit := JsonFileStore.write_dictionary(_database_path(), working)
    if not commit.get("ok", false):
        return {"ok": false, "error": "storage", "message": commit.get("message", "No se pudo guardar")}
    database = commit["data"].duplicate(true)
    draw_added.emit(draw.duplicate(true))
    database_changed.emit(get_database_version())
    return {"ok": true, "draw": draw.duplicate(true)}

func add_draws_batch(inputs: Array) -> Dictionary:
    if inputs.is_empty():
        return {"ok": false, "message": "No hay registros para importar."}
    var normalized_batch: Array[Dictionary] = []
    var batch_keys := {}
    for raw in inputs:
        var validation := _validate_draw_input(raw)
        if not validation.get("ok", false):
            return {"ok": false, "message": validation.get("message", "Registro inválido")}
        var item := _normalize_input(raw)
        var key := "%s|%s|%s" % [item["profile_id"], item["date"], item["draw_number"]]
        if batch_keys.has(key):
            return {"ok": false, "message": "Duplicado dentro del lote: %s" % key}
        if not get_draw_by_identity(item["date"], item["draw_number"], item["profile_id"]).is_empty():
            return {"ok": false, "message": "Ya existe el sorteo %s." % item["draw_number"]}
        batch_keys[key] = true
        normalized_batch.append(item)

    var working := database.duplicate(true)
    var sequence := int(working.get("next_record_id", 1))
    var now := Time.get_datetime_string_from_system()
    var added: Array[Dictionary] = []
    for item in normalized_batch:
        var draw := item.duplicate(true)
        draw["record_id"] = "DRAW-%06d" % sequence
        draw["revision"] = 1
        draw["created_at"] = now
        draw["updated_at"] = now
        working["draws"].append(draw)
        added.append(draw)
        sequence += 1
    working["next_record_id"] = sequence
    working["database_version"] = int(working.get("database_version", 0)) + 1
    var commit := JsonFileStore.write_dictionary(_database_path(), working)
    if not commit.get("ok", false):
        return {"ok": false, "message": commit.get("message", "No se pudo importar")}
    database = commit["data"].duplicate(true)
    for draw in added:
        draw_added.emit(draw.duplicate(true))
    database_changed.emit(get_database_version())
    return {"ok": true, "count": added.size()}

func update_draw(record_id: String, input: Dictionary) -> Dictionary:
    var validation := _validate_draw_input(input)
    if not validation.get("ok", false):
        return {"ok": false, "message": validation.get("message", "Datos inválidos")}
    var normalized := _normalize_input(input)
    var working := database.duplicate(true)
    var index := -1
    for i in range(working["draws"].size()):
        if str(working["draws"][i].get("record_id", "")) == record_id:
            index = i
            break
    if index < 0:
        return {"ok": false, "message": "Registro inexistente."}
    for draw in working["draws"]:
        if str(draw.get("record_id", "")) == record_id:
            continue
        if str(draw.get("date", "")) == normalized["date"] and str(draw.get("draw_number", "")) == normalized["draw_number"] and str(draw.get("profile_id", "")) == normalized["profile_id"]:
            return {"ok": false, "message": "La corrección produciría un sorteo duplicado."}
    var old: Dictionary = working["draws"][index]
    var updated := normalized.duplicate(true)
    updated["record_id"] = record_id
    updated["revision"] = int(old.get("revision", 1)) + 1
    updated["created_at"] = str(old.get("created_at", ""))
    updated["updated_at"] = Time.get_datetime_string_from_system()
    working["draws"][index] = updated
    working["database_version"] = int(working.get("database_version", 0)) + 1
    var commit := JsonFileStore.write_dictionary(_database_path(), working)
    if not commit.get("ok", false):
        return {"ok": false, "message": commit.get("message", "No se pudo actualizar")}
    database = commit["data"].duplicate(true)
    draw_updated.emit(updated.duplicate(true))
    database_changed.emit(get_database_version())
    return {"ok": true, "draw": updated.duplicate(true)}

func _normalize_input(input: Dictionary) -> Dictionary:
    var lotto: Array[int] = []
    var revancha: Array[int] = []
    if bool(input.get("lotto_enabled", false)):
        for v in input.get("lotto", []):
            lotto.append(int(v))
        lotto.sort()
    if bool(input.get("revancha_enabled", false)):
        for v in input.get("revancha", []):
            revancha.append(int(v))
        revancha.sort()
    return {
        "date": DateUtils.normalize_date(str(input.get("date", ""))),
        "draw_number": str(input.get("draw_number", "")).strip_edges(),
        "profile_id": str(input.get("profile_id", "lotto_cr")),
        "lotto_enabled": bool(input.get("lotto_enabled", false)),
        "lotto": lotto,
        "revancha_enabled": bool(input.get("revancha_enabled", false)),
        "revancha": revancha
    }

func _validate_draw_input(input: Dictionary) -> Dictionary:
    var date := DateUtils.normalize_date(str(input.get("date", "")))
    if date.is_empty():
        return {"ok": false, "message": "Fecha inválida. Use AAAA-MM-DD o DD/MM/AAAA."}
    var draw_number := str(input.get("draw_number", "")).strip_edges()
    if draw_number.is_empty():
        return {"ok": false, "message": "Falta el número de sorteo."}
    var lotto_enabled := bool(input.get("lotto_enabled", false))
    var revancha_enabled := bool(input.get("revancha_enabled", false))
    if not lotto_enabled and not revancha_enabled:
        return {"ok": false, "message": "Active Lotto, Revancha o ambas."}
    var profile := GameProfile.lotto_costa_rica()
    if lotto_enabled:
        var r := profile.validate_numbers(input.get("lotto", []))
        if not r.get("ok", false):
            return {"ok": false, "message": "Lotto: %s" % r.get("message", "")}
    if revancha_enabled:
        var r := profile.validate_numbers(input.get("revancha", []))
        if not r.get("ok", false):
            return {"ok": false, "message": "Revancha: %s" % r.get("message", "")}
    return {"ok": true}

func reload_for_tests() -> bool:
    if not AppPaths.test_mode:
        return false
    _load_or_create_database()
    return true
