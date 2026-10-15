class_name JsonFileStore
extends RefCounted

static func read_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"ok": false, "message": "Archivo inexistente: %s" % path}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"ok": false, "message": "No se pudo abrir: %s" % path}
    var text := file.get_as_text()
    file.close()
    var json := JSON.new()
    var err := json.parse(text)
    if err != OK:
        return {"ok": false, "message": "JSON inválido en %s: %s" % [path, json.get_error_message()]}
    if typeof(json.data) != TYPE_DICTIONARY:
        return {"ok": false, "message": "El JSON no contiene un Dictionary: %s" % path}
    return {"ok": true, "data": json.data}

static func write_dictionary(path: String, content: Dictionary) -> Dictionary:
    var dir_path := path.get_base_dir()
    var mk := DirAccess.make_dir_recursive_absolute(dir_path)
    if mk != OK and not DirAccess.dir_exists_absolute(dir_path):
        return {"ok": false, "message": "No se pudo crear %s" % dir_path}

    var current_sequence := 0
    if FileAccess.file_exists(path):
        var old := read_dictionary(path)
        if old.get("ok", false):
            current_sequence = int(old["data"].get("_commit", {}).get("sequence", 0))

    var payload := content.duplicate(true)
    payload["_commit"] = {
        "sequence": current_sequence + 1,
        "written_at": Time.get_datetime_string_from_system()
    }

    var tmp := path + ".tmp"
    var bak := path + ".bak"
    var file := FileAccess.open(tmp, FileAccess.WRITE)
    if file == null:
        return {"ok": false, "message": "No se pudo abrir temporal: %s" % tmp}
    if not file.store_string(JSON.stringify(payload, "\t", true, true)):
        file.close()
        return {"ok": false, "message": "No se pudo escribir temporal: %s" % tmp}
    file.flush()
    file.close()

    var verify := read_dictionary(tmp)
    if not verify.get("ok", false):
        DirAccess.remove_absolute(tmp)
        return {"ok": false, "message": "El temporal no superó la verificación."}

    if FileAccess.file_exists(path):
        var copy_err := DirAccess.copy_absolute(path, bak)
        if copy_err != OK:
            DirAccess.remove_absolute(tmp)
            return {"ok": false, "message": "No se pudo crear la copia inmediata .bak"}

    var rename_err := DirAccess.rename_absolute(tmp, path)
    if rename_err != OK:
        return {"ok": false, "message": "No se pudo confirmar la escritura."}

    var final_check := read_dictionary(path)
    if not final_check.get("ok", false):
        return {"ok": false, "message": "El archivo final no pasó la verificación."}
    return {"ok": true, "data": final_check["data"]}

static func recover_dictionary(path: String) -> Dictionary:
    var candidates: Array[Dictionary] = []
    for candidate_path in [path, path + ".tmp", path + ".bak"]:
        if not FileAccess.file_exists(candidate_path):
            continue
        var r := read_dictionary(candidate_path)
        if not r.get("ok", false):
            continue
        candidates.append({
            "path": candidate_path,
            "data": r["data"],
            "sequence": int(r["data"].get("_commit", {}).get("sequence", 0))
        })
    if candidates.is_empty():
        return {"ok": false, "message": "No existe una copia válida de %s" % path}
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["sequence"]) > int(b["sequence"]))
    var winner := candidates[0]
    if str(winner["path"]) != path:
        var copy_err := DirAccess.copy_absolute(str(winner["path"]), path)
        if copy_err != OK:
            return {"ok": false, "message": "No se pudo restaurar %s" % path}
    if FileAccess.file_exists(path + ".tmp"):
        DirAccess.remove_absolute(path + ".tmp")
    var final := read_dictionary(path)
    if not final.get("ok", false):
        return final
    return {"ok": true, "data": final["data"], "recovered": str(winner["path"]) != path}

static func has_any_copy(path: String) -> bool:
    return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".tmp") or FileAccess.file_exists(path + ".bak")

static func write_interrupted_temp_for_test(path: String, content: Dictionary) -> Dictionary:
    if not AppPaths.test_mode:
        return {"ok": false, "message": "Solo disponible en modo de prueba."}
    var current_sequence := 0
    if FileAccess.file_exists(path):
        var current := read_dictionary(path)
        if current.get("ok", false):
            current_sequence = int(current["data"].get("_commit", {}).get("sequence", 0))
    var payload := content.duplicate(true)
    payload["_commit"] = {
        "sequence": current_sequence + 1,
        "written_at": Time.get_datetime_string_from_system()
    }
    var tmp := path + ".tmp"
    var file := FileAccess.open(tmp, FileAccess.WRITE)
    if file == null:
        return {"ok": false, "message": "No se pudo crear temporal de prueba."}
    var ok := file.store_string(JSON.stringify(payload, "\t", true, true))
    file.flush()
    file.close()
    return {"ok": ok}
