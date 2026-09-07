extends SceneTree

const EXPECTED_PRELOADED := [
	"res://player/player.tscn",
	"res://boiler_minigame.tscn",
	"res://washing_machine_minigame.tscn",
	"res://boarded_door_minigame.tscn",
	"res://skill_check_minigame.tscn",
	"res://thrown_can.tscn",
	"res://thrown_bottle.tscn",
]


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	change_scene_to_file("res://startup_loader.tscn")
	for _frame in 900:
		await process_frame
		if current_scene != null and current_scene.name == &"ThreeStoreyHouse" \
			and current_scene.get_node_or_null("StartupWarmup") == null:
			break
	if current_scene == null or current_scene.name != &"ThreeStoreyHouse":
		push_error("La carga inicial no llegó a la escena del juego")
		quit(1)
		return
	if current_scene.get_node_or_null("StartupWarmup") != null:
		push_error("La preparación inicial no terminó")
		quit(1)
		return
	var navigation := current_scene.get_node("RuntimeHouseNavigation") as NavigationRegion3D
	var player := current_scene.get_node("Player") as CharacterBody3D
	if navigation.navigation_mesh == null or not player.is_physics_processing():
		push_error("Se entregó el control antes de terminar la navegación")
		quit(1)
		return
	for path in EXPECTED_PRELOADED:
		# El cargador ya no precarga recursos: abre test.tscn directamente para
		# no mantener duplicados en memoria. Validamos que sus dependencias sigan
		# disponibles sin asumir una API retirada de startup_loader.gd.
		if not ResourceLoader.exists(path):
			push_error("Recurso de juego no encontrado: " + path)
			quit(1)
			return
	if ResourceLoader.has_cached("res://church_catacombs.tscn"):
		push_error("El laberinto final se cargó antes de su minijuego")
		quit(1)
		return
	print("STARTUP OK: escena y dependencias disponibles; laberinto diferido")
	quit(0)
