class_name LottoTestFixtures
extends RefCounted

static func make_draw(index: int) -> Dictionary:
    var lotto: Array[int] = []
    var revancha: Array[int] = []
    for offset in range(5):
        lotto.append((index * 3 + offset * 7) % 41)
        revancha.append((index * 5 + offset * 9 + 2) % 41)
    lotto.sort()
    revancha.sort()
    return {
        "date": "2026-01-%02d" % index,
        "draw_number": str(1000 + index),
        "profile_id": "lotto_cr",
        "lotto_enabled": true,
        "lotto": lotto,
        "revancha_enabled": true,
        "revancha": revancha
    }

static func make_draws(first: int, last: int) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for index in range(first, last + 1):
        result.append(make_draw(index))
    return result
