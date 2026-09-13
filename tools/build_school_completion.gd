extends "res://tools/build_school_upper_floor.gd"

## Additive, editable extension. Never rebuild the previously furnished school.
const WEST := -33.6
const EAST := -30.15
const TOP := 8.4
const STOREYS := [0.0, 4.16, TOP]
var original_wall: ShaderMaterial

func build() -> void:
	_palette()
	new_asset("SchoolCompletion", false)
	asset.set_script(load("res://environment/school_upper_runtime.gd"))
	asset.set_meta("layout", "Three storeys; two separate staff rooms off each west stair corridor; auditorium, music and reading upstairs.")
	for index in 3:
		_staff_floor(index)
	_third_floor()
	_stairs()
	_close_stairwell()
	_finish_shell()
	# The old central balustrade leaves real clearance but rasterization erodes
	# the narrow turn. Join only the verified horizontal passage on that landing.
	var landing_link := child("OriginalStairLandingLink",asset,"NavigationLink3D") as NavigationLink3D
	landing_link.start_position = Vector3(-28.05,2.05,3.18)
	landing_link.end_position = Vector3(-28.95,2.05,3.18)
	landing_link.bidirectional = true
	landing_link.editor_description = "Paso real alrededor de la barandilla del descansillo original; conecta las dos orillas de la malla de navegacion."
	# Normal editor-owned geometry; the existing runtime script batches decoration.
	var packed := PackedScene.new()
	assert(packed.pack(asset) == OK)
	assert(ResourceSaver.save(packed, "res://environment/school_completion.tscn") == OK)
	asset.free()
	_integrate()
	print("SCHOOL COMPLETION BUILT: six staff rooms, third floor and enclosed stairwell")
	quit()

func _palette() -> void:
	mat("Paint", Color(0.2,0.29,0.27),0.25)
	mat("Frame", Color(0.20,0.18,0.13),0.15)
	mat("Steel", Color(0.48,0.49,0.45),0.7,0.4)
	mat("Rubber", Color(0.04,0.045,0.039))
	mat("Paper", Color(0.72,0.69,0.55))
	mat("Linen", Color(0.68,0.67,0.55))
	mat("Ceramic", Color(0.76,0.75,0.65),0,0.4)
	mat("Stone", Color(0.63,0.61,0.54))
	mat("Ceiling", Color(0.71,0.7,0.64))
	mat("Roof", Color(0.24,0.23,0.21))
	mat("Board", Color(0.05,0.10,0.08))
	mat("Curtain", Color(0.24,0.075,0.058))
	mat("Seat", Color(0.25,0.29,0.22))
	mat("Red", Color(0.39,0.12,0.09))
	mat("Blue", Color(0.18,0.28,0.32))
	mat("Yellow", Color(0.52,0.43,0.19))
	mat("Glass",Color(0.56,0.68,0.67,0.20),0,0.17)
	mats.Glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for key in ["Wood","Floor"]:
		mat(key, Color(0.49,0.36,0.21) if key == "Wood" else Color(0.64,0.62,0.54))
		mats[key].albedo_texture = load("res://ps2_house/Models/Abandoned_House_Madera4.jpg" if key == "Wood" else "res://ps2_house/Models/Abandoned_House_Piso2.jpg")
		mats[key].uv1_triplanar = true
		mats[key].uv1_scale = Vector3.ONE * (0.9 if key == "Wood" else 0.65)
	original_wall = ShaderMaterial.new()
	original_wall.shader = load("res://shaders/pastel_wall_band.gdshader")

func _wall_palette(base: float) -> void:
	var wall := original_wall.duplicate() as ShaderMaterial
	wall.set_shader_parameter("ground_band_top",base+1.38)
	wall.set_shader_parameter("upper_floor_start",base)
	wall.set_shader_parameter("upper_band_top",base+1.38)
	mats.Wall = wall

func _group(title: String, base: float) -> Node3D:
	var room := child(title, asset)
	room.position.y = base
	return room

func instance_asset(path: String, parent: Node3D, name_: String, p: Vector3, yaw: float = 0.0, size_: Vector3 = Vector3.ONE) -> Node3D:
	var node := super.instance_asset(path,parent,name_,p,yaw,size_)
	if path != "res://house_props/school_double_door.tscn": return node
	# Resize the panels in hinge space. Scaling the doorway itself stretches
	# rotating leaves into the room and makes the open doorway impassable.
	node.scale = Vector3.ONE
	node.scene_file_path = ""
	unpack_children(node)
	for part in node.get_children():
		part.position *= size_
		if part is AnimatableBody3D: part.panel_width *= size_.x
		for detail in part.get_children():
			if detail is Node3D:
				detail.position *= size_
				if detail is CollisionShape3D and detail.shape is BoxShape3D:
					detail.shape = detail.shape.duplicate()
					detail.shape.size *= size_
				else: detail.scale *= size_
	return node

