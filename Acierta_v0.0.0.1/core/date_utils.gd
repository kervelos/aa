class_name DateUtils
extends RefCounted

static func normalize_date(text: String) -> String:
    var value := text.strip_edges()
    if value.is_empty():
        return ""
    if value.contains("/"):
        var p := value.split("/")
        if p.size() != 3:
            return ""
        var day := int(p[0])
        var month := int(p[1])
        var year := int(p[2])
        if not _valid_date(year, month, day):
            return ""
        return "%04d-%02d-%02d" % [year, month, day]
    if value.contains("-"):
        var p := value.split("-")
        if p.size() != 3:
            return ""
        var year := int(p[0])
        var month := int(p[1])
        var day := int(p[2])
        if not _valid_date(year, month, day):
            return ""
        return "%04d-%02d-%02d" % [year, month, day]
    return ""

static func today() -> String:
    return Time.get_date_string_from_system()

static func display(iso_date: String) -> String:
    var n := normalize_date(iso_date)
    if n.is_empty():
        return iso_date
    var p := n.split("-")
    return "%s/%s/%s" % [p[2], p[1], p[0]]

static func _valid_date(year: int, month: int, day: int) -> bool:
    if year < 1900 or year > 2200 or month < 1 or month > 12 or day < 1:
        return false
    var days := [31, 28 + (1 if _is_leap(year) else 0), 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    return day <= days[month - 1]

static func _is_leap(year: int) -> bool:
    return year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)
