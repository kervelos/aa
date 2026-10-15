extends Node

var passed := 0
var failed := 0
var failures: Array[String] = []

func _ready() -> void:
    if not AppPaths.test_mode:
        push_error("Ejecute con -- --acierta-test-reset")
        get_tree().quit(2)
        return
    await get_tree().process_frame
    _run()

func _run() -> void:
    _check("01 base vacía", Database.get_all_draws().size() == 0)
    _check("02 un modelo activo", not ModelRegistry.get_active_model().is_empty())

    var batch := Database.add_draws_batch(LottoTestFixtures.make_draws(1, 12))
    _check("03 importar 12", batch.get("ok", false))
    _check("04 draw_count 12", Database.get_all_draws().size() == 12)
    _check("05 database_version 1", Database.get_database_version() == 1)

    var generator := CombinationGenerator.new(GameProfile.lotto_costa_rica())
    _check("06 aplicar modelo", generator.apply_model(ModelRegistry.get_active_model()).get("ok", false))
    var generation := generator.generate(Database.get_all_draws(), StatisticsEngine.AnalysisSource.LOTTO_ONLY, 250, 17041)
    _check("07 generar con 12", generation.get("ok", false))
    _check("08 top10", generation.get("top_10", []).size() == 10)

    var saved := PredictionStore.save_generation(PredictionStore.MODE_PRETRAINING, generation, "2026-01-13", "1013", "lotto")
    _check("09 guardar TEST13", saved.get("ok", false))
    var pid := str(saved.get("prediction", {}).get("prediction_id", ""))
    var best_numbers: Array = saved.get("prediction", {}).get("best", {}).get("numbers", [])
    var feedback := [{"display_rank": 1, "hits": [best_numbers[0], best_numbers[1]], "hit_count": 2}]
    _check("10 feedback previo", FeedbackStore.save_feedback(pid, feedback).get("ok", false))

    _check("11 cargar resultado13", Database.add_draw(LottoTestFixtures.make_draw(13)).get("ok", false))
    EvaluationStore.reconcile_all()
    var evaluation := EvaluationStore.get_evaluation_for_prediction(pid)
    _check("12 evaluación automática", not evaluation.is_empty())
    _check("13 feedback posterior bloqueado", not FeedbackStore.can_edit_feedback(pid).get("ok", true))

    var eval_count := EvaluationStore.get_all_evaluations().size()
    for _i in range(10):
        EvaluationStore.reconcile_all()
    _check("14 reconcile x10 no duplica", EvaluationStore.get_all_evaluations().size() == eval_count)

    var old_eval_id := str(evaluation.get("evaluation_id", ""))
    var old_eval_revision := int(evaluation.get("revision", 1))
    var draw13 := Database.get_draw_by_identity("2026-01-13", "1013")
    var corrected := draw13.duplicate(true)
    var replacement := 40
    while replacement in corrected["lotto"]:
        replacement -= 1
    corrected["lotto"][0] = replacement
    corrected["lotto"].sort()
    _check("15 corregir objetivo", Database.update_draw(str(draw13.get("record_id", "")), corrected).get("ok", false))
    EvaluationStore.reconcile_all()
    var evaluation2 := EvaluationStore.get_evaluation_for_prediction(pid)
    _check("16 mismo evaluation_id", str(evaluation2.get("evaluation_id", "")) == old_eval_id)
    _check("17 revisión evaluación sube", int(evaluation2.get("revision", 0)) == old_eval_revision + 1)

    var path := AppPaths.lotto_file("results.json")
    var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
    if file != null:
        file.store_string("{ JSON CORTADO ")
        file.flush()
        file.close()
    _check("18 tmp corrupto no rompe", Database.reload_for_tests())
    _check("19 principal preservado", Database.get_all_draws().size() == 13)

    var raw := JsonFileStore.read_dictionary(path)
    if raw.get("ok", false):
        var future := raw["data"].duplicate(true)
        future["recovery_marker"] = "OK"
        _check("20 crear tmp válido interrumpido", JsonFileStore.write_interrupted_temp_for_test(path, future).get("ok", false))
        _check("21 recargar desde tmp válido", Database.reload_for_tests())
        var recovered := JsonFileStore.read_dictionary(path)
        _check("22 tmp válido recuperado", recovered.get("ok", false) and str(recovered["data"].get("recovery_marker", "")) == "OK")

    var audit := ProjectAudit.run()
    _check("23 revisión austera", audit.get("ok", false), str(audit.get("errors", [])))

    print("ACIERTA SMOKE: PASS=%d FAIL=%d" % [passed, failed])
    for item in failures:
        print("FAIL: ", item)
    get_tree().quit(0 if failed == 0 else 1)

func _check(name: String, condition: bool, detail: String = "") -> void:
    if condition:
        passed += 1
        print("PASS: ", name)
    else:
        failed += 1
        failures.append(name + (" · " + detail if not detail.is_empty() else ""))
