extends SceneTree

const NAMES := [
	"DarkroomMetalWorktable", "DarkroomPhotoEnlarger", "DarkroomDevelopingTrays",
	"DarkroomChemicalBottles", "DarkroomLoosePolaroid", "DarkroomClippedPhotoLine",
	"DarkroomPrintDryingRack", "DarkroomExposureTimer", "DarkroomWashingSink",
	"DarkroomFilmCanisters", "DarkroomRedCeilingLight"
]
const COMPONENTS := [
	"darkroom_metal_table.tscn", "darkroom_photo_enlarger.tscn", "darkroom_developing_trays.tscn",
	"darkroom_chemical_bottles.tscn", "darkroom_loose_polaroid.tscn", "darkroom_clipped_photo_line.tscn",
	"darkroom_print_drying_rack.tscn", "darkroom_exposure_timer.tscn", "darkroom_washing_sink.tscn",
	"darkroom_film_canisters.tscn", "darkroom_red_ceiling_light.tscn"
]


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://levels/house_baked.tscn") as PackedScene
	if packed == null: return _fail("No se pudo cargar house_baked")
	var house := packed.instantiate()
	root.add_child(house)
	await process_frame
	await process_frame
	for index in NAMES.size():
		var item_name: String = NAMES[index]
		var item := house.get_node_or_null(item_name)
		if item == null: return _fail("Falta %s" % item_name)
		if item.get_parent() != house or not item.get_meta("_edit_group_", false): return _fail("%s no es seleccionable independientemente" % item_name)
		if item.get_node_or_null("GeneratedDetail") == null: return _fail("%s no genero su detalle" % item_name)
		if item.find_children("GeneratedDetail", "Node3D", true, false).size() != 1: return _fail("%s tiene detalle visual duplicado" % item_name)
		if item.scene_file_path.get_file() != COMPONENTS[index]: return _fail("%s no tiene un componente propio" % item_name)
	var red := house.get_node_or_null("DarkroomRedCeilingLight/GeneratedDetail/RedDarkroomGlow") as OmniLight3D
	if red == null or red.light_color.r < .9 or red.light_color.g > .25: return _fail("La luz roja no esta configurada")
	print("OK: cuarto oscuro con 10 objetos independientes y luz roja funcional")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