func _slab(parent: Node3D, rect: Rect2, y: float, key: String = "Floor", thick: float = 0.16) -> void:
	var c := rect.get_center()
	solid(parent,key,Vector3(c.x,y-thick/2,c.y),Vector3(rect.size.x,thick,rect.size.y))

func _wall_x(parent: Node3D, a: float, b: float, z: float, bottom: float = 0.0, height: float = 4.0) -> void:
	if b-a < 0.01: return
	solid(parent,"Wall",Vector3((a+b)/2,bottom+height/2,z),Vector3(b-a,height,0.2))
	if bottom == 0.0:
		box(parent,"Frame",Vector3((a+b)/2,0.1,z),Vector3(b-a,0.2,0.24))

func _wall_z(parent: Node3D, x: float, a: float, b: float, bottom: float = 0.0, height: float = 4.0) -> void:
	if b-a < 0.01: return
	solid(parent,"Wall",Vector3(x,bottom+height/2,(a+b)/2),Vector3(0.2,height,b-a))
	if bottom == 0.0:
		box(parent,"Frame",Vector3(x,0.1,(a+b)/2),Vector3(0.24,0.2,b-a))

func _door_z(parent: Node3D, x: float, a: float, b: float, z: float, title: String, height: float) -> void:
	var half := 1.34*0.62
	_wall_z(parent,x,a,z-half,0,height)
	_wall_z(parent,x,z+half,b,0,height)
	_wall_z(parent,x,z-half,z+half,2.9,height-2.9)
	var door := instance_asset("res://house_props/school_double_door.tscn",parent,title+"Door",Vector3(x,0,z),PI/2,Vector3(0.62,1,1))
	door.set_meta("school_room_entrance",true)
	_sign(parent,title.to_upper(),Vector3(x+0.13,3.16,z),PI/2)

func portal_x(parent: Node3D, a: float, b: float, z: float, center: float, title: String) -> void:
	var half := 1.34*0.7
	_wall_x(parent,a,center-half,z,0,4.16)
	_wall_x(parent,center+half,b,z,0,4.16)
	_wall_x(parent,center-half,center+half,z,2.9,1.26)
	var north_room := title == "SALON DE ACTOS"
	instance_asset("res://house_props/school_double_door.tscn",parent,title+"Door",Vector3(center,0,z),0 if north_room else PI,Vector3(0.7,1,1))
	_sign(parent,title,Vector3(center,3.16,z+(0.13 if north_room else -0.13)),0 if north_room else PI)

func _sign(parent: Node3D, title: String, point: Vector3, yaw: float = 0.0) -> void:
	var sign_root := child("Sign"+str(parent.get_child_count()),parent)
	sign_root.position = point
	sign_root.rotation.y = yaw
	box(sign_root,"Frame",Vector3.ZERO,Vector3(1.65,0.3,0.035))
	label(sign_root,title,Vector3(0,0,0.024),0.0022)

func _window_z(parent: Node3D, x: float, a: float, b: float, height: float) -> void:
	_wall_z(parent,x,a,b,0,1.1)
	_wall_z(parent,x,a,b,2.9,height-2.9)
	solid(parent,"Glass",Vector3(x,2,(a+b)/2),Vector3(0.025,1.8,b-a))
	for z in [a+0.04,(a+b)/2,b-0.04]:
		box(parent,"Wood",Vector3(x,2,z),Vector3(0.14,1.8,0.06))
	for y in [1.12,2.0,2.88]:
		box(parent,"Wood",Vector3(x,y,(a+b)/2),Vector3(0.14,0.06,b-a))
	box(parent,"Stone",Vector3(x,1.08,(a+b)/2),Vector3(0.32,0.07,b-a+0.1))

func _fixture(parent: Node3D, point: Vector3, radius: float = 4.0) -> void:
	light(parent,point,0.75,radius)
	var fixture := parent.get_child(-1)
	var lamp := fixture.get_node("Light") as OmniLight3D
	lamp.shadow_enabled = false
	lamp.distance_fade_enabled = false

