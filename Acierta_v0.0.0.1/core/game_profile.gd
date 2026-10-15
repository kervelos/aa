class_name GameProfile
extends RefCounted

var id := "lotto_cr"
var title := "Lotto Costa Rica"
var min_number := 0
var max_number := 40
var numbers_per_draw := 5
var display_digits := 2
var suggestion_count := 5

static func lotto_costa_rica() -> GameProfile:
    return GameProfile.new()

static func custom_00_40_six() -> GameProfile:
    var p := GameProfile.new()
    p.id = "custom_00_40_6"
    p.title = "Experimental 6 de 41"
    p.numbers_per_draw = 6
    return p

func is_valid_number(value: int) -> bool:
    return value >= min_number and value <= max_number

func format_number(value: int) -> String:
    return ("%0*d" % [display_digits, value])

func validate_numbers(values: Array) -> Dictionary:
    if values.size() != numbers_per_draw:
        return {"ok": false, "message": "Se requieren exactamente %d números." % numbers_per_draw}
    var seen := {}
    for raw in values:
        var value := int(raw)
        if not is_valid_number(value):
            return {"ok": false, "message": "El número %d está fuera del rango %02d-%02d." % [value, min_number, max_number]}
        if seen.has(value):
            return {"ok": false, "message": "El número %02d está repetido." % value}
        seen[value] = true
    return {"ok": true, "message": ""}
