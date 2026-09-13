extends RefCounted
## One bounded capture job. No scene-tree or GPU access from the JPEG worker.
## Deferred callbacks retain this object even if the recorder/scene is freed.

signal completed(jpeg: PackedByteArray)
signal fallback_required

var _quality := 0.62
var _task_id := -1
var _jpeg := PackedByteArray()


func request(texture: RID, quality: float) -> void:
	_quality = quality
	RenderingServer.call_on_render_thread(_read_texture.bind(texture))


func _read_texture(texture: RID) -> void:
	var device := RenderingServer.get_rendering_device()
	if device == null or not device.has_method("texture_get_data_async"):
		_request_fallback.call_deferred()
		return
	var rd_texture := RenderingServer.texture_get_rd_texture(texture)
	if not rd_texture.is_valid() or not device.texture_is_valid(rd_texture):
		_request_fallback.call_deferred()
		return
	var format := device.texture_get_format(rd_texture)
	# A non-HDR SubViewport resolves to RGBA8. Other formats use Godot's Image
	# conversion path, rather than risking swapped channels or linear colours.
	if format.format not in [RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM, RenderingDevice.DATA_FORMAT_R8G8B8A8_SRGB] \
			or not (format.usage_bits & RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT):
		_request_fallback.call_deferred()
		return
	var error := device.texture_get_data_async(rd_texture, 0, _receive_pixels.bind(Vector2i(format.width, format.height)))
	if error != OK:
		_request_fallback.call_deferred()


func _receive_pixels(pixels: PackedByteArray, size: Vector2i) -> void:
	if pixels.size() != size.x * size.y * 4:
		_request_fallback.call_deferred()
		return
	_encode_pixels.call_deferred(pixels, size)


func _encode_pixels(pixels: PackedByteArray, size: Vector2i) -> void:
	var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, pixels)
	encode_image(image, _quality)


func encode_image(image: Image, quality: float) -> void:
	_task_id = WorkerThreadPool.add_task(_compress.bind(image, quality), false, "Tape JPEG")


func _compress(image: Image, quality: float) -> void:
	_jpeg = image.save_jpg_to_buffer(quality)
	_finish_encoding.call_deferred()


func _finish_encoding() -> void:
	# Compression has already finished before this callback is queued. Joining
	# releases the pool task; it never waits for GPU work on the main thread.
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
	completed.emit(_jpeg)


func _request_fallback() -> void:
	fallback_required.emit()
