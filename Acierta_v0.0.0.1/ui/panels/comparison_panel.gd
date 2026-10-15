class_name ComparisonPanel
extends Control

var selector: OptionButton
var output: RichTextLabel
var predictions: Array[Dictionary] = []

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
    root.add_child(UIHelpers.title("COMPARAR"))
    selector = OptionButton.new(); selector.item_selected.connect(_show_selected); root.add_child(selector)
    output = RichTextLabel.new(); output.bbcode_enabled = true; output.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(output)
    PredictionStore.predictions_changed.connect(refresh)
    FeedbackStore.feedback_changed.connect(refresh)
    EvaluationStore.evaluations_changed.connect(refresh)
    refresh()

func refresh() -> void:
    predictions.clear(); selector.clear()
    for p in PredictionQueryService.get_all():
        if str(p.get("status", "")) == "verified": predictions.append(p)
    for p in predictions:
        var t: Dictionary = p.get("target", {})
        selector.add_item("%s · %s #%s" % [p.get("prediction_id", ""), str(t.get("type", "lotto")).to_upper(), t.get("draw_number", "")])
    if predictions.is_empty(): output.text = "No hay predicciones verificadas."; return
    selector.select(0); _show_selected(0)

func _show_selected(index: int) -> void:
    if index < 0 or index >= predictions.size(): return
    var p := predictions[index]; var e: Dictionary = p.get("official_evaluation", {}); var s: Dictionary = e.get("summary", {})
    var lines := PackedStringArray()
    lines.append("[b]%s[/b]" % p.get("prediction_id", ""))
    lines.append("Resultado oficial: %s" % UIHelpers.format_numbers(e.get("official_numbers", [])))
    var best: Dictionary = e.get("best", {})
    lines.append("\n[b]Mejor puntuada[/b]\n%s\nAciertos: %s (%d/5)" % [UIHelpers.format_numbers(best.get("numbers", [])), UIHelpers.format_numbers(best.get("hits", [])), int(best.get("hit_count", 0))])
    lines.append("\n[b]Top 5[/b] mejor: %d/5" % int(s.get("top_5_best_hits", 0)))
    for row in e.get("top_5", []): lines.append("#%d %s  → %d/5  [%s]" % [int(row.get("display_rank", 0)), UIHelpers.format_numbers(row.get("numbers", [])), int(row.get("hit_count", 0)), UIHelpers.format_numbers(row.get("hits", []))])
    lines.append("\n[b]Top 10[/b] mejor: %d/5" % int(s.get("top_10_best_hits", 0)))
    var manual: Dictionary = e.get("manual_comparison", {})
    lines.append("\nMarca provisional: %s" % ("sin marca" if not manual.get("available", false) else ("COINCIDE" if manual.get("matches", false) else "DIFIERE DEL OFICIAL")))
    output.text = "\n".join(lines)
