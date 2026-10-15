class_name ProjectAudit
extends RefCounted

static func run() -> Dictionary:
    var errors: Array[String] = []
    var ids := {}
    var identities := {}
    var profile := GameProfile.lotto_costa_rica()
    for draw in Database.get_all_draws():
        var rid := str(draw.get("record_id", ""))
        if rid.is_empty() or ids.has(rid): errors.append("record_id duplicado o vacío: %s" % rid)
        ids[rid] = true
        var key := "%s|%s|%s" % [draw.get("profile_id", ""), draw.get("date", ""), draw.get("draw_number", "")]
        if identities.has(key): errors.append("sorteo duplicado: %s" % key)
        identities[key] = true
        if bool(draw.get("lotto_enabled", false)) and not profile.validate_numbers(draw.get("lotto", [])).get("ok", false): errors.append("Lotto inválido en %s" % rid)
        if bool(draw.get("revancha_enabled", false)) and not profile.validate_numbers(draw.get("revancha", [])).get("ok", false): errors.append("Revancha inválida en %s" % rid)
    var active := 0
    for model in ModelRegistry.get_all_models():
        if str(model.get("status", "")) == ModelRegistry.STATUS_ACTIVE: active += 1
    if active != 1: errors.append("Debe existir exactamente un modelo activo.")
    var pred_ids := {}
    for p in PredictionStore.get_all_predictions():
        var pid := str(p.get("prediction_id", ""))
        if pred_ids.has(pid): errors.append("prediction_id duplicado: %s" % pid)
        pred_ids[pid] = true
        if p.has("official_evaluation") or p.has("manual_evaluation"): errors.append("predictions.json mezcla capas en %s" % pid)
    var eval_counts := {}
    for e in EvaluationStore.get_all_evaluations():
        var pid := str(e.get("prediction_id", "")); eval_counts[pid] = int(eval_counts.get(pid, 0)) + 1
        if not pred_ids.has(pid): errors.append("Evaluación huérfana: %s" % pid)
    for pid in eval_counts:
        if int(eval_counts[pid]) > 1: errors.append("Evaluación redundante: %s" % pid)
    var fb_counts := {}
    for f in FeedbackStore.get_all_feedback():
        var pid := str(f.get("prediction_id", "")); fb_counts[pid] = int(fb_counts.get(pid, 0)) + 1
        if not pred_ids.has(pid): errors.append("Feedback huérfano: %s" % pid)
    for pid in fb_counts:
        if int(fb_counts[pid]) > 1: errors.append("Feedback redundante: %s" % pid)
    return {"ok": errors.is_empty(), "errors": errors}
