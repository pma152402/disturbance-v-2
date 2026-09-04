extends SceneTree

const MIN := Vector3(-34.0, -1.0, -20.0)
const MAX := Vector3(-10.0, 6.0, 16.0)

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var house := (load("res://house_baked.tscn") as PackedScene).instantiate()
    house.set_script(null)
    root.add_child(house)
    for body in house.find_children("*", "StaticBody3D", true, false):
        var bounds := AABB()
        var has_bounds := false
        for mesh in body.find_children("*", "MeshInstance3D", true, false):
            var mesh_bounds := mesh.global_transform * mesh.get_aabb()
            if not has_bounds:
                bounds = mesh_bounds
                has_bounds = true
            else:
                bounds = bounds.merge(mesh_bounds)
        if has_bounds and bounds.intersects(AABB(MIN, MAX - MIN)):
            print(str(house.get_path_to(body)), " | ", bounds)
    house.free()
    quit()
