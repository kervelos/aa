extends Node

const NORMAL_ROOT := "user://acierta"
const TEST_ROOT := "user://acierta_test"

var test_mode := false

func _ready() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument == "--acierta-test" or argument == "--acierta-test-reset":
            test_mode = true
    if test_mode and not OS.is_debug_build():
        push_error("ACIERTA: modo de prueba rechazado en compilación Release.")
        test_mode = false
    if test_mode and "--acierta-test-reset" in OS.get_cmdline_user_args():
        reset_test_root()
    DirAccess.make_dir_recursive_absolute(lotto_dir())

func root_dir() -> String:
    return TEST_ROOT if test_mode else NORMAL_ROOT

func games_dir() -> String:
    return root_dir() + "/games"

func lotto_dir() -> String:
    return games_dir() + "/lotto"

func lotto_file(filename: String) -> String:
    return lotto_dir() + "/" + filename

func reset_test_root() -> bool:
    if not test_mode or not OS.is_debug_build():
        return false
    if not DirAccess.dir_exists_absolute(TEST_ROOT):
        return true
    return _remove_tree(TEST_ROOT)

func _remove_tree(path: String) -> bool:
    var directory := DirAccess.open(path)
    if directory == null:
        return false
    for filename in directory.get_files():
        if DirAccess.remove_absolute(path + "/" + filename) != OK:
            return false
    for folder_name in directory.get_directories():
        if not _remove_tree(path + "/" + folder_name):
            return false
    return DirAccess.remove_absolute(path) == OK
