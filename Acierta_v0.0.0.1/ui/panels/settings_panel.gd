class_name SettingsPanel
extends Control

var models_list: ItemList
var output: Label
var audit_output: RichTextLabel
var _model_ids: Array[String] = []

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
    root.add_child(UIHelpers.title("CONFIGURACIÓN"))
    output = Label.new(); output.text = "Versión 0.0.0.1\nDatos: %s" % AppPaths.lotto_dir(); root.add_child(output)
    root.add_child(UIHelpers.section("MODELOS"))
    models_list = ItemList.new(); models_list.custom_minimum_size.y = 180; root.add_child(models_list)
    var actions := HBoxContainer.new(); root.add_child(actions)
    var create := UIHelpers.make_button("CREAR CANDIDATO RECIENTE"); create.pressed.connect(_create_candidate); actions.add_child(create)
    var promote := UIHelpers.make_button("PROMOVER SELECCIONADO"); promote.pressed.connect(_promote); actions.add_child(promote)
    var audit := UIHelpers.make_button("REVISIÓN AUSTERA"); audit.pressed.connect(_audit); actions.add_child(audit)
    audit_output = RichTextLabel.new(); audit_output.bbcode_enabled = true; audit_output.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(audit_output)
    ModelRegistry.models_changed.connect(refresh); refresh()

func refresh() -> void:
    _model_ids.clear(); models_list.clear()
    for m in ModelRegistry.get_all_models():
        _model_ids.append(str(m.get("model_id", "")))
        models_list.add_item("%s · %s · %s" % [m.get("model_id", ""), str(m.get("status", "")).to_upper(), m.get("label", "")])

func _create_candidate() -> void:
    var weights := WeightOptimizer.PROFILES["recent"].duplicate(true)
    var r := ModelRegistry.register_candidate("Perfil reciente", weights, {"created_from": "settings"}, false)
    audit_output.text = "Candidato creado: %s" % r.get("model", {}).get("model_id", "") if r.get("ok", false) else "ERROR: %s" % r.get("message", "")

func _promote() -> void:
    var selected := models_list.get_selected_items(); if selected.is_empty(): return
    var r := ModelRegistry.promote_candidate(_model_ids[selected[0]])
    audit_output.text = "Modelo promovido." if r.get("ok", false) else "ERROR: %s" % r.get("message", "")

func _audit() -> void:
    var r := ProjectAudit.run()
    audit_output.text = "[color=green][b]SIN ERRORES CRÍTICOS[/b][/color]" if r.get("ok", false) else "[color=red][b]ERRORES[/b][/color]\n- " + "\n- ".join(PackedStringArray(r.get("errors", [])))
