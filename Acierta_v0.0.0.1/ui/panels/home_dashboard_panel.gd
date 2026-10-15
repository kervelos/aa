class_name HomeDashboardPanel
extends Control

var output: RichTextLabel

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
    root.add_child(UIHelpers.title("INICIO"))
    output = RichTextLabel.new(); output.bbcode_enabled = true; output.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(output)
    Database.database_changed.connect(func(_v: int): refresh())
    PredictionStore.predictions_changed.connect(refresh)
    FeedbackStore.feedback_changed.connect(refresh)
    EvaluationStore.evaluations_changed.connect(refresh)
    ModelRegistry.models_changed.connect(refresh)
    refresh()

func refresh() -> void:
    var s := DashboardSummaryEngine.build(); var model := ModelRegistry.get_active_model(); var p: Dictionary = s.get("primary_performance", {})
    var lines := PackedStringArray()
    lines.append("[b]ACIERTA v0.0.0.1 · Lotto / Lotto Revancha[/b]")
    lines.append("\nResultados oficiales: %d" % int(s.get("draw_count", 0)))
    lines.append("Versión lógica de base: %d" % int(s.get("database_version", 0)))
    lines.append("Madurez: %s" % s.get("maturity_label", ""))
    lines.append("Modelo activo: %s · %s" % [model.get("model_id", "—"), model.get("label", "")])
    lines.append("\nPruebas: %d · Predicciones reales: %d · Verificadas limpias: %d" % [int(s.get("pretraining_count", 0)), int(s.get("real_count", 0)), int(s.get("verified_count", 0))])
    if p.is_empty(): lines.append("Rendimiento: todavía sin evaluaciones suficientes.")
    else: lines.append("Rendimiento: promedio mejor %.2f aciertos · Top5 ≥2 %.1f%% · Top5 ≥3 %.1f%%" % [float(p.get("average_hits", 0.0)), float(p.get("at_least_2_percent", 0.0)), float(p.get("at_least_3_percent", 0.0))])
    lines.append("Calibración: %s" % s.get("calibration_status", "Insuficiente"))
    var alert: Dictionary = s.get("latest_attention_alert", {})
    if not alert.is_empty(): lines.append("\n[b]★ ALERTA 90+ histórica[/b] %s · índice %.1f/100" % [alert.get("prediction_id", ""), float(alert.get("relative_index", 0.0))])
    lines.append("\n[color=gray]El score y el índice relativo comparan candidatos del modelo; no son probabilidades de ganar.[/color]")
    output.text = "\n".join(lines)