func _staff_floor(index: int) -> void:
	var base: float = STOREYS[index]
	var height: float = (STOREYS[index+1]-base) if index < 2 else 4.16
	_wall_palette(base)
	var names := [["Secretaria","Sala de profesores"],["Enfermeria","Reunion de profesores"],["Mantenimiento","Materiales y juegos"]]
	var floor_root := _group(["GroundStaffWing","MiddleStaffWing","TopStaffWing"][index],base)
	for room_index in 2:
		var room := child(["Secretariat","StaffRoom","Infirmary","MeetingRoom","Maintenance","GamesStorage"][index*2+room_index],floor_root)
		var north := -14.1 + room_index*5.6
		var south := north+5.6
		var door_z := -11.2 if room_index == 0 else -5.7
		room.set_meta("school_room",names[index][room_index])
		_slab(room,Rect2(WEST,north,EAST-WEST,5.6),0)
		# Meet the underside of the next slab, never duplicate its top surface.
		_slab(room,Rect2(WEST,north,EAST-WEST,5.6),height-(0.16 if index<2 else 0.0),"Ceiling",0.04 if index<2 else 0.16)
		_wall_x(room,WEST,EAST,north,0,height)
		if room_index == 1: _wall_x(room,WEST,EAST,south,0,height)
		_wall_z(room,WEST,north,north+1.0,0,height)
		_window_z(room,WEST,north+1.0,north+3.2,height)
		_wall_z(room,WEST,north+3.2,south,0,height)
		_door_z(room,EAST,north,south,door_z,names[index][room_index],height)
		_fixture(room,Vector3(-31.85,height-0.4,(north+south)/2))
		_furnish_staff(room,index,room_index,north)
	# Remaining corridor wall above/below the two openings replaces the old solid wall.
	_wall_z(floor_root,EAST,-17.39,-14.1,0,height)
	_wall_z(floor_root,EAST,-2.9,3.79,0,height)
	if index == 0:
		_slab(floor_root,Rect2(WEST-0.1,-14.2,EAST-WEST+0.2,11.4),-0.15,"Stone",0.65)

func _table(parent: Node3D, point: Vector3, width: float = 1.5, depth: float = 0.75, height: float = 0.78) -> Node3D:
	var table := child("Table"+str(parent.get_child_count()),parent,"StaticBody3D")
	table.position = point
	box(table,"Wood",Vector3(0,height,0),Vector3(width,0.08,depth))
	for x in [-width/2+0.09,width/2-0.09]:
		for z in [-depth/2+0.09,depth/2-0.09]:
			box(table,"Paint",Vector3(x,(height-0.04)/2,z),Vector3(0.055,height-0.04,0.055))
	collision(table,"Collision",Vector3(0,(height+0.02)/2,0),Vector3(width,height+0.02,depth))
	navigation_block(table,Rect2(-width/2,-depth/2,width,depth))
	return table

func _prop(parent: Node3D, file: String, name_: String, point: Vector3, yaw: float = 0.0) -> Node3D:
	return instance_asset("res://house_props/"+file+".tscn",parent,name_,point,yaw)

