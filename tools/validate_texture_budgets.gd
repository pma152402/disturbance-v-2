extends SceneTree

const EXPECTED_LIMITS := {
	"res://assets/tv_videos/tv_bike.png": 512,
	"res://assets/tv_videos/tv_bread.png": 512,
	"res://assets/tv_videos/tv_bus_route.png": 512,
	"res://assets/tv_videos/tv_people_1.png": 512,
	"res://assets/tv_videos/tv_sea.png": 512,
	"res://assets/pictures/accolade.jpg": 1024,
	"res://assets/pictures/grandmother_and_child.jpg": 1024,
	"res://assets/ui/camera_damage/camera_cracks_hit_1_a.png": 1024,
	"res://assets/ui/camera_damage/camera_cracks_hit_1_more.png": 1024,
	"res://assets/ui/camera_damage/camera_cracks_hit_1_b.png": 1024,
	"res://assets/ui/camera_damage/camera_cracks_hit_2_a.png": 1024,
	"res://assets/ui/camera_damage/camera_cracks_hit_2_b.png": 1024,
	"res://assets/ui/camera_damage/camera_cracks_hit_3_fatal.png": 1024,
	"res://assets/ui/camera_damage/camera_cracks_hit_3_fatal_clear_center.png": 1024,
	"res://assets/ui/blood_damage/blood_damage_hit_1.png": 1024,
	"res://assets/ui/blood_damage/blood_damage_hit_2.png": 1024,
	"res://assets/ui/blood_damage/blood_damage_hit_3.png": 1024,
	"res://assets/textures/crochet_doily_transparent.png": 512,
}


func _init() -> void:
	var failed := false
	for path: String in EXPECTED_LIMITS:
		var texture := load(path) as Texture2D
		var limit := int(EXPECTED_LIMITS[path])
		if texture == null:
			push_error("Texture budget asset failed to load: %s" % path)
			failed = true
			continue
		var largest_side := maxi(texture.get_width(), texture.get_height())
		if largest_side > limit:
			push_error("Texture exceeds %d px after import: %s is %dx%d" % [limit, path, texture.get_width(), texture.get_height()])
			failed = true
		else:
			print("TEXTURE_BUDGET_OK %s %dx%d <= %d" % [path, texture.get_width(), texture.get_height(), limit])
	quit(1 if failed else 0)
