extends Control

var view_container: MarginContainer
var views: Dictionary = {}
var draw_count_label: Label
var db_label: Label
var version_label: Label
var active_view := "home"

func _ready() -> void:
    get_window().min_size = Vector2i(854, 480)
    get_window().max_size = Vector2i(1920, 1080)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_ui()
    Database.database_changed.connect(_on_database_changed)
    Database.database_error.connect(_on_database_error)
    _update_status()
    _show_view("home")

func _build_ui() -> void:
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_theme_constant_override("separation", 6); add_child(root)

    var header := HBoxContainer.new(); header.custom_minimum_size.y = 52; root.add_child(header)
    var title := Label.new(); title.text = "ACIERTA"; title.add_theme_font_size_override("font_size", 28); header.add_child(title)
    var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(spacer)
    var profile := Label.new(); profile.text = "Lotto / Lotto Revancha"; header.add_child(profile)
    var date := Label.new(); date.text = "   " + DateUtils.display(DateUtils.today()); header.add_child(date)

    var game_tabs := HBoxContainer.new(); root.add_child(game_tabs)
    var lotto := UIHelpers.make_button("LOTTO"); lotto.disabled = false; game_tabs.add_child(lotto)
    for text in ["3 MONAZOS · PRÓXIMAMENTE", "NUEVOS TIEMPOS · PRÓXIMAMENTE", "CHANCES · PRÓXIMAMENTE", "LOTERÍA NACIONAL · PRÓXIMAMENTE"]:
        var b := UIHelpers.make_button(text); b.disabled = true; game_tabs.add_child(b)

    var content := HSplitContainer.new(); content.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(content)
    var sidebar := VBoxContainer.new(); sidebar.custom_minimum_size.x = 220; sidebar.add_theme_constant_override("separation", 6); content.add_child(sidebar)
    var nav := {
        "home": "INICIO",
        "input": "INGRESAR RESULTADO",
        "generate": "GENERAR",
        "statistics": "ESTADÍSTICAS",
        "history": "HISTORIAL",
        "compare": "COMPARAR",
        "backtest": "BACKTESTING",
        "settings": "CONFIGURACIÓN"
    }
    for key in nav:
        var button := UIHelpers.make_button(nav[key]); button.pressed.connect(_show_view.bind(key)); sidebar.add_child(button)
    var side_spacer := Control.new(); side_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; sidebar.add_child(side_spacer)

    view_container = MarginContainer.new(); view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL; view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL; view_container.add_theme_constant_override("margin_left", 14); view_container.add_theme_constant_override("margin_right", 14); view_container.add_theme_constant_override("margin_top", 8); view_container.add_theme_constant_override("margin_bottom", 8); content.add_child(view_container)

    views = {
        "home": HomeDashboardPanel.new(),
        "input": InputResultPanel.new(),
        "generate": GeneratorPanel.new(),
        "statistics": StatisticsPanel.new(),
        "history": HistoryPanel.new(),
        "compare": ComparisonPanel.new(),
        "backtest": BacktestingPanel.new(),
        "settings": SettingsPanel.new()
    }
    for key in views:
        var view: Control = views[key]; view.visible = false; view_container.add_child(view)

    var status := HBoxContainer.new(); status.custom_minimum_size.y = 34; root.add_child(status)
    draw_count_label = Label.new(); status.add_child(draw_count_label)
    var status_spacer := Control.new(); status_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; status.add_child(status_spacer)
    db_label = Label.new(); status.add_child(db_label)
    version_label = Label.new(); status.add_child(version_label)

func _show_view(key: String) -> void:
    if not views.has(key): return
    active_view = key
    for k in views: views[k].visible = k == key

func _update_status() -> void:
    draw_count_label.text = "Resultados: %d" % Database.get_all_draws().size()
    db_label.text = "Base: v%d   " % Database.get_database_version()
    version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0.1"))

func _on_database_changed(_version: int) -> void:
    _update_status()

func _on_database_error(message: String) -> void:
    db_label.text = "BASE: ERROR   "
    push_error("ACIERTA DATABASE: %s" % message)
