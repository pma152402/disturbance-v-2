extends "res://tools/build_school_upper_floor.gd"
func build() -> void:
	mat("Iron", Color(0.105,0.14,0.13), 0.65, 0.7)
	mat("Edge", Color(0.24,0.27,0.22), 0.6, 0.55)
	mat("Steel", Color(0.32,0.31,0.27), 0.75, 0.4)
	mat("Stone", Color(0.42,0.41,0.36), 0, 0.93)
	mat("Glass", Color(0.48,0.45,0.31,0.22), 0.05, 0.3)
	mats.Glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat("Bulb", Color(0.92,0.79,0.53), 0, 0.35)
	mats.Bulb.emission_enabled = true
	mats.Bulb.emission = Color(1,0.76,0.43)
	mats.Bulb.emission_energy_multiplier = 2.0
	new_asset("CourtyardStreetlamp")
	asset.set_meta("description", "Farola de patio de hierro envejecido; piezas editables y luz regulable.")
	solid(asset,"Stone",Vector3(0,0.055,0),Vector3(0.56,0.11,0.56))
	box(asset,"Iron",Vector3(0,0.135,0),Vector3(0.43,0.05,0.43))
	for x in [-0.16,0.16]:
		for z in [-0.16,0.16]:
			cyl(asset,"Steel",Vector3(x,0.171,z),0.028,0.024)
	for tier in [Vector3(0.19,0.08,0.21),Vector3(0.15,0.24,0.37),Vector3(0.18,0.05,0.515),Vector3(0.13,0.08,0.58)]:
		cyl(asset,"Iron",Vector3(0,tier.z,0),tier.x,tier.y)
	var shaft := CylinderMesh.new()
	shaft.bottom_radius = 0.10
	shaft.top_radius = 0.063
	shaft.height = 2.55
	shaft.radial_segments = 12
	append(asset,"Iron",shaft,Vector3(0,1.88,0),Vector3.ZERO)
	for i in range(8):
		var angle := i * TAU / 8
		cyl(asset,"Edge",Vector3(sin(angle)*0.088,1.1,cos(angle)*0.088),0.008,0.92)
	box(asset,"Iron",Vector3(0,0.98,0.103),Vector3(0.10,0.29,0.018))
	for y in [0.87,1.09]:
		cyl(asset,"Steel",Vector3(0,y,0.117),0.009,0.007,Vector3(PI/2,0,0))
	for y in [1.58,2.85,3.12]:
		cyl(asset,"Edge",Vector3(0,y,0),0.094,0.042)
	cyl(asset,"Iron",Vector3(0,3.19,0),0.145,0.13)
	box(asset,"Iron",Vector3(0,3.30,0),Vector3(0.53,0.09,0.53))
	box(asset,"Edge",Vector3(0,3.36,0),Vector3(0.48,0.035,0.48))
	for x in [-0.225,0.225]:
		for z in [-0.225,0.225]:
			box(asset,"Iron",Vector3(x,3.68,z),Vector3(0.034,0.65,0.034))
	for side in [-1,1]:
		box(asset,"Glass",Vector3(side*0.224,3.68,0),Vector3(0.008,0.58,0.40))
		box(asset,"Glass",Vector3(0,3.68,side*0.224),Vector3(0.40,0.58,0.008))
		box(asset,"Iron",Vector3(side*0.23,3.68,0),Vector3(0.022,0.018,0.44))
		box(asset,"Iron",Vector3(0,3.68,side*0.23),Vector3(0.44,0.018,0.022))
	box(asset,"Iron",Vector3(0,4.01,0),Vector3(0.56,0.075,0.56))
	var cap := CylinderMesh.new()
	cap.bottom_radius = 0.43
	cap.top_radius = 0.04
	cap.height = 0.23
	cap.radial_segments = 4
	append(asset,"Iron",cap,Vector3(0,4.16,0),Vector3(0,PI/4,0))
	cyl(asset,"Edge",Vector3(0,4.31,0),0.042,0.09)
	var finial := SphereMesh.new()
	finial.radius = 0.06
	finial.height = 0.12
	finial.radial_segments = 12
	finial.rings = 6
	append(asset,"Iron",finial,Vector3(0,4.4,0),Vector3.ZERO)
	cyl(asset,"Steel",Vector3(0,3.49,0),0.055,0.18)
	var bulb := child("Bulb",asset,"MeshInstance3D") as MeshInstance3D
	var globe := SphereMesh.new()
	globe.radius = 0.075
	globe.height = 0.23
	globe.radial_segments = 12
	globe.rings = 8
	bulb.mesh = globe
	bulb.material_override = mats.Bulb
	bulb.position.y = 3.67
	var lamp := child("WarmLight",asset,"OmniLight3D") as OmniLight3D
	lamp.position.y = 3.68
	lamp.light_color = Color(1,0.76,0.43)
	lamp.light_energy = 1.8
	lamp.omni_range = 8
	lamp.shadow_enabled = true
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 24
	lamp.distance_fade_length = 8
	# The cage must not cast a solid shadow that traps its own bulb light.
	for n in asset.find_children("*","MeshInstance3D",true,false):
		n.remove_meta("school_static_detail")
		if n.position.y > 3.34 and n.position.y < 4.0:
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	collision(asset,"PostCollision",Vector3(0,1.62,0),Vector3(0.22,3.1,0.22))
	collision(asset,"LanternCollision",Vector3(0,3.77,0),Vector3(0.56,1.0,0.56))
	save_scene("res://house_props/courtyard_streetlamp.tscn")
	quit()