func _furnish_staff(room: Node3D, floor_index: int, room_index: int, north: float) -> void:
	if floor_index == 0 and room_index == 0:
		_table(room,Vector3(-31.95,0,north+1.05),1.65,0.75)
		_prop(room,"office_telephone","Telephone",Vector3(-31.6,0.83,north+1.05))
		_prop(room,"office_document_trays","RegistrationForms",Vector3(-32.35,0.83,north+1.05))
		_prop(room,"office_stamp_and_pad","AttendanceStamp",Vector3(-31.9,0.83,north+1.2))
		_prop(room,"office_visitor_chair","SecretaryChair",Vector3(-31.95,0,north+0.45),PI)
		_prop(room,"office_filing_cabinet","StudentRecords",Vector3(-33.1,0,north+4.15),PI/2)
		_prop(room,"office_notice_board","Timetable",Vector3(-31.5,2.1,north+0.12))
	elif floor_index <= 1 and room_index == 1:
		_table(room,Vector3(-32.65,0,north+2.6),0.9,1.65)
		for dz in [-1.22,1.22]:
			_prop(room,"office_visitor_chair","MeetingChair"+str(dz),Vector3(-32.65,0,north+2.6+dz),PI if dz<0 else 0)
		_prop(room,"office_bookcase_low","StaffBooks",Vector3(-31.95,0,north+5.1))
		_prop(room,"office_tea_cup","Tea",Vector3(-32.6,0.83,north+2.5))
		for i in 3:
			box(room,"Paper",Vector3(-32.45,0.827+i*0.008,north+2.85),Vector3(0.31,0.008,0.24),Vector3(0,i*0.09,0))
		_sign(room,"ACTAS / CLAUSTRO" if floor_index == 1 else "PERSONAL DOCENTE",Vector3(-31.8,2.2,north+0.12))
	elif floor_index == 1:
		var bed := child("ExaminationBed",room,"StaticBody3D")
		bed.position = Vector3(-32.65,0,north+1.7)
		box(bed,"Steel",Vector3(0,0.58,0),Vector3(0.9,0.08,2.1))
		box(bed,"Linen",Vector3(0,0.7,0),Vector3(0.85,0.18,2.0))
		box(bed,"Linen",Vector3(0,0.83,-0.68),Vector3(0.55,0.13,0.34))
		for x in [-0.34,0.34]:
			for z in [-0.8,0.8]: cyl(bed,"Steel",Vector3(x,0.29,z),0.035,0.58)
		collision(bed,"Collision",Vector3(0,0.4,0),Vector3(0.9,0.8,2.1))
		navigation_block(bed,Rect2(-0.45,-1.05,0.9,2.1))
		solid(room,"Ceramic",Vector3(-32.9,0.42,north+4.9),Vector3(0.95,0.84,0.65))
		box(room,"Steel",Vector3(-32.9,0.86,north+4.9),Vector3(0.72,0.045,0.45))
		cyl(room,"Steel",Vector3(-32.9,1.02,north+5.12),0.025,0.30)
		box(room,"Ceramic",Vector3(-31.25,1.85,north+0.22),Vector3(0.65,0.8,0.26))
		box(room,"Red",Vector3(-31.25,1.85,north+0.365),Vector3(0.32,0.07,0.012))
		box(room,"Red",Vector3(-31.25,1.85,north+0.365),Vector3(0.07,0.32,0.012))
		_prop(room,"office_visitor_chair","WaitingChair",Vector3(-31.1,0,north+5.05))
	elif room_index == 0:
		var bench := _table(room,Vector3(-33.02,0,north+2.0),0.8,2.4)
		bench.name = "MaintenanceWorkbench"
		box(room,"Board",Vector3(-32.5,1.7,north+0.12),Vector3(1.65,0.95,0.07))
		for i in 7:
			var tool_x := -33.12+i*0.2
			box(room,"Steel",Vector3(tool_x,1.78,north+0.18),Vector3(0.035,0.35+i%2*0.12,0.045))
			box(room,"Rubber",Vector3(tool_x,1.61,north+0.19),Vector3(0.055,0.18,0.06))
			if i%3==0: box(room,"Steel",Vector3(tool_x,1.96,north+0.19),Vector3(0.16,0.07,0.07))
		_prop(room,"office_wall_key_cabinet","ServiceKeys",Vector3(-31.3,1.9,north+0.14))
		_shelves(room,Vector3(-31.35,0,north+4.9),false)
		cyl(room,"Steel",Vector3(-32.85,0.25,north+4.8),0.22,0.5)
	else:
		_shelves(room,Vector3(-32.75,0,north+1.1),true)
		_shelves(room,Vector3(-32.75,0,north+4.6),true)
		for i in 3:
			solid(room,"Wood",Vector3(-33.05,0.2,north+2.3+i*0.6),Vector3(0.7,0.4,0.5))
		for i in 3:
			var ball := SphereMesh.new()
			ball.radius = 0.15
			ball.height = 0.3
			ball.radial_segments = 12
			ball.rings = 6
			append(room,["Red","Blue","Yellow"][i],ball,Vector3(-33.05,0.56,north+2.3+i*0.6),Vector3.ZERO)

func _shelves(parent: Node3D, point: Vector3, toys: bool) -> void:
	var shelf := child("GamesShelf" if toys else "SparePartsShelf",parent,"StaticBody3D")
	shelf.position = point
	for x in [-0.66,0.66]: box(shelf,"Paint",Vector3(x,1.03,0),Vector3(0.045,2.06,0.47))
	for y in [0.18,0.72,1.26,1.8]:
		box(shelf,"Wood",Vector3(0,y,0),Vector3(1.35,0.05,0.48))
		for i in 3:
			box(shelf,["Red","Blue","Yellow"][i] if toys else "Paper",Vector3(-0.43+i*0.43,y+0.14,0),Vector3(0.35,0.23,0.38))
	collision(shelf,"Collision",Vector3(0,1.03,0),Vector3(1.38,2.06,0.5))
	navigation_block(shelf,Rect2(-0.69,-0.25,1.38,0.5))

