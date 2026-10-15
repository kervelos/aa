class_name AttentionAlertButton
extends Button

var _tween: Tween

func _init() -> void:
    text = "★ POSIBLE COMBINACIÓN"
    custom_minimum_size = Vector2(220, 48)
    disabled = true
    visible = false

func start_attention(duration: float = 15.0) -> void:
    stop_attention()
    visible = true
    modulate = Color(0.55, 1.0, 0.55, 1.0)
    _tween = create_tween()
    var cycles := max(1, int(duration / 1.5))
    _tween.set_loops(cycles)
    _tween.tween_property(self, "modulate:a", 0.35, 0.75)
    _tween.tween_property(self, "modulate:a", 1.0, 0.75)
    _tween.finished.connect(func(): modulate.a = 1.0)

func stop_attention() -> void:
    if _tween != null and _tween.is_valid():
        _tween.kill()
    _tween = null
    modulate.a = 1.0
