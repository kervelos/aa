class_name HistoryPanel
extends Control

var result_list: ItemList
var result_detail: RichTextLabel
var prediction_list: ItemList
var prediction_detail: RichTextLabel
var _result_ids: Array[String] = []
var _prediction_ids: Array[String] = []
var _edit_dialog: ConfirmationDialog
var _edit_date: LineEdit
var _edit_draw: LineEdit
var _edit_lotto: LineEdit
var _edit_revancha: LineEdit
var _editing_id := ""

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
    root.add_child(UIHelpers.title("HISTORIAL"))
    var tabs := TabContainer.new(); tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(tabs)
    _build_results_tab(tabs)
    _build_predictions_tab(tabs)
    _build_edit_dialog()
    Database.draw_added.connect(func(_d: Dictionary): refresh_results())
    Database.draw_updated.connect(func(_d: Dictionary): refresh_results())
    PredictionStore.predictions_changed.connect(refresh_predictions)
    FeedbackStore.feedback_changed.connect(refresh_predictions)
    EvaluationStore.evaluations_changed.connect(refresh_predictions)
    refresh_results(); refresh_predictions()

func _build_results_tab(tabs: TabContainer) -> void:
    var page := VBoxContainer.new(); page.name = "Resultados oficiales"; tabs.add_child(page)
    var split := HSplitContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL; page.add_child(split)
    result_list = ItemList.new(); result_list.custom_minimum_size.x = 360; result_list.item_selected.connect(_show_result); split.add_child(result_list)
    result_detail = RichTextLabel.new(); result_detail.bbcode_enabled = true; split.add_child(result_detail)
    var edit := UIHelpers.make_button("EDITAR RESULTADO SELECCIONADO"); edit.pressed.connect(_open_edit); page.add_child(edit)

func _build_predictions_tab(tabs: TabContainer) -> void:
    var page := VBoxContainer.new(); page.name = "Predicciones y pruebas"; tabs.add_child(page)
    var split := HSplitContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL; page.add_child(split)
    prediction_list = ItemList.new(); prediction_list.custom_minimum_size.x = 420; prediction_list.item_selected.connect(_show_prediction); split.add_child(prediction_list)
    prediction_detail = RichTextLabel.new(); prediction_detail.bbcode_enabled = true; split.add_child(prediction_detail)

func _build_edit_dialog() -> void:
    _edit_dialog = ConfirmationDialog.new(); _edit_dialog.title = "Corregir resultado"; _edit_dialog.confirmed.connect(_save_edit); add_child(_edit_dialog)
    var box := VBoxContainer.new(); _edit_dialog.add_child(box)
    _edit_date = LineEdit.new(); _edit_date.placeholder_text = "Fecha"; box.add_child(_labeled("Fecha", _edit_date))
    _edit_draw = LineEdit.new(); _edit_draw.placeholder_text = "Sorteo"; box.add_child(_labeled("Sorteo", _edit_draw))
    _edit_lotto = LineEdit.new(); _edit_lotto.placeholder_text = "03 11 17 28 35"; box.add_child(_labeled("Lotto", _edit_lotto))
    _edit_revancha = LineEdit.new(); _edit_revancha.placeholder_text = "05 11 19 28 40 o vacío"; box.add_child(_labeled("Revancha", _edit_revancha))

func _labeled(label_text: String, field: Control) -> HBoxContainer:
    var row := HBoxContainer.new(); var l := Label.new(); l.text = label_text + ":"; l.custom_minimum_size.x = 100; row.add_child(l); field.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(field); return row

func refresh_results() -> void:
    _result_ids.clear(); result_list.clear()
    var draws := Database.get_all_draws()
    draws.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("date", "")) > str(b.get("date", "")))
    for d in draws:
        _result_ids.append(str(d.get("record_id", "")))
        result_list.add_item("%s · #%s · rev.%d" % [DateUtils.display(str(d.get("date", ""))), d.get("draw_number", ""), int(d.get("revision", 1))])
    if not draws.is_empty(): result_list.select(0); _show_result(0)
    else: result_detail.text = "Sin resultados."

