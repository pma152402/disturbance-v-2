extends Node3D

## Solo la geometria plegada: un RigidBody3D en la mano recibe correcciones
## del motor fisico y puede separarse del agarre al mover el rig.


func _ready() -> void:
	var source := preload("res://house_props/camera_tripod.tscn").instantiate()
	var rig := source.get_node("TripodRig") as Node3D
	var mounted_camera := rig.get_node("CenterAssembly/PanHead/CameraPlate/MountedCameraVisual")
	mounted_camera.free()
	var grip := source.get_node("CarryGrip") as Node3D
	for node: Node in source.find_children("*", "Node", true, false):
		node.owner = null
	source.remove_child(rig)
	source.remove_child(grip)
	add_child(rig)
	add_child(grip)
	source.free()
	for mesh: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
