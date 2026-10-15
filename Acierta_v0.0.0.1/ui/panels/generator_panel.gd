class_name GeneratorPanel
extends Control

var profile := GameProfile.lotto_costa_rica()
var generator: CombinationGenerator
var last_generation: Dictionary = {}
var saved_prediction_id := ""

var mode_option: OptionButton
var source_option: OptionButton
var target_option: OptionButton
var target_date: LineEdit
var target_draw: LineEdit
var candidate_spin: SpinBox
var generate_button: Button
var save_button: Button
var feedback_button: Button
var status_label: Label
var best_label: RichTextLabel
var top_label: RichTextLabel
var alert_button: AttentionAlertButton
var feedback_dialog: ConfirmationDialog
var feedback_content: VBoxContainer
var feedback_fields: Dictionary = {}

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    generator = CombinationGenerator.new(profile)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_theme_constant_override("separation", 8); add_child(root)
    root.add_child(UIHelpers.title("GENERAR"))
    var controls := GridContainer.new(); controls.columns = 4; root.add_child(controls)
    controls.add_child(_label("Modo")); mode_option = OptionButton.new(); mode_option.add_item("PREDICCIÓN REAL"); mode_option.set_item_metadata(0, PredictionStore.MODE_REAL); mode_option.add_item("PRUEBA / PREENTRENAMIENTO"); mode_option.set_item_metadata(1, PredictionStore.MODE_PRETRAINING); mode_option.select(1); controls.add_child(mode_option)
    controls.add_child(_label("Fuente")); source_option = OptionButton.new(); source_option.add_item("LOTTO"); source_option.set_item_metadata(0, StatisticsEngine.AnalysisSource.LOTTO_ONLY); source_option.add_item("REVANCHA"); source_option.set_item_metadata(1, StatisticsEngine.AnalysisSource.REVANCHA_ONLY); source_option.add_item("AMBOS"); source_option.set_item_metadata(2, StatisticsEngine.AnalysisSource.BOTH); controls.add_child(source_option)
    controls.add_child(_label("Objetivo")); target_option = OptionButton.new(); target_option.add_item("LOTTO"); target_option.set_item_metadata(0, "lotto"); target_option.add_item("REVANCHA"); target_option.set_item_metadata(1, "revancha"); controls.add_child(target_option)
    controls.add_child(_label("Fecha objetivo")); target_date = LineEdit.new(); target_date.text = DateUtils.today(); controls.add_child(target_date)
    controls.add_child(_label("Sorteo objetivo")); target_draw = LineEdit.new(); controls.add_child(target_draw)
    controls.add_child(_label("Candidatos")); candidate_spin = SpinBox.new(); candidate_spin.min_value = 50; candidate_spin.max_value = 2500; candidate_spin.step = 50; candidate_spin.value = 1000; controls.add_child(candidate_spin)

    var actions := HBoxContainer.new(); root.add_child(actions)
    generate_button = UIHelpers.make_button("GENERAR"); generate_button.pressed.connect(_generate); actions.add_child(generate_button)
    save_button = UIHelpers.make_button("GUARDAR TEST/PRED"); save_button.disabled = true; save_button.pressed.connect(_save); actions.add_child(save_button)
    feedback_button = UIHelpers.make_button("MARCAR ACIERTOS"); feedback_button.disabled = true; feedback_button.pressed.connect(_open_feedback); actions.add_child(feedback_button)
    alert_button = AttentionAlertButton.new(); actions.add_child(alert_button)
    status_label = Label.new(); status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; root.add_child(status_label)
    best_label = RichTextLabel.new(); best_label.bbcode_enabled = true; best_label.custom_minimum_size.y = 120; root.add_child(best_label)
    top_label = RichTextLabel.new(); top_label.bbcode_enabled = true; top_label.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(top_label)
    _build_feedback_dialog()
    Database.database_changed.connect(_on_database_changed)
    ModelRegistry.models_changed.connect(_on_model_changed)
    EvaluationStore.evaluations_changed.connect(_on_evaluations_changed)

func _label(text: String) -> Label:
    var l := Label.new(); l.text = text + ":"; return l

func _generate() -> void:
    if Database.get_all_draws().size() < 12:
        status_label.text = "Se requieren al menos 12 resultados históricos."; return
    if DateUtils.normalize_date(target_date.text).is_empty() or target_draw.text.strip_edges().is_empty():
        status_label.text = "Complete fecha y sorteo objetivo."; return
    var model := ModelRegistry.get_active_model()
    var applied := generator.apply_model(model)
    if not applied.get("ok", false): status_label.text = str(applied.get("message", "No se pudo aplicar modelo")); return
    status_label.text = "Generando..."
    var result := generator.generate(Database.get_all_draws(), int(source_option.get_item_metadata(source_option.selected)), int(candidate_spin.value))
    if not result.get("ok", false): last_generation = {}; status_label.text = str(result.get("message", "No se pudo generar")); return
    last_generation = result.duplicate(true); saved_prediction_id = ""; save_button.disabled = false; feedback_button.disabled = true; _show_generation(); status_label.text = "Generación lista. Revise y guarde si corresponde."