func _show_result(index: int) -> void:
    if index < 0 or index >= _result_ids.size(): return
    var d := Database.get_draw_by_id(_result_ids[index])
    result_detail.text = "[b]%s · Sorteo %s[/b]\nID %s · revisión %d\n\nLOTTO\n%s\n\nREVANCHA\n%s" % [DateUtils.display(str(d.get("date",""))), d.get("draw_number",""), d.get("record_id",""), int(d.get("revision",1)), UIHelpers.format_numbers(d.get("lotto",[])) if d.get("lotto_enabled",false) else "—", UIHelpers.format_numbers(d.get("revancha",[])) if d.get("revancha_enabled",false) else "—"]

func _open_edit() -> void:
    var selected := result_list.get_selected_items()
    if selected.is_empty(): return
    var d := Database.get_draw_by_id(_result_ids[selected[0]])
    _editing_id = str(d.get("record_id", "")); _edit_date.text = str(d.get("date", "")); _edit_draw.text = str(d.get("draw_number", "")); _edit_lotto.text = " ".join(_string_numbers(d.get("lotto", []))); _edit_revancha.text = " ".join(_string_numbers(d.get("revancha", []))) if d.get("revancha_enabled", false) else ""; _edit_dialog.popup_centered(Vector2i(620, 280))

func _save_edit() -> void:
    var lotto := _parse_numbers(_edit_lotto.text); var rev := _parse_numbers(_edit_revancha.text)
    var r := Database.update_draw(_editing_id, {"date": _edit_date.text, "draw_number": _edit_draw.text, "profile_id": "lotto_cr", "lotto_enabled": not lotto.is_empty(), "lotto": lotto, "revancha_enabled": not rev.is_empty(), "revancha": rev})
    if not r.get("ok", false): push_error("Corrección rechazada: %s" % r.get("message", ""))

func refresh_predictions() -> void:
    _prediction_ids.clear(); prediction_list.clear()
    var values := PredictionQueryService.get_all()
    values.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("created_at", "")) > str(b.get("created_at", "")))
    for p in values:
        var t: Dictionary = p.get("target", {})
        _prediction_ids.append(str(p.get("prediction_id", "")))
        prediction_list.add_item("%s · %s #%s · %s%s" % [p.get("prediction_id",""), str(t.get("type","lotto")).to_upper(), t.get("draw_number",""), str(p.get("status","pending")).to_upper(), " · ★90+" if p.get("attention_alert",{}).get("triggered",false) else ""])
    if not values.is_empty(): prediction_list.select(0); _show_prediction(0)
    else: prediction_detail.text = "Sin predicciones ni pruebas."

func _show_prediction(index: int) -> void:
    if index < 0 or index >= _prediction_ids.size(): return
    var p := PredictionQueryService.get_by_id(_prediction_ids[index]); var t: Dictionary = p.get("target", {}); var best: Dictionary = p.get("best", {}); var text := "[b]%s[/b] · %s\nObjetivo: %s · sorteo %s · %s\nModelo: %s\nMejor: %s · score %.2f\n" % [p.get("prediction_id",""), str(p.get("mode","")), DateUtils.display(str(t.get("date",""))), t.get("draw_number",""), str(t.get("type","lotto")).to_upper(), p.get("model_id",""), UIHelpers.format_numbers(best.get("numbers",[])), float(best.get("score",0.0))]
    var eval: Dictionary = p.get("official_evaluation", {})
    if not eval.is_empty():
        var s: Dictionary = eval.get("summary", {}); text += "\n[b]OFICIAL[/b] %s\nMejor %d/5 · Top5 %d/5 · Top10 %d/5" % [UIHelpers.format_numbers(eval.get("official_numbers",[])), int(s.get("best_combination_hits",0)), int(s.get("top_5_best_hits",0)), int(s.get("top_10_best_hits",0))]
    var feedback: Dictionary = p.get("manual_evaluation", {})
    if not feedback.is_empty(): text += "\n\nMarca provisional guardada: %s" % feedback.get("feedback_id", "")
    if p.get("affected_by_data_correction", false): text += "\n\n[color=yellow]AFECTADA POR CORRECCIÓN DEL HISTÓRICO[/color]"
    prediction_detail.text = text

func _parse_numbers(text: String) -> Array[int]:
    var result: Array[int] = []
    for part in text.replace(",", " ").split(" ", false):
        if part.strip_edges().is_valid_int(): result.append(int(part))
    return result

func _string_numbers(values: Array) -> PackedStringArray:
    var result := PackedStringArray(); for v in values: result.append("%02d" % int(v)); return result