func _third_floor() -> void:
	_wall_palette(TOP)
	var hall := _group("ThirdFloorCorridor",TOP)
	var auditorium := _group("Auditorium",TOP)
	var music := _group("MusicRoom",TOP)
	var reading := _group("ReadingRoom",TOP)
	for entry in [[hall,Rect2(-30.15,-17.3,3.6,17.32)],[hall,Rect2(-26.55,-6.03,12.2,4.15)],[auditorium,Rect2(-26.55,-13.94,12.2,7.91)],[music,Rect2(-22.54,-1.88,3.54,6.98)],[reading,Rect2(-19,-1.88,3.96,6.98)]]:
		_slab(entry[0],entry[1],0)
		_slab(entry[0],entry[1],4.16,"Ceiling")
	_wall_x(hall,-30.15,-29.5,-17.3,0,4.16)
	_wall_x(hall,-27.2,-26.55,-17.3,0,4.16)
	_wall_x(hall,-29.5,-27.2,-17.3,0,1.1)
	_wall_x(hall,-29.5,-27.2,-17.3,2.9,1.26)
	solid(hall,"Glass",Vector3(-28.35,2,-17.3),Vector3(2.3,1.8,0.025))
	for x in [-29.46,-28.35,-27.24]: box(hall,"Wood",Vector3(x,2,-17.3),Vector3(0.06,1.8,0.14))
	for y in [1.12,2.0,2.88]: box(hall,"Wood",Vector3(-28.35,y,-17.3),Vector3(2.3,0.06,0.14))
	box(hall,"Stone",Vector3(-28.35,1.08,-17.3),Vector3(2.4,0.07,0.32))
	_wall_z(hall,-26.55,-17.3,-6.03,0,4.16)
	_wall_x(hall,-26.55,-22.54,-1.88,0,4.16)
	_wall_x(hall,-15.04,-14.35,-1.88,0,4.16)
	_wall_z(hall,-26.55,-1.88,0.02,0,4.16)
	_window_z(hall,-14.35,-6.03,-1.88,4.16)
	_wall_z(auditorium,-14.35,-13.94,-6.03,0,4.16)
	_wall_x(auditorium,-26.55,-14.35,-13.94,0,4.16)
	portal_x(auditorium,-26.55,-14.35,-6.03,-21.2,"SALON DE ACTOS")
	_wall_z(music,-22.54,-1.88,5.1,0,4.16)
	_wall_z(reading,-19,-1.88,5.1,0,4.16)
	_window_z(reading,-15.04,-1.88,5.1,4.16)
	for entry in [[music,-22.54,-19.0,-20.6,"MUSICA"],[reading,-19.0,-15.04,-16.8,"LECTURA"]]:
		portal_x(entry[0],entry[1],entry[2],-1.88,entry[3],entry[4])
		_wall_x(entry[0],entry[1],entry[2],5.1,0,4.16)
	for point in [Vector3(-28.35,3.7,-12.0),Vector3(-28.35,3.7,-3.0),Vector3(-20.5,3.7,-4.0)]: _fixture(hall,point,5.0)
	_sign(hall,"3 / ACTOS - MUSICA - LECTURA",Vector3(-28.3,3.2,-17.16))
	_furnish_auditorium(auditorium)
	_furnish_music(music)
	_furnish_reading(reading)

func _chair(parent: Node3D, point: Vector3, yaw: float = 0.0) -> void:
	var seat := child("AuditoriumSeat"+str(parent.get_child_count()),parent,"StaticBody3D")
	seat.position = point
	seat.rotation.y = yaw
	box(seat,"Seat",Vector3(0,0.47,0),Vector3(0.49,0.11,0.46))
	box(seat,"Seat",Vector3(0,0.82,0.22),Vector3(0.49,0.6,0.09))
	for x in [-0.21,0.21]:
		box(seat,"Wood",Vector3(x,0.3,0),Vector3(0.055,0.6,0.42))
		box(seat,"Wood",Vector3(x,0.67,0),Vector3(0.07,0.06,0.48))
	collision(seat,"Collision",Vector3(0,0.54,0),Vector3(0.52,1.08,0.54))
	navigation_block(seat,Rect2(-0.26,-0.27,0.52,0.54))

