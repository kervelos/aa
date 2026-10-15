class_name InputResultPanel
extends Control

var date_edit: LineEdit
var draw_edit: LineEdit
var lotto_check: CheckButton
var revancha_check: CheckButton
var lotto_fields: Array[LineEdit] = []
var revancha_fields: Array[LineEdit] = []
var status_label: Label
var bulk_text: TextEdit

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_theme_constant_override("separation", 10); add_child(root)
    root.add_child(UIHelpers.title("INGRESAR RESULTADO"))
    var tabs := TabContainer.new(); tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(tabs)
    _build_manual(tabs)
    _build_bulk(tabs)
    status_label = Label.new(); status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; root.add_child(status_label)

func _build_manual(tabs: TabContainer) -> void:
    var manual := VBoxContainer.new(); manual.name = "Manual"; manual.add_theme_constant_override("separation", 8); tabs.add_child(manual)
    var date_row := HBoxContainer.new(); manual.add_child(date_row)
    date_row.add_child(Label.new()); date_row.get_child(0).text = "Fecha (AAAA-MM-DD o DD/MM/AAAA):"
    date_edit = LineEdit.new(); date_edit.text = DateUtils.today(); date_edit.custom_minimum_size.x = 180; date_row.add_child(date_edit)
    date_row.add_child(Label.new()); date_row.get_child(2).text = "Sorteo:"
    draw_edit = LineEdit.new(); draw_edit.custom_minimum_size.x = 140; date_row.add_child(draw_edit)

    lotto_check = CheckButton.new(); lotto_check.text = "LOTTO"; lotto_check.button_pressed = true; manual.add_child(lotto_check)
    var lotto_row := HBoxContainer.new(); manual.add_child(lotto_row)
    for i in range(5):
        var e := _number_field(); lotto_fields.append(e); lotto_row.add_child(e)

    revancha_check = CheckButton.new(); revancha_check.text = "LOTTO REVANCHA"; revancha_check.button_pressed = true; manual.add_child(revancha_check)
    var rev_row := HBoxContainer.new(); manual.add_child(rev_row)
    for i in range(5):
        var e := _number_field(); revancha_fields.append(e); rev_row.add_child(e)

    var actions := HBoxContainer.new(); manual.add_child(actions)
    var save := UIHelpers.make_button("GUARDAR"); save.pressed.connect(_save_manual); actions.add_child(save)
    var clear := UIHelpers.make_button("LIMPIAR"); clear.pressed.connect(_clear_manual); actions.add_child(clear)

func _build_bulk(tabs: TabContainer) -> void:
    var bulk := VBoxContainer.new(); bulk.name = "Importar lote"; tabs.add_child(bulk)
    var help := Label.new(); help.text = "Una línea por sorteo:\nAAAA-MM-DD|SORTEO|01 02 03 04 05|06 07 08 09 10\nLa Revancha puede dejarse vacía."; help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; bulk.add_child(help)
    bulk_text = TextEdit.new(); bulk_text.size_flags_vertical = Control.SIZE_EXPAND_FILL; bulk.add_child(bulk_text)
    var import_button := UIHelpers.make_button("IMPORTAR TODO"); import_button.pressed.connect(_import_bulk); bulk.add_child(import_button)

func _number_field() -> LineEdit:
    var e := LineEdit.new(); e.custom_minimum_size = Vector2(64, 44); e.max_length = 2; e.placeholder_text = "00"; return e

func _collect(fields: Array[LineEdit]) -> Array[int]:
    var values: Array[int] = []
    for e in fields:
        if e.text.strip_edges().is_empty(): continue
        if not e.text.strip_edges().is_valid_int(): return []
        values.append(int(e.text))
    return values

func _save_manual() -> void:
    var record := {
        "date": date_edit.text,
        "draw_number": draw_edit.text,
        "profile_id": "lotto_cr",
        "lotto_enabled": lotto_check.button_pressed,
        "lotto": _collect(lotto_fields),
        "revancha_enabled": revancha_check.button_pressed,
        "revancha": _collect(revancha_fields)
    }
    var r := Database.add_draw(record)
    status_label.text = "Guardado: %s" % r.get("draw", {}).get("record_id", "") if r.get("ok", false) else "ERROR: %s" % r.get("message", "No se pudo guardar")
    if r.get("ok", false): _clear_numbers_only()

func _clear_manual() -> void:
    draw_edit.clear(); _clear_numbers_only(); status_label.text = ""

func _clear_numbers_only() -> void:
    for e in lotto_fields: e.clear()
    for e in revancha_fields: e.clear()

func _import_bulk() -> void:
    var batch: Array[Dictionary] = []
    var line_number := 0
    for raw_line in bulk_text.text.split("\n"):
        line_number += 1
        var line := raw_line.strip_edges()
        if line.is_empty(): continue
        var parts := line.split("|")
        if parts.size() < 3 or parts.size() > 4:
            status_label.text = "ERROR línea %d: formato inválido." % line_number; return
        var lotto := _parse_number_text(str(parts[2]))
        var revancha := _parse_number_text(str(parts[3])) if parts.size() == 4 and not str(parts[3]).strip_edges().is_empty() else []
        batch.append({"date": str(parts[0]), "draw_number": str(parts[1]).strip_edges(), "profile_id": "lotto_cr", "lotto_enabled": true, "lotto": lotto, "revancha_enabled": not revancha.is_empty(), "revancha": revancha})
    var r := Database.add_draws_batch(batch)
    status_label.text = "Importados %d sorteos." % int(r.get("count", 0)) if r.get("ok", false) else "ERROR: %s" % r.get("message", "No se pudo importar")
    if r.get("ok", false): bulk_text.clear()

func _parse_number_text(text: String) -> Array[int]:
    var clean := text.replace(",", " ").replace(";", " ")
    var result: Array[int] = []
    for part in clean.split(" ", false):
        if part.strip_edges().is_valid_int(): result.append(int(part))
    return result
