extends TextureRect


const _SPACE: Color = Color.LIGHT_STEEL_BLUE
const _WALL: Color = Color.INDIGO
const _STEP_RATE: float = 0.01

@export var step_max: int = 10
@export var moore_threshold: int = 4
@export var density: float = 0.6

@onready var step: int = 0
@onready var step_limiter: float = _STEP_RATE
@onready var rng := RandomNumberGenerator.new()

var image: Image

func _ready():
	rng.seed = int(Time.get_unix_time_from_system() * 1000)

func _process(delta):
	if step > step_max:
		return
	
	if step == 0:
		# Create initial image
		image = _get_initial_random_image()
		print(image)
		texture = ImageTexture.create_from_image(image)
		step += 1
		step_limiter = _STEP_RATE
	
	if step_limiter < 0.0:
		# Perform cellular automaton step
		image = _get_cellular_automaton_step(image)
		print(image)
		texture = ImageTexture.create_from_image(image)
		step_limiter = _STEP_RATE
		step += 1
	else:
		step_limiter -= delta

func _get_cellular_automaton_step(input_image: Image) -> Image:
	var width := int(input_image.get_size().x)
	var height := int(input_image.get_size().y)
	var output_image := Image.create(width, height, false, image.get_format())
	for y in range(height):
		for x in range(width):
			var moore_number : int = _get_moore_neighbour(input_image, x, y)
			output_image.set_pixel(x, y, _WALL if moore_number > moore_threshold else _SPACE)
	
	return output_image

func _get_moore_neighbour(input_image: Image, x: int, y: int) -> int:
	var neighbour_wall_count: int = 0
	for k in range(y - 1, y + 2):
		for j in range(x - 1, x + 2):
			if j == x and k == y:
				continue
			if j < 0 or j >= image.get_size().x or k < 0 or k >= image.get_size().y:
				neighbour_wall_count += 1
				continue
			if input_image.get_pixel(j, k) == _WALL:
				neighbour_wall_count += 1
	return neighbour_wall_count
	

func _get_initial_random_image() -> Image:
	var width := int(size.x)
	var height := int(size.y)
	var init_image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			init_image.set_pixel(x, y, _SPACE if rng.randf_range(0.0, 1.0) >= density else _WALL)
	return init_image