func _furnish_auditorium(room: Node3D) -> void:
	solid(room,"Wood",Vector3(-20.45,0.21,-12.86),Vector3(11.8,0.42,1.96))
	for i in 3:
		box(room,"Wood",Vector3(-15.75,0.07+i*0.14,-11.25-i*0.3),Vector3(1.1,0.14,0.3))
	_ramp(room,Vector3(-15.75,0,-11.0),Vector3(-15.75,0.42,-11.9),1.1)
	for row in 4:
		for x in [-24.9,-23.7,-22.5,-19.9,-18.7,-17.5]:
			_chair(room,Vector3(x,0,-10.6+row*1.2))
	for x in [-25.6,-15.25]:
		for i in 6:
			cyl(room,"Curtain",Vector3(x+i*0.1,2.03,-13.45),0.085,3.1)
	box(room,"Curtain",Vector3(-20.45,3.57,-13.45),Vector3(11.0,0.36,0.2))
	box(room,"Wood",Vector3(-20.5,0.97,-12.35),Vector3(0.6,1.1,0.5))
	box(room,"Wood",Vector3(-20.5,1.56,-12.35),Vector3(0.78,0.08,0.65),Vector3(-0.15,0,0))
	cyl(room,"Steel",Vector3(-20.3,1.79,-12.4),0.012,0.42)
	_sign(room,"COLEGIO / SALON DE ACTOS",Vector3(-20.45,2.8,-13.77))
	for x in [-24.0,-17.0]: _fixture(room,Vector3(x,3.7,-9.1),5.5)
	# Append after authored parts so their generated node names stay stable.
	var curtains := child("CurtainControls",room,"Node3D") as Node3D
	curtains.position = Vector3(-20.45,0,-13.45)
	curtains.set_script(preload("res://house_props/interactive_curtains.gd"))
	curtains.profile = 1
	curtains.source_parent = NodePath("..")
	curtains.curtain_width = 11.0
	curtains.bottom_height = 0.48
	curtains.top_height = 3.58
	curtains.transition_seconds = 1.8
	room.set_meta("school_room","Salon de actos")

func _furnish_music(room: Node3D) -> void:
	var piano := child("UprightPiano",room,"StaticBody3D")
	piano.position = Vector3(-20.8,0,4.55)
	box(piano,"Wood",Vector3(0,0.67,0),Vector3(2.15,1.34,0.55))
	box(piano,"Rubber",Vector3(0,0.79,-0.48),Vector3(2.08,0.12,0.48))
	for i in 28:
		box(piano,"Ceramic",Vector3(-0.95+i*0.07,0.865,-0.50),Vector3(0.065,0.025,0.4))
		if i%7 not in [2,6]: box(piano,"Rubber",Vector3(-0.915+i*0.07,0.889,-0.38),Vector3(0.036,0.04,0.2))
	collision(piano,"Collision",Vector3(0,0.7,-0.15),Vector3(2.15,1.4,0.85))
	navigation_block(piano,Rect2(-1.1,-0.6,2.2,0.9))
	_table(room,Vector3(-20.8,0,3.1),0.95,0.42,0.48)
	for z in [0.4,1.7]:
		_prop(room,"office_visitor_chair","MusicChair"+str(z),Vector3(-21.7,0,z),-PI/2)
		var stand := child("MusicStand"+str(z),room)
		stand.position = Vector3(-20.7,0,z)
		stand.rotation.y = -PI/2
		cyl(stand,"Steel",Vector3(0,0.66,0),0.018,1.32)
		cyl(stand,"Rubber",Vector3(0,0.025,0),0.16,0.05)
		box(stand,"Board",Vector3(0,1.34,0),Vector3(0.55,0.38,0.035),Vector3(-0.18,0,0))
	_fixture(room,Vector3(-20.7,3.7,1.6),4.5)
	room.set_meta("school_room","Aula de musica")

func _furnish_reading(room: Node3D) -> void:
	for z in [0.0,2.1,4.2]:
		_prop(room,"office_bookcase_oak","ReadingBooks"+str(z),Vector3(-18.55,0,z),PI/2)
	_table(room,Vector3(-16.9,0,1.6),1.05,1.4)
	for z in [0.45,2.75]: _prop(room,"office_visitor_chair","ReadingChair"+str(z),Vector3(-16.9,0,z),PI if z<1 else 0)
	box(room,"Paper",Vector3(-16.9,0.835,1.6),Vector3(0.42,0.03,0.3))
	_fixture(room,Vector3(-16.7,3.7,1.5),4.5)
	room.set_meta("school_room","Sala de lectura")

