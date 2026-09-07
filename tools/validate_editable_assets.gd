extends SceneTree

const ASSETS := {
	"BlackFicus": "res://house_props/black_ficus_editable.tscn",
	"TurbineRoofVent": "res://house_props/turbine_roof_vent_editable.tscn",
	"HVACUnit": "res://house_props/hvac_unit_editable.tscn",
}


func _initialize() -> void:
	for asset_name in ASSETS:
		var packed := load(ASSETS[asset_name]) as PackedScene
		if packed == null:
			return _fail("No se pudo cargar %s" % asset_name)
		var asset := packed.instantiate()
		if asset.get_script() != null:
			return _fail("%s conserva un script generador" % asset_name)
		var detail := asset.get_node_or_null("GeneratedDetail")
		if detail == null or detail.get_child_count() < 5:
			return _fail("%s no contiene piezas editables" % asset_name)
	var house := (load("res://levels/house_baked.tscn") as PackedScene).instantiate()
	for node_name in ["BlackFicus", "TurbineRoofVent", "OldHVACUnit", "OldHVACUnit2"]:
		var node := house.get_node_or_null(node_name)
		if node == null or node.get_script() != null:
			return _fail("La instancia %s falta o aún usa script" % node_name)
	print("OK: Ficus, turbina y dos HVAC enlazados a escenas editables sin script")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
