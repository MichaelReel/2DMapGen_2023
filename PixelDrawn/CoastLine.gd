extends TextureRect
""" Try to draw some sort of southern coastline """

const SEA_COLOR := Color8(32, 32, 128, 255)
const COAST_COLOR := Color8(128, 128, 32, 255)
const RIVER_COLOR := Color8(128, 32, 32, 255)
const LAND_COLOR := Color8(32, 128, 32, 255)
const FRAME_DATA_TIME_MILLIS := 15  # Millis spent on each data update tick

var stages: Array
var stage_pos: int

onready var status_label := $RichTextLabel
onready var imageTexture := ImageTexture.new()


class Stage:
	var _cached_image: Image
	
	func status_text() -> String:
		return ""
	
	func update_data_tick(_return_after: float) -> void:
		pass
	
	func update_complete() -> bool:
		return true
	
	func update_image(image: Image) -> void:
		_cached_image = image.duplicate()
	
	func get_cached_stage_image() -> Image:
		return _cached_image
	
	static func draw_line_on_image(image: Image, a: Vector2, b: Vector2, col: Color) -> void:
		var longest_side = int(max(abs(a.x - b.x), abs(a.y - b.y))) + 1
		for p in range(longest_side):
			var t = (1.0 / longest_side) * p
			image.set_pixelv(lerp(a, b, t), col)

	static func get_off_center_point_between(a: Vector2, b: Vector2, rng: RandomNumberGenerator, spread: float) -> Vector2:
		var mid_point = lerp(a, b, 0.5)
		var tangent = (b - a).tangent()
		return mid_point + tangent * (rng.randf() - 0.5) * spread

	static func split_long_path_segments(path: PoolVector2Array, max_length: float, rng: RandomNumberGenerator, spread: float) -> PoolVector2Array:
		var max_length_squared = max_length * max_length
		var new_point_list := PoolVector2Array()
		for i in range(len(path) - 1):
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			new_point_list.append(a)
			if a.distance_squared_to(b) >= max_length_squared:
				new_point_list.append(get_off_center_point_between(a, b, rng, spread))
		
		# Re-add the final point and return
		new_point_list.append(path[len(path) - 1])
		return new_point_list

class SetupStage extends Stage:
	var _color: Color
	
	func _init(color: Color):
		_color = color
	
	func status_text() -> String:
		return "Setting up..."
	
	func update_image(image: Image) -> void:
		image.fill(_color)
		.update_image(image)


class CoastStage extends Stage:
	var _coast_points: PoolVector2Array
	var _color: Color
	var _rng: RandomNumberGenerator
	var _complete: bool
	var _segment_length: float
	var _spread: float

	func _init(screen_size: Vector2, color: Color, rng_seed: int) -> void:
		_coast_points = PoolVector2Array([
			Vector2(0.0, screen_size.y / 2.0),
			Vector2(screen_size.x, screen_size.y / 2.0),
		])
		_color = color
		_rng = RandomNumberGenerator.new()
		_rng.seed = rng_seed
		_segment_length = 7.0
		_spread = 0.5
	
	func status_text() -> String:
		return "Drawing coast..."
	
	func update_image(image: Image) -> void:
		image.lock()
		_draw_coast_segments_on_image(image, _color)
		image.unlock()
		.update_image(image)
	
	func update_data_tick(return_after: float) -> void:
		while OS.get_ticks_msec() < return_after and not _complete:
			var new_coast_points := split_long_path_segments(_coast_points, _segment_length, _rng, _spread)
			if len(new_coast_points) > len(_coast_points):
				_coast_points = new_coast_points
			else:
				_complete = true
	
	func update_complete() -> bool:
		return _complete

	func _draw_coast_segments_on_image(image: Image, color: Color) -> void:
		for i in range(len(_coast_points) - 1):
			var a = _coast_points[i]
			var b = _coast_points[i + 1]
			draw_line_on_image(image, a, b, color)
	
	func get_coast_points() -> PoolVector2Array:
		return _coast_points


class RiverComponentStage extends Stage:
	var _mouth: Vector2
	var _head: Vector2
	
	func _init(mouth: Vector2, head: Vector2) -> void:
		_mouth = mouth
		_head = head
	
	func draw_river_segments_on_image(image: Image, color: Color) -> void:
		# Temp
		draw_line_on_image(image, _mouth, _head, color)


class RiverStage extends Stage:
	var _coast_stage: CoastStage
	var _rivers: Array
	var _color: Color
	var _rng: RandomNumberGenerator
	var _started: bool
	var _complete: bool
	var _mouths: int
	var _mouth_variation: int
	var _head_variation: float
	
	func _init(coast_stage: CoastStage, color: Color, rng_seed: int, mouths: int) -> void:
		_coast_stage = coast_stage
		_rivers = []
		_color = color
		_rng = RandomNumberGenerator.new()
		_rng.seed = rng_seed
		_started = false
		_complete = false
		_mouths = mouths
		_mouth_variation = 10
		_head_variation = 10.0
	
	func update_data_tick(_return_after: float) -> void:
		if not _started:
			_setup_rivers()
			_started = true
		
		# Temp
		_complete = true
	
	func status_text() -> String:
		return "Drawing rivers..."
	
	func update_image(image: Image) -> void:
		image.lock()
		_draw_rivers_on_image(image, _color)
		image.unlock()
		.update_image(image)
	
	func _draw_rivers_on_image(image: Image, color: Color) -> void:
		for river in _rivers:
			river.draw_river_segments_on_image(image, color)
	
	func update_complete() -> bool:
		return _complete
	
	func _setup_rivers() -> void:
		var coast_points := _coast_stage.get_coast_points()
		var mouth_diff: int = len(coast_points) / (_mouths)
		for i in range(mouth_diff / 2, len(coast_points) - mouth_diff / 2, mouth_diff):
			var mouth = coast_points[i + _rng.randi_range(-_mouth_variation, _mouth_variation)]
			var head_rnd_offset = Vector2(
				_rng.randf_range(-_head_variation, _head_variation),
				_rng.randf_range(-_head_variation, _head_variation)
			)
			var head = Vector2(mouth.x, mouth.y * 0.25) + head_rnd_offset
			_rivers.append(RiverComponentStage.new(mouth, head))


func _ready() -> void:
	stage_pos = 0
	var base_rng := RandomNumberGenerator.new()
	base_rng.seed = OS.get_system_time_msecs()
	
	var background := SetupStage.new(SEA_COLOR)
	var coast_line := CoastStage.new(rect_size, COAST_COLOR, base_rng.randi())
	var rivers := RiverStage.new(coast_line, RIVER_COLOR, base_rng.randi(), 5)
	
	stages = [
		background,
		coast_line,
		rivers,
	]

func _process(_delta) -> void:
	# Create image or get last cached image
	var image: Image
	if stage_pos > 0:
		var previous_stage: Stage = stages[stage_pos - 1]
		image = previous_stage.get_cached_stage_image()
	else:
		image = Image.new()
		image.create(int(rect_size.x), int(rect_size.y), false, Image.FORMAT_RGBA8)
	
	# Play the current stage ontop of the previous image
	var current_stage: Stage = stages[stage_pos]
	status_label.bbcode_text = current_stage.status_text()
	var return_after: float = OS.get_ticks_msec() + FRAME_DATA_TIME_MILLIS
	current_stage.update_data_tick(return_after)
	current_stage.update_image(image)
	imageTexture.create_from_image(image)
	texture = imageTexture

	# Advance to the next stage if the current is complete and there are more stages
	if stage_pos < len(stages) - 1 and current_stage.update_complete(): 
		stage_pos += 1