func _ramp(parent: Node3D, a: Vector3, b: Vector3, width: float) -> void:
	var side := Vector3.RIGHT*width/2
	var faces := PackedVector3Array([a-side,b-side,a+side,a+side,b-side,b+side])
	for i in range(0,faces.size(),3):
		if (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).y > 0.0:
			var swap := faces[i]
			faces[i] = faces[i+2]
			faces[i+2] = swap
	var body := child("ContinuousRamp"+str(parent.get_child_count()),parent,"StaticBody3D")
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var c := child("Collision",body,"CollisionShape3D") as CollisionShape3D
	c.shape = shape
	# Closed underside with side faces; no invisible hanging steps from below.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in [[a-side,b-side,a+side],[a+side,b-side,b+side]]:
		for p: Vector3 in triangle: st.add_vertex(p-Vector3.UP*0.18)
	for edge in [[a-side,b-side],[a+side,b+side],[a-side,a+side],[b-side,b+side]]:
		for p: Vector3 in [edge[0],edge[1],edge[0]-Vector3.UP*0.18,edge[1],edge[1]-Vector3.UP*0.18,edge[0]-Vector3.UP*0.18]: st.add_vertex(p)
	st.generate_normals()
	var mesh := child("StairSoffit",body,"MeshInstance3D") as MeshInstance3D
	mesh.mesh = st.commit()
	mesh.material_override = mats.Stone
	mesh.set_meta("school_static_detail",true)

