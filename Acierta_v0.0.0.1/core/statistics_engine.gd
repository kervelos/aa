class_name StatisticsEngine
extends RefCounted

enum AnalysisSource { LOTTO_ONLY, REVANCHA_ONLY, BOTH }

static func extract_samples(draws: Array, source: int) -> Array[Dictionary]:
    var sorted := draws.duplicate(true)
    sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if str(a.get("date", "")) == str(b.get("date", "")):
            return str(a.get("draw_number", "")) < str(b.get("draw_number", ""))
        return str(a.get("date", "")) < str(b.get("date", ""))
    )
    var samples: Array[Dictionary] = []
    for draw in sorted:
        if (source == AnalysisSource.LOTTO_ONLY or source == AnalysisSource.BOTH) and bool(draw.get("lotto_enabled", false)):
            samples.append({"record_id": draw.get("record_id", ""), "date": draw.get("date", ""), "draw_number": draw.get("draw_number", ""), "type": "lotto", "numbers": draw.get("lotto", []).duplicate()})
        if (source == AnalysisSource.REVANCHA_ONLY or source == AnalysisSource.BOTH) and bool(draw.get("revancha_enabled", false)):
            samples.append({"record_id": draw.get("record_id", ""), "date": draw.get("date", ""), "draw_number": draw.get("draw_number", ""), "type": "revancha", "numbers": draw.get("revancha", []).duplicate()})
    return samples

static func analyze(draws: Array, source: int, profile: GameProfile = null) -> Dictionary:
    if profile == null:
        profile = GameProfile.lotto_costa_rica()
    var samples := extract_samples(draws, source)
    var total_samples := samples.size()
    var frequency := {}
    var recent_frequency := {}
    var absence := {}
    var pair_frequency := {}
    var trio_frequency := {}
    var monthly_frequency := {}
    var sum_values: Array[float] = []
    var span_values: Array[float] = []
    var even_values: Array[float] = []
    var low_values: Array[float] = []
    var consecutive_values: Array[float] = []
    for n in range(profile.min_number, profile.max_number + 1):
        frequency[n] = 0
        recent_frequency[n] = 0
        absence[n] = total_samples
    for i in range(total_samples):
        var numbers: Array = samples[i]["numbers"].duplicate()
        numbers.sort()
        var month := str(samples[i].get("date", "")).substr(5, 2)
        if not monthly_frequency.has(month):
            monthly_frequency[month] = {}
        for raw in numbers:
            var n := int(raw)
            frequency[n] = int(frequency.get(n, 0)) + 1
            monthly_frequency[month][n] = int(monthly_frequency[month].get(n, 0)) + 1
            absence[n] = total_samples - 1 - i
        for a in range(numbers.size()):
            for b in range(a + 1, numbers.size()):
                var pk := "%02d-%02d" % [int(numbers[a]), int(numbers[b])]
                pair_frequency[pk] = int(pair_frequency.get(pk, 0)) + 1
                for c in range(b + 1, numbers.size()):
                    var tk := "%02d-%02d-%02d" % [int(numbers[a]), int(numbers[b]), int(numbers[c])]
                    trio_frequency[tk] = int(trio_frequency.get(tk, 0)) + 1
        var total := 0
        var evens := 0
        var lows := 0
        var consecutive := 0
        for j in range(numbers.size()):
            total += int(numbers[j])
            if int(numbers[j]) % 2 == 0:
                evens += 1
            if int(numbers[j]) <= 20:
                lows += 1
            if j > 0 and int(numbers[j]) == int(numbers[j - 1]) + 1:
                consecutive += 1
        sum_values.append(float(total))
        span_values.append(float(int(numbers[-1]) - int(numbers[0])) if not numbers.is_empty() else 0.0)
        even_values.append(float(evens))
        low_values.append(float(lows))
        consecutive_values.append(float(consecutive))
    var recent_count := min(10, total_samples)
    for i in range(max(0, total_samples - recent_count), total_samples):
        for raw in samples[i]["numbers"]:
            var n := int(raw)
            recent_frequency[n] = int(recent_frequency.get(n, 0)) + 1
    return {
        "sample_count": total_samples,
        "frequency": frequency,
        "recent_frequency": recent_frequency,
        "absence": absence,
        "pairs": pair_frequency,
        "trios": trio_frequency,
        "monthly": monthly_frequency,
        "shape": {
            "avg_sum": _avg(sum_values),
            "avg_span": _avg(span_values),
            "avg_even": _avg(even_values),
            "avg_low": _avg(low_values),
            "avg_consecutive": _avg(consecutive_values)
        }
    }

static func same_draw_overlap(draws: Array) -> Dictionary:
    var counts := {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
    var total := 0
    for draw in draws:
        if not bool(draw.get("lotto_enabled", false)) or not bool(draw.get("revancha_enabled", false)):
            continue
        total += 1
        var hits := 0
        for n in draw.get("lotto", []):
            if int(n) in draw.get("revancha", []):
                hits += 1
        counts[hits] = int(counts.get(hits, 0)) + 1
    return {"events": total, "overlap_counts": counts}

static func _avg(values: Array[float]) -> float:
    if values.is_empty():
        return 0.0
    var s := 0.0
    for v in values:
        s += v
    return s / values.size()
