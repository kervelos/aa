class_name DashboardSummaryEngine
extends RefCounted

static func build() -> Dictionary:
    var draws := Database.get_all_draws()
    var predictions := PredictionQueryService.get_all()
    var pretraining := 0
    var real := 0
    var verified := 0
    var alerts := 0
    var latest_alert: Dictionary = {}
    for p in predictions:
        if str(p.get("mode", "")) == PredictionStore.MODE_PRETRAINING:
            pretraining += 1
        if str(p.get("mode", "")) == PredictionStore.MODE_REAL:
            real += 1
        if str(p.get("status", "")) == "verified" and not bool(p.get("affected_by_data_correction", false)):
            verified += 1
        if p.get("attention_alert", {}).get("triggered", false):
            alerts += 1
            latest_alert = {
                "prediction_id": p.get("prediction_id", ""),
                "relative_index": p.get("attention_alert", {}).get("relative_index", 0.0)
            }
    var real_metrics := LearningMetricsEngine.build(PredictionStore.MODE_REAL)
    var pretraining_metrics := LearningMetricsEngine.build(PredictionStore.MODE_PRETRAINING)
    var primary := real_metrics if int(real_metrics.get("independent_runs", 0)) > 0 else pretraining_metrics
    var calibration := ConfidenceCalibrationEngine.build(PredictionStore.MODE_REAL if int(real_metrics.get("independent_runs", 0)) > 0 else PredictionStore.MODE_PRETRAINING)
    return {
        "draw_count": draws.size(),
        "database_version": Database.get_database_version(),
        "maturity_label": _maturity(draws.size()),
        "pretraining_count": pretraining,
        "real_count": real,
        "verified_count": verified,
        "alert_count": alerts,
        "primary_performance": primary,
        "calibration_status": calibration.get("maturity", "INSUFICIENTE"),
        "latest_attention_alert": latest_alert
    }

static func _maturity(count: int) -> String:
    if count < 5:
        return "INSUFICIENTE"
    if count < 10:
        return "EXPLORATORIO"
    if count < 12:
        return "PRELIMINAR"
    if count < 20:
        return "ENTRENAMIENTO INICIAL"
    if count < 40:
        return "EN DESARROLLO"
    return "VALIDACIÓN MÁS AMPLIA"