func _rail(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var delta := b-a
	var node := child("Handrail"+str(parent.get_child_count()),parent,"StaticBody3D")
	node.position = (a+b)/2
	node.quaternion = Quaternion(Vector3.UP,delta.normalized())
	box(node,"Paint",Vector3.ZERO,Vector3(0.075,delta.length(),0.075))
	collision(node,"Collision",Vector3.ZERO,Vector3(0.075,delta.length(),0.075))

func _stairs() -> void:
	var stairs := _group("StairsToThirdFloor",4.16)
	# Balance the flight slopes below 42 degrees while keeping a broad landing.
	var mid := 2.34
	var flights := [[Vector3(-27.5,0,-0.38),Vector3(-27.5,mid,2.3)],[Vector3(-29.28,mid,2.3),Vector3(-29.28,TOP-4.16,0.1)]]
	for flight in flights:
		var a: Vector3 = flight[0]
		var b: Vector3 = flight[1]
		_ramp(stairs,a,b,1.62)
		for i in 14:
			var p := a.lerp(b,float(i+1)/14)
			p.z = lerpf(a.z,b.z,float(i+0.5)/14)
			box(stairs,"Stone",p-Vector3.UP*0.085,Vector3(1.62,0.17,absf(b.z-a.z)/14))
		for side in [-0.83,0.83]:
			_rail(stairs,a+Vector3(side,1.0,0),b+Vector3(side,1.0,0))
			for i in 8:
				var p := a.lerp(b,float(i)/7)+Vector3(side,0,0)
				_rail(stairs,p,p+Vector3.UP)
	_slab(stairs,Rect2(-30.15,2.3,3.6,1.48),mid,"Stone")
	_slab(stairs,Rect2(-30.15,-0.3,1.74,0.4),TOP-4.16,"Stone")
	_ramp(stairs,Vector3(-29.28,TOP-4.16,0.1),Vector3(-29.28,TOP-4.16,-0.3),1.62)
	_rail(stairs,Vector3(-28.36,TOP-4.16+1.0,0.05),Vector3(-26.65,TOP-4.16+1.0,0.05))
	for x in [-28.36,-27.8,-27.2,-26.65]: _rail(stairs,Vector3(x,TOP-4.16,0.05),Vector3(x,TOP-4.16+1,0.05))

func _close_stairwell() -> void:
	for index in 3:
		var base: float = STOREYS[index]
		var height: float = STOREYS[index+1]-base if index<2 else 4.16
		_wall_palette(base)
		var enclosure := _group("StairEnclosure"+str(index),base)
		_wall_z(enclosure,-26.55,-1.88 if index==0 else 0.02,3.79,0,height)
		if index > 1: _wall_x(enclosure,-30.15,-26.55,3.79,0,height)
		elif index == 1: _wall_x(enclosure,-30.15,-26.55,3.79,4.08,0.16)
		_fixture(enclosure,Vector3(-28.3,height-0.4,3.25),3.2)
		_sign(enclosure,["1 / SECRETARIA - PROFESORES","2 / ENFERMERIA - REUNIONES","3 / ACTOS - MUSICA - LECTURA"][index],Vector3(-28.2,2.9,3.67),PI)
		if index==2:
			_slab(enclosure,Rect2(-30.15,0.02,3.6,3.77),height,"Ceiling")

func _finish_shell() -> void:
	var geometry := preload("res://tools/school_shell_geometry.gd")
	# Match corners in the saved meshes and their collision boxes.
	geometry.stitch(asset)
	var footprint: Array[Rect2] = [Rect2(WEST,-14.1,EAST-WEST,11.2),Rect2(-30.15,-17.3,3.6,21.09),Rect2(-26.55,-13.94,12.2,12.06),Rect2(-22.54,-1.88,7.5,6.98)]
	var expanded: Array[Rect2] = []
	for rect in footprint: expanded.append(rect.grow(0.1))
	var rim := geometry.rect_union(expanded,footprint)
	var seams := _group("SlabEdgeClosures",0)
	# The street-facing ground corridor was outside the original upper slab.
	# Give it the same floor datum before sealing its vertical edges.
	_slab(seams,Rect2(-30.15,-17.58,3.6,4.38),0,"Floor",0.18)
	for rect in rim:
		_slab(seams,rect,4.16,"Ceiling",0.24)
		_slab(seams,rect,8.4,"Ceiling",0.24)
		_slab(seams,rect,12.56,"Ceiling",0.16)
	var roof := _group("ContinuousRoof",0)
	expanded.clear()
	for rect in footprint: expanded.append(rect.grow(0.12))
	for rect in geometry.rect_union(expanded): _slab(roof,rect,12.69,"Roof",0.13)
	_wall_palette(4.16)
	var middle := _group("MiddleCorridorEndClosure",4.16)
	_wall_x(middle,-15.04,-14.35,-1.88,0,4.0)

func _remove_nodes(text: String, paths: Array[String]) -> String:
	var lines := text.split("\n")
	var output := PackedStringArray()
	var skip := false
	var regex := RegEx.new()
	regex.compile('^\\[node name="([^"]+)".*? parent="([^"]+)"')
	for line in lines:
		if line.begins_with("["):
			skip = false
			var found := regex.search(line)
			if found:
				var path := found.get_string(1) if found.get_string(2)=="." else found.get_string(2)+"/"+found.get_string(1)
				for removed in paths:
					if path==removed or path.begins_with(removed+"/"): skip = true
		if not skip: output.append(line)
	return "\n".join(output)

func _integrate() -> void:
	_fix_existing_stair_winding()
	var house_path := "res://levels/house_baked.tscn"
	var text := FileAccess.get_file_as_string(house_path)
	text = _remove_nodes(text,["BranchWestWall","NewFrontHouseDecor/BalconyBalustradeSample12","BranchEastSouthWall","GroundFloor/ExteriorWalls/WindowLowerWallBaseboard_10","GroundFloor/ReceptionAndHall/WallBaseboard7"])
	if not 'id="school_completion"' in text:
		text = text.insert(text.find("[ext_resource "),'[ext_resource type="PackedScene" path="res://environment/school_completion.tscn" id="school_completion"]\n')
		var at := text.find("[connection ")
		text = text.insert(at if at>=0 else text.length(),'[node name="SchoolCompletion" parent="." instance=ExtResource("school_completion")]\n\n')
	FileAccess.open(house_path,FileAccess.WRITE).store_string(text)
	var upper_path := "res://environment/school_upper_floor.tscn"
	text = FileAccess.get_file_as_string(upper_path)
	text = _remove_nodes(text,["ExteriorAndPartitions/WallSolid0","ExteriorAndPartitions/FramePart1","UpperCorridor/StairLandingGuard"])
	FileAccess.open(upper_path,FileAccess.WRITE).store_string(text)
	load("res://tools/align_school_shell.gd").new().run()

func _fix_existing_stair_winding() -> void:
	# Godot renders/bakes clockwise front faces. Backface-enabled old collision
	# ramps worked for players, but their upward side was absent from NPC paths.
	var path := "res://geometry/corridor_stair_ramps.tscn"
	var text := FileAccess.get_file_as_string(path)
	var regex := RegEx.new()
	regex.compile("PackedVector3Array\\(([^)]+)\\)")
	for match_ in regex.search_all(text):
		var values := match_.get_string(1).split(", ")
		var changed := false
		for i in range(0,values.size(),9):
			var a := Vector3(float(values[i]),float(values[i+1]),float(values[i+2]))
			var b := Vector3(float(values[i+3]),float(values[i+4]),float(values[i+5]))
			var c := Vector3(float(values[i+6]),float(values[i+7]),float(values[i+8]))
			if (b-a).cross(c-a).y <= 0: continue
			changed = true
			for j in 3:
				var tmp := values[i+j]
				values[i+j] = values[i+6+j]
				values[i+6+j] = tmp
		if changed: text = text.replace(match_.get_string(),"PackedVector3Array("+", ".join(values)+")")
	FileAccess.open(path,FileAccess.WRITE).store_string(text)
