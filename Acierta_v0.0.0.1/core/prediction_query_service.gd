class_name PredictionQueryService
extends RefCounted

static func get_all() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for prediction in PredictionStore.get_all_predictions():
        var joined := prediction.duplicate(true)
        var pid := str(joined.get("prediction_id", ""))
        var feedback := FeedbackStore.get_feedback_for_prediction(pid)
        var evaluation := EvaluationStore.get_evaluation_for_prediction(pid)
        joined["manual_evaluation"] = feedback
        joined["official_evaluation"] = evaluation
        joined["status"] = "verified" if not evaluation.is_empty() else ("manual_review" if not feedback.is_empty() else "pending")
        result.append(joined)
    return result

static func get_by_id(prediction_id: String) -> Dictionary:
    for p in get_all():
        if str(p.get("prediction_id", "")) == prediction_id:
            return p
    return {}
