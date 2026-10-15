class_name BacktestingPanel
extends Control

var source: OptionButton
var target: OptionButton
var output: RichTextLabel

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
    root.add_child(UIHelpers.title("BACKTESTING"))
    var row := HBoxContainer.new(); root.add_child(row)
    source = OptionButton.new(); source.add_item("LOTTO"); source.set_item_metadata(0, StatisticsEngine.AnalysisSource.LOTTO_ONLY); source.add_item("REVANCHA"); source.set_item_metadata(1, StatisticsEngine.AnalysisSource.REVANCHA_ONLY); row.add_child(source)
    target = OptionButton.new(); target.add_item("LOTTO"); target.set_item_metadata(0, "lotto"); target.add_item("REVANCHA"); target.set_item_metadata(1, "revancha"); row.add_child(target)
    var validate := UIHelpers.make_button("VALIDAR SCORE"); validate.pressed.connect(_validate); row.add_child(validate)
    var optimize := UIHelpers.make_button("OPTIMIZAR PESOS"); optimize.pressed.connect(_optimize); row.add_child(optimize)
    var calibration := UIHelpers.make_button("CALIBRACIÓN"); calibration.pressed.connect(_calibrate); row.add_child(calibration)
    output = RichTextLabel.new(); output.bbcode_enabled = true; output.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(output)

func _validate() -> void:
    var model := ModelRegistry.get_active_model()
    var r := Backtester.run(Database.get_all_draws(), int(source.get_item_metadata(source.selected)), str(target.get_item_metadata(target.selected)), model.get("weights", CombinationScoreEngine.DEFAULT_WEIGHTS))
    output.text = "[b]VALIDACIÓN CRONOLÓGICA[/b]\nCasos fuera de muestra: %d\nPromedio mejor combinación: %.2f\nTop5 ≥2: %.1f%%\nTop5 ≥3: %.1f%%\n\nCon 12 resultados hay 0 casos futuros; el primer caso aparece al cargar el #13." % [int(r.get("cases", 0)), float(r.get("average_best_hits", 0.0)), float(r.get("top5_at_least_2", 0.0)), float(r.get("top5_at_least_3", 0.0))]

func _optimize() -> void:
    var r := WeightOptimizer.compare(Database.get_all_draws(), int(source.get_item_metadata(source.selected)), str(target.get_item_metadata(target.selected)))
    var lines := PackedStringArray(["[b]COMPARACIÓN DE PERFILES[/b]"])
    for row in r.get("rows", []):
        var result: Dictionary = row.get("result", {})
        lines.append("%s · objetivo %.2f · casos %d · promedio %.2f · ≥2 %.1f%% · ≥3 %.1f%%" % [row.get("name", ""), float(row.get("objective", 0.0)), int(result.get("cases", 0)), float(result.get("average_best_hits", 0.0)), float(result.get("top5_at_least_2", 0.0)), float(result.get("top5_at_least_3", 0.0))])
    lines.append("\nNo se promueve ningún modelo automáticamente. Use CONFIGURACIÓN para registrar/promover manualmente.")
    output.text = "\n".join(lines)


func _calibrate() -> void:
    var model := ModelRegistry.get_active_model()
    var result := ConfidenceCalibrationEngine.build(
        "all",
        str(target.get_item_metadata(target.selected)),
        str(model.get("signature", ""))
    )
    var lines := PackedStringArray()
    lines.append("[b]CALIBRACIÓN HISTÓRICA[/b]")
    lines.append("Sorteos independientes: %d · madurez %s" % [int(result.get("independent_draws", 0)), result.get("maturity", "")])
    for state in ["green", "yellow", "gray", "red"]:
        var b: Dictionary = result.get("buckets", {}).get(state, {})
        lines.append("%s: %d sorteos · promedio %.2f · ≥2 %.1f%%" % [state.to_upper(), int(b.get("draws", 0)), float(b.get("average_hits", 0.0)), float(b.get("at_least_2_percent", 0.0))])
    output.text = "\n".join(lines)
