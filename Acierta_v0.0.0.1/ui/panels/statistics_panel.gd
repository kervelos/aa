class_name StatisticsPanel
extends Control

var source: OptionButton
var output: RichTextLabel

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
    root.add_child(UIHelpers.title("ESTADÍSTICAS"))
    var row := HBoxContainer.new(); root.add_child(row)
    source = OptionButton.new(); source.add_item("LOTTO"); source.set_item_metadata(0, StatisticsEngine.AnalysisSource.LOTTO_ONLY); source.add_item("REVANCHA"); source.set_item_metadata(1, StatisticsEngine.AnalysisSource.REVANCHA_ONLY); source.add_item("AMBOS"); source.set_item_metadata(2, StatisticsEngine.AnalysisSource.BOTH); row.add_child(source)
    var refresh := UIHelpers.make_button("CALCULAR"); refresh.pressed.connect(_refresh); row.add_child(refresh)
    output = RichTextLabel.new(); output.bbcode_enabled = true; output.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(output)
    Database.database_changed.connect(func(_v: int): _refresh())
    _refresh()

func _refresh() -> void:
    var s := StatisticsEngine.analyze(Database.get_all_draws(), int(source.get_item_metadata(source.selected)), GameProfile.lotto_costa_rica())
    var lines := PackedStringArray()
    lines.append("[b]Muestras:[/b] %d" % int(s.get("sample_count", 0)))
    lines.append("\n[b]Frecuencia por número[/b]")
    for n in range(0, 41): lines.append("%02d: %d" % [n, int(s.get("frequency", {}).get(n, 0))])
    lines.append("\n[b]Forma promedio[/b]")
    var shape: Dictionary = s.get("shape", {})
    lines.append("Suma %.2f | Rango %.2f | Pares %.2f | Bajos 00-20 %.2f | Consecutivos %.2f" % [shape.get("avg_sum",0.0), shape.get("avg_span",0.0), shape.get("avg_even",0.0), shape.get("avg_low",0.0), shape.get("avg_consecutive",0.0)])
    var overlap := StatisticsEngine.same_draw_overlap(Database.get_all_draws())
    lines.append("\n[b]Solapamiento Lotto/Revancha mismo sorteo:[/b] %s" % str(overlap.get("overlap_counts", {})))
    output.text = "\n".join(lines)
