extends TextureRect

onready var image := Image.new()
onready var imageTexture := ImageTexture.new()

const SEA_COLOR := Color8(32, 32, 128, 255)
const COAST_COLOR := Color8(128, 128, 32, 255)
const RIVER_COLOR := Color8(128, 32, 32, 255)
const LAND_COLOR := Color8(32, 128, 32, 255)

func _ready() -> void:
	image.create(int(rect_size.x), int(rect_size.y), false, Image.FORMAT_RGBA8)

func _process(_delta) -> void:
	image.fill(SEA_COLOR)
	imageTexture.create_from_image(image)
	texture = imageTexture
