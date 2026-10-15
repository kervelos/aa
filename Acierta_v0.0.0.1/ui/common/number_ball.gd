class_name NumberBall
extends Button

enum State { NORMAL, SELECTED, HIT, WARNING, ERROR }

var number_value := -1
var state := State.NORMAL

func _init() -> void:
    custom_minimum_size = Vector2(44, 44)
    disabled = true

func set_number(value: int) -> void:
    number_value = value
    text = "%02d" % value

func set_state(value: int) -> void:
    state = value
    match state:
        State.HIT: modulate = Color(0.55, 1.0, 0.55)
        State.WARNING: modulate = Color(1.0, 0.9, 0.45)
        State.ERROR: modulate = Color(1.0, 0.55, 0.55)
        State.SELECTED: modulate = Color(0.65, 0.8, 1.0)
        _: modulate = Color.WHITE
