class_name UIHelpers
extends RefCounted

static func clear_children(node: Node) -> void:
    for child in node.get_children():
        child.queue_free()

static func title(text: String) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 24)
    return label

static func section(text: String) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 18)
    return label

static func make_button(text: String) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size.y = 44
    return b

static func format_numbers(numbers: Array) -> String:
    var parts := PackedStringArray()
    for n in numbers: parts.append("%02d" % int(n))
    return "  ".join(parts)

static func add_balls(container: Container, numbers: Array, hits: Array = []) -> void:
    clear_children(container)
    for n in numbers:
        var b := NumberBall.new()
        b.set_number(int(n))
        if int(n) in hits: b.set_state(NumberBall.State.HIT)
        container.add_child(b)