func _show_generation() -> void:
    var best: Dictionary = last_generation.get("best", {}); var conf: Dictionary = best.get("confidence", {})
    best_label.text = "[b]MEJOR PUNTUADA[/b]\n%s\nScore %.2f / 100 · Índice relativo %.1f / 100 · Percentil %.1f · Estado %s" % [UIHelpers.format_numbers(best.get("numbers", [])), float(best.get("score", 0.0)), float(conf.get("relative_index", 0.0)), float(conf.get("percentile", 0.0)), str(conf.get("state", "gray")).to_upper()]
    var lines := PackedStringArray(["[b]TOP 10[/b]"])
    for c in last_generation.get("top_10", []):
        var cc: Dictionary = c.get("confidence", {})
        lines.append("#%d  %s   score %.2f   %s %.1f" % [int(c.get("display_rank", 0)), UIHelpers.format_numbers(c.get("numbers", [])), float(c.get("score", 0.0)), str(cc.get("state", "gray")).to_upper(), float(cc.get("relative_index", 0.0))])
    top_label.text = "\n".join(lines)
    if last_generation.get("attention_alert", {}).get("triggered", false): alert_button.start_attention(15.0)
    else: alert_button.stop_attention(); alert_button.visible = false

func _save() -> void:
    if last_generation.is_empty(): return
    var mode := str(mode_option.get_item_metadata(mode_option.selected)); var target_type := str(target_option.get_item_metadata(target_option.selected))
    var r := PredictionStore.save_generation(mode, last_generation, target_date.text, target_draw.text, target_type)
    if not r.get("ok", false): status_label.text = "ERROR: %s" % r.get("message", "No se pudo guardar"); return
    saved_prediction_id = str(r.get("prediction", {}).get("prediction_id", "")); save_button.disabled = true; feedback_button.disabled = mode != PredictionStore.MODE_PRETRAINING; status_label.text = "%s guardada correctamente." % saved_prediction_id

func _build_feedback_dialog() -> void:
    feedback_dialog = ConfirmationDialog.new()
    feedback_dialog.title = "Marcas provisionales"
    feedback_dialog.confirmed.connect(_save_feedback)
    add_child(feedback_dialog)

    feedback_content = VBoxContainer.new()
    feedback_content.custom_minimum_size = Vector2(680, 430)
    feedback_dialog.add_child(feedback_content)

func _open_feedback() -> void:
    if saved_prediction_id.is_empty(): return
    var permission := FeedbackStore.can_edit_feedback(saved_prediction_id)
    if not permission.get("ok", false): status_label.text = str(permission.get("message", "Feedback bloqueado")); feedback_button.disabled = true; return
    UIHelpers.clear_children(feedback_content)
    feedback_fields.clear()
    var info := Label.new(); info.text = "Escriba SOLO los números que usted considera acertados. Ejemplo: 11 17"; feedback_content.add_child(info)
    var p := PredictionStore.get_prediction_by_id(saved_prediction_id)
    var existing := FeedbackStore.get_feedback_for_prediction(saved_prediction_id)
    var existing_by_rank := {}
    for entry in existing.get("combinations", []): existing_by_rank[int(entry.get("display_rank", 0))] = entry.get("hits", [])
    for c in p.get("top_10", []):
        var rank := int(c.get("display_rank", 0)); var row := HBoxContainer.new(); feedback_content.add_child(row)
        var l := Label.new(); l.text = "#%d  %s  →" % [rank, UIHelpers.format_numbers(c.get("numbers", []))]; l.custom_minimum_size.x = 360; row.add_child(l)
        var e := LineEdit.new(); e.placeholder_text = "aciertos"; if existing_by_rank.has(rank): e.text = " ".join(_to_strings(existing_by_rank[rank])); row.add_child(e); feedback_fields[rank] = {"field": e, "allowed": c.get("numbers", []).duplicate()}
    feedback_dialog.popup_centered(Vector2i(720, 520))

func _save_feedback() -> void:
    var combinations: Array[Dictionary] = []
    for rank in feedback_fields:
        var info: Dictionary = feedback_fields[rank]; var hits := _parse_numbers(info["field"].text)
        for n in hits:
            if n not in info["allowed"]: status_label.text = "ERROR: el número %02d no pertenece a la combinación #%d." % [n, int(rank)]; return
        combinations.append({"display_rank": int(rank), "hits": hits, "hit_count": hits.size()})
    var r := FeedbackStore.save_feedback(saved_prediction_id, combinations)
    status_label.text = "Marcas provisionales guardadas." if r.get("ok", false) else "ERROR: %s" % r.get("message", "No se pudo guardar feedback")

func _parse_numbers(text: String) -> Array[int]:
    var result: Array[int] = []
    for part in text.replace(",", " ").split(" ", false):
        if part.strip_edges().is_valid_int():
            var n := int(part)
            if n not in result: result.append(n)
    result.sort(); return result

func _to_strings(values: Array) -> PackedStringArray:
    var result := PackedStringArray(); for v in values: result.append("%02d" % int(v)); return result

func _on_database_changed(_version: int) -> void:
    if not last_generation.is_empty(): last_generation = {}; saved_prediction_id = ""; save_button.disabled = true; feedback_button.disabled = true; status_label.text = "La base cambió. Genere nuevamente."

func _on_model_changed() -> void:
    if not last_generation.is_empty(): last_generation = {}; saved_prediction_id = ""; save_button.disabled = true; feedback_button.disabled = true; status_label.text = "El modelo cambió. Genere nuevamente."

func _on_evaluations_changed() -> void:
    if saved_prediction_id.is_empty(): return
    var e := EvaluationStore.get_evaluation_for_prediction(saved_prediction_id)
    if e.is_empty(): return
    feedback_button.disabled = true
    var s: Dictionary = e.get("summary", {})
    status_label.text = "Resultado verificado · Top5 %d/5 · Top10 %d/5" % [int(s.get("top_5_best_hits", 0)), int(s.get("top_10_best_hits", 0))]
