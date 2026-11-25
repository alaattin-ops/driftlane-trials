extends Control

const GAME_SCENE := "res://node_3d.tscn"
const STARTUP_RESOURCES := [
	GAME_SCENE, "res://DesertGarage.png", "res://BarlowCondensed-BoldItalic.ttf",
	"res://BarlowCondensed-SemiBold.ttf", "res://microcar.glb", "res://MeshyDesertSand2K.jpg"
]
var loaded: Dictionary = {}
var elapsed := 0.0
var completed_at := -1.0
@onready var bar: ProgressBar = $Meter


func _ready() -> void:
	for path in STARTUP_RESOURCES:
		if ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)


func _process(delta: float) -> void:
	elapsed += delta
	var total := 0.0
	for path in STARTUP_RESOURCES:
		if loaded.has(path):
			total += 1.0
			continue
		var progress := []
		match ResourceLoader.load_threaded_get_status(path, progress):
			ResourceLoader.THREAD_LOAD_LOADED:
				loaded[path] = ResourceLoader.load_threaded_get(path)
				total += 1.0
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				total += float(progress[0]) if not progress.is_empty() else 0.0
			_:
				total += 1.0
	var goal := total / STARTUP_RESOURCES.size() * 100.0
	bar.value = move_toward(bar.value, goal, 135.0 * delta)
	if bar.value >= 99.9:
		if completed_at < 0.0:
			completed_at = elapsed
			return
		if elapsed - completed_at >= 0.13:
			set_process(false)
			var scene := loaded.get(GAME_SCENE) as PackedScene
			if scene != null:
				get_tree().root.set_meta("driftlane_startup_resources", loaded)
				get_tree().change_scene_to_packed(scene)
			else:
				get_tree().change_scene_to_file(GAME_SCENE)
