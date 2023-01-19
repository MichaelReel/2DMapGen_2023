extends TextureRect

# Max CELL_EDGE <= min(rect_size.x * (2 / 3), rect_size.y * sqrt(16/27))
# Max for (1024, 600) <= min(682.666666667, 461.880215352)
const CELL_EDGE := 12.0
const SEA_COLOR := Color8(32, 32, 64, 255)
const BASE_COLOR := SEA_COLOR
const GRID_COLOR := Color8(40, 40, 96, 255)
const COAST_COLOR := Color8(128, 128, 32, 255)
const LAKE_COLOR := SEA_COLOR
const RIVER_COLOR := Color8(128, 32, 32, 255) 
const LAND_COLOR := Color8(32, 128, 32, 255)
const CURSOR_COLOR := Color8(128, 32, 128, 255)
const RIVER_COUNT := 8

const REGION_COLORS := [
	Color8(  0,   0, 192, 255),
	Color8(  0, 192,   0, 255),
	Color8(192,   0,   0, 255),
	Color8(  0, 192, 192, 255),
	Color8(192, 192,   0, 255),
	Color8(192,   0, 192, 255),
]

const SUB_REGION_COLORS := [
	Color8(192, 128,  64, 255),
	Color8( 64, 192, 128, 255),
	Color8(128,  64, 192, 255),
]

const FRAME_DATA_TIME_MILLIS := 15  # Millis spent on each data update tick
const SLOPE := sqrt(1.0 / 3.0)

var stages: Array
var stage_pos: int

onready var status_label := $RichTextLabel
onready var imageTexture := ImageTexture.new()

class BasePoint:
	var _pos: Vector2
	var _connections: Array
	var _polygons: Array
	var _height_color_scale: float = 1.0 / 10.0
	var _height_set: bool = false
	var _height: float
	
	func _init(x: float, y: float) -> void:
		_pos = Vector2(x, y)
		_connections = []
		
	func add_connection(line: BaseLine) -> void:
		_connections.append(line)
	
	func add_polygon(polygon: BaseTriangle) -> void:
		if not polygon in _polygons:
			_polygons.append(polygon)
	
	static func sort_vert_inv_hortz(a: BasePoint, b: BasePoint) -> bool:
		"""This will sort by Y desc, then X asc"""
		if a._pos.y > b._pos.y:
			return true
		elif a._pos.y == b._pos.y and a._pos.x < b._pos.x:
				return true
		return false
	
	func equals(other: BasePoint) -> bool:
		return self._pos == other._pos
	
	func higher_connections() -> Array:
		# Return connection lines to "higher" points
		var higher_conns = []
		for con in _connections:
			var other = con.other_point(self)
			if sort_vert_inv_hortz(self, other):
				higher_conns.append(con)
		return higher_conns
	
	func higher_connections_to_point(point) -> Array:
		# Return connection lines to "higher" points that connect to a given point
		var higher_conns = []
		for con in _connections:
			var other = con.other_point(self)
			if sort_vert_inv_hortz(self, other):
				if other.has_connection_to_point(point):
					higher_conns.append(con)
		return higher_conns
	
	func has_connection_to_point(point) -> bool:
		for con in _connections:
			if con.other_point(self) == point:
				return true
		return false
	
	func connection_to_point(point) -> BaseLine:
		for con in _connections:
			if con.other_point(self) == point:
				return con
		return BaseLine.error()
	
	func error() -> BasePoint:
		printerr("Something needed a placeholder BasePoint")
		return BasePoint.new(0.0, 0.0)
	
	func get_pos() -> Vector2:
		return _pos
	
	func get_cornering_triangles() -> Array:
		return _polygons
		
	func _get_line_ids() -> String:
		var ids_string : String = ""
		var first := true
		for line in _connections:
			ids_string += "" if first else ", "
			first = false
			ids_string += "%d" % line.get_instance_id()
		return ids_string
	
	func get_connections() -> Array:
		return _connections
	
	func get_connected_points() -> Array:
		var connected_points := []
		for con in _connections:
			connected_points.append(con.other_point(self))
		return connected_points
	
	func height_set() -> bool:
		return _height_set
	
	func set_height(height: float) -> void:
		_height_set = true
		_height = height
		
	func get_height() -> float:
		return _height
	
	func has_polygon_with_parent(parent: Object) -> bool:
		for triangle in _polygons:
			if triangle.get_parent() == parent:
				return true
		return false
	
	func draw_as_height(image: Image, color: Color) -> void:
		var scaled_color = lerp(Color.black, color, (_height * _height_color_scale) + 0.5 )
		if height_set():
			image.set_pixelv(_pos, scaled_color)
	
	func _to_string() -> String:
		return "%d: %s: { %s }" % [get_instance_id(), _pos, _get_line_ids()]


class BaseLine:
	var _a: BasePoint
	var _b: BasePoint
	var _borders: Array
	
	func _init(a: BasePoint, b: BasePoint) -> void:
		if BasePoint.sort_vert_inv_hortz(a, b):
			_a = a
			_b = b
		else:
			_a = b
			_b = a
		_borders = []
	
	func get_points() -> Array:
		return [_a, _b]
	
	func shared_point(other: BaseLine) -> BasePoint:
		if self._a == other._a or self._a == other._b:
			return self._a
		elif self._b == other._a or self._b == other._b:
			return _b
		else:
			return BasePoint.error()
	
	func shares_a_point_with(other: BaseLine) -> bool:
		return (
			other.has_point(_a) or
			other.has_point(_b)
		)
	
	func has_point(point: BasePoint) -> bool:
		return _a == point or _b == point
	
	func other_point(this: BasePoint) -> BasePoint:
		if this == _a:
			return _b
		return _a
	
	func draw_line_on_image(image: Image, col: Color) -> void:
		var a := _a.get_pos()
		var b := _b.get_pos()
		var longest_side = int(max(abs(a.x - b.x), abs(a.y - b.y))) + 1
		for p in range(longest_side):
			var t = (1.0 / longest_side) * p
			image.set_pixelv(lerp(a, b, t), col)
	
	static func sort_vert_hortz(a: BaseLine, b: BaseLine) -> bool:
		if BasePoint.sort_vert_hortz(a._a, b._a):
			return true
		elif a._a.equals(b._a) and BasePoint.sort_vert_hortz(a._b, b._b):
			return true
		return false
	
	func error() -> BaseLine:
		printerr("Something needed a placeholder BaseLine")
		return BaseLine.new(BasePoint.new(0.0, 0.0), BasePoint.new(0.0, 0.0))
	
	func set_border_of(triangle: BaseTriangle) -> void:
		_borders.append(triangle)
	
	func get_bordering_triangles() -> Array:
		return _borders
	
	func center_in_ring(center: Vector2, min_distance: float, max_distance: float) -> bool:
		var min_squared: float = min_distance * min_distance
		var max_squared: float = max_distance * max_distance
		var line_center: Vector2 = (_a.get_pos() + _b.get_pos()) / 2.0
		var distance = line_center.distance_squared_to(center)
		return distance >= min_squared and distance <= max_squared
	
	func end_point_farthest_from(target: Vector2) -> BasePoint:
		if _a.get_pos().distance_squared_to(target) >= _b.get_pos().distance_squared_to(target):
			return _a
		else:
			return _b
	
	func _to_string() -> String:
		return "%d: { %d -> %d }" % [get_instance_id(), _a.get_instance_id(), _b.get_instance_id()]


class BaseTriangle:
	var _points: Array
	var _edges: Array
	var _neighbours: Array
	var _corner_neighbours: Array
	var _parent: Object = null
	var _pos: Vector2
	var _index_row: int
	var _index_col: int
	
	func _init(a: BaseLine, b: BaseLine, c: BaseLine, index_col: int, index_row: int) -> void:
		_points = [a.shared_point(b), a.shared_point(c), b.shared_point(c)]
		_points.sort_custom(BasePoint, "sort_vert_hortz")
		_index_col = index_col
		_index_row = index_row
		_edges = [a, b, c]
		for point in _points:
			point.add_polygon(self)
		for edge in _edges:
			edge.set_border_of(self)
		_pos = (_points[0]._pos + _points[1]._pos + _points[2]._pos) / 3.0
	
	func update_neighbours_from_edges() -> void:
		for edge in _edges:
			for tri in edge.get_bordering_triangles():
				if tri != self:
					_neighbours.append(tri)
		for point in _points:
			for tri in point.get_cornering_triangles():
				if not tri in _neighbours and not tri in _corner_neighbours and not tri == self:
					_corner_neighbours.append(tri)
	
	func get_points() -> Array:
		return _points
	
	func get_edges() -> Array:
		return _edges
	
	func get_neighbours() -> Array:
		return _neighbours
	
	func get_parent() -> Object:
		return _parent
	
	func get_pos() -> Vector2:
		return _pos
	
	func set_parent(parent: Object) -> void:
		_parent = parent
	
	func get_neighbours_with_parent(parent: Object) -> Array:
		var parented_neighbours = []
		for neighbour in _neighbours:
			if neighbour.get_parent() == parent:
				parented_neighbours.append(neighbour)
		return parented_neighbours
	
	func get_corner_neighbours_with_parent(parent: Object) -> Array:
		var parented_corner_neighbours = []
		for corner_neighbour in _corner_neighbours:
			if corner_neighbour.get_parent() == parent:
				parented_corner_neighbours.append(corner_neighbour)
		return parented_corner_neighbours
	
	func get_neighbour_borders_with_parent(parent: Object) -> Array:
		var borders : Array = []
		for edge in _edges:
			for tri in edge.get_bordering_triangles():
				if tri != self and tri.get_parent() == parent:
					borders.append(edge)
		return borders
		
	func is_on_field_boundary() -> bool:
		return len(_neighbours) < len(_edges)
	
	func get_edges_on_field_boundary() -> Array:
		var boundary_edges : Array = []
		for edge in _edges:
			if len(edge.get_bordering_triangles()) == 1:
				boundary_edges.append(edge)
		return boundary_edges
	
	func count_neighbours_with_parent(parent: Object) -> int:
		return get_neighbours_with_parent(parent).size()
	
	func count_corner_neighbours_with_parent(parent: Object) -> int:
		return get_corner_neighbours_with_parent(parent).size()
	
	func get_neighbours_no_parent() -> Array:
		return get_neighbours_with_parent(null)
	
	func draw_triangle_on_image(image: Image, color: Color) -> void:
		for line in _edges:
			line.draw_line_on_image(image, color)
		draw_filled_triangle_on_image(image, color)
	
	# Can use special-case flat top and bottom triangle fill algorithms for filling
	# E.g.: http://www.sunshine2k.de/coding/java/TriangleRasterization/TriangleRasterization.html
	
	func _draw_filled_flat_top_triangle_on_image(image: Image, color: Color) -> void:
		# Flat topped triangles are created with points (p) and edges (e) in a specific orders
		#              e1 
		#         p0 ------ p2     slope of e2 will always be half the side, divided by the height
		#           \      /       slope of e0 will be the negative of e2
		#         e0 \    / e2     SLOPE_e2 = (tri_side / 2) / sqrt(0.75 * (tri_side * tri_side))
		#             \  /         SLOPE_e2 = tri_side / ( 2 * sqrt(0.75) * tri_side )
		#              p1          SLOPE_e2 = 1 / sqrt(0.75 * 4)
		
		var start_x : float = _points[0].get_pos().x
		var end_x : float = _points[2].get_pos().x
		var start_y : int = int(_points[0].get_pos().y)
		var end_y : int = int(_points[1].get_pos().y)
		
		for y in range(start_y, end_y + 1):
			for x in range(int(start_x), int(end_x) + 1):
				image.set_pixel(x, y, color)
			start_x += SLOPE
			end_x -= SLOPE
		
	func _draw_filled_flat_bottom_triangle_on_image(image: Image, color: Color) -> void:
		# Flat bottomed triangles are created with points (p) and edges (e) in a specific orders
		#              p2 
		#             /  \
		#         e2 /    \ e1
		#           /      \
		#         p1 ------ p0
		#              e0
		
		var start_x : float = _points[2].get_pos().x
		var end_x : float = _points[2].get_pos().x
		var start_y : int = int(_points[2].get_pos().y)
		var end_y : int = int(_points[1].get_pos().y)
		
		for y in range(start_y, end_y + 1):
			for x in range(int(start_x), int(end_x) + 1):
				image.set_pixel(x, y, color)
			start_x -= SLOPE
			end_x += SLOPE
	
	func _is_flat_topped() -> bool:
		"""False implies flat bottomed as the grid only has this orientation"""
		# If the first and last points are on the same y axis, this is flat topped
		return _points[0].get_pos().y == _points[2].get_pos().y
	
	func draw_filled_triangle_on_image(image: Image, color: Color) -> void:
		if _is_flat_topped():
			_draw_filled_flat_top_triangle_on_image(image, color)
		else:
			_draw_filled_flat_bottom_triangle_on_image(image, color)
	
	func get_closest_neighbour_to(point: Vector2) -> BaseTriangle:
		var closest = _neighbours[0]
		var current_sqr_dist = point.distance_squared_to(closest.get_pos())
		for neighbour in _neighbours.slice(1, _neighbours.size()):
			var next_sqr_dist = point.distance_squared_to(neighbour.get_pos())
			if next_sqr_dist < current_sqr_dist:
				closest = neighbour
				current_sqr_dist = next_sqr_dist
		return closest
	
	func _get_neighbour_ids() -> String:
		var neighbour_ids : String = ""
		var first := true
		for neighbour in _neighbours:
			neighbour_ids += "\n  " if first else ",\n  "
			first = false
			neighbour_ids += "%d" % neighbour.get_instance_id()
		return neighbour_ids
	
	func _get_corner_neighbour_ids() -> String:
		var corner_neighbour_ids : String = ""
		var first := true
		for corner_neighbour in _corner_neighbours:
			corner_neighbour_ids += "\n  " if first else ",\n  "
			first = false
			corner_neighbour_ids += "%d" % corner_neighbour.get_instance_id()
		return corner_neighbour_ids
	
	func get_status() -> String:
		var status : String = ""
		status += "%d (%d, %d) %s\n" % [ get_instance_id(), _index_col, _index_row, _pos ]
		status += "Corner Neighbours: [%s\n]" % _get_corner_neighbour_ids()
		status += "Edge Neighbours: [%s\n]" % _get_neighbour_ids()
		status += "Lines: [\n  %s,\n  %s,\n  %s\n]\n" % _edges
		status += "Points: [\n  %s,\n  %s,\n  %s\n]\n" % _points
		status += "Parent: %s" % _parent
		return status


class Utils:
	static func shuffle(rng: RandomNumberGenerator, target: Array) -> void:
		for i in range(len(target)):
			var j: int = rng.randi_range(0, len(target) - 1)
			var swap = target[i]
			target[i] = target[j]
			target[j] =swap
	
	static func _get_chains_from_lines(perimeter: Array) -> Array:
		"""
		Given an array of unordered BaseLines on the perimeter of a shape
		Return an array, each element of which is an array of BaseLines ordered by
		the path around the perimeter. One of the arrays will be the outer shape and the
		rest will be internal "holes" in the shape.
		"""
		var perimeter_lines := perimeter.duplicate()
		# Identify chains by tracking each point in series of perimeter lines
		var chains: Array = []
		while not perimeter_lines.empty():
			# Next chain, pick the end of a line
			var chain_done = false
			var chain_flipped = false
			var chain: Array = []
			var next_chain_line: BaseLine = perimeter_lines.pop_back()
			var start_chain_point: BasePoint = next_chain_line.get_points().front()
			var next_chain_point: BasePoint = next_chain_line.other_point(start_chain_point)
			# Follow the lines until we reach back to the beginning
			while not chain_done:
				chain.append(next_chain_line)
				
				# Do we have a complete chain now?
				if len(chain) >= 3 and chain.front().shares_a_point_with(chain.back()):
					chains.append(chain)
					chain_done = true
					continue
				
				# Which directions can we go from here?
				var connections = next_chain_point.get_connections()
				var directions: Array = []
				for line in connections:
					# Skip the current line
					if line == next_chain_line:
						continue
					if perimeter_lines.has(line):
						directions.append(line)
				
				# If there's no-where to go, something went wrong
				if len(directions) <= 0:
					printerr("FFS: This line goes nowhere!")
				
				# If there's only one way to go, go that way
				elif len(directions) == 1:
					next_chain_line = directions.front()
					next_chain_point = next_chain_line.other_point(next_chain_point)
					perimeter_lines.erase(next_chain_line)
				
				else:
					# Any links that link back to start of the current chain?
					var loop = false
					for line in directions:
						if line.other_point(next_chain_point) == start_chain_point:
							loop = true
							next_chain_line = line
							next_chain_point = next_chain_line.other_point(next_chain_point)
							perimeter_lines.erase(line)
					
					if not loop:
						# Multiple directions with no obvious loop, 
						# Reverse the chain to extend it in the opposite direction
						if chain_flipped:
							# This chain has already been flipped, both ends are trapped
							# Push this chain back into the pool of lines and try again
							chain.append_array(perimeter_lines)
							perimeter_lines = chain
							chain_done = true
							continue
						
						chain.invert()
						var old_start_point : BasePoint = start_chain_point
						start_chain_point = next_chain_point
						next_chain_line = chain.pop_back()
						next_chain_point = old_start_point
						chain_flipped = true
		
		return chains


class Stage extends Utils:
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
		var return_cache : Image = _cached_image.duplicate()
		return return_cache
	
	func update_mouse_coords(_mouse_coords: Vector2) -> void:
		pass


class BaseGrid extends Stage:
	var _color: Color
	var _tri_side: float
	var _tri_height: float
	var _grid_points: Array = []  # Array of rows of points
	var _grid_lines: Array = []
	var _grid_tris: Array = []
	var _cell_count: int = 0
	var _center: Vector2
	var _near_center_edges: Array = []
	
	func _init(edge_size: float, rect_size: Vector2, color: Color) -> void:
		_center = rect_size / 2.0
		_tri_side = edge_size
		_color = color
		_tri_height = sqrt(0.75) * _tri_side
		
#		 |\         h^2 + (s/2)^2 = s^2
#		 | \        h^2 = s^2 - (s/2)^2
#		 |  \s      h^2 = s^2 - (s^2 / 4)
#		h|   \      h^2 = (1 - 1/4) * s^2
#		 |    \     h^2 = ( 3/4 * s^2 )
#		 |_____\      h = sqrt(3/4 * s^2)
#		  (s/2)       h = sqrt(3/4) * s
		
		# Lay out points and connect them to any existing points
		var row_ind: int = 0
		for y in range (_tri_height / 2.0, rect_size.y, _tri_height):
			var points_row: Array = []
			var ind_offset: int = (row_ind % 2) * 2 - 1
			var offset: float = (row_ind % 2) * (_tri_side / 2.0)
			var col_ind: int = 0
			for x in range(offset + (_tri_side / 2.0), rect_size.x, _tri_side):
				var new_point = BasePoint.new(x, y)
				var lines := []
				points_row.append(new_point)
				# Connect from the left
				if col_ind > 0:
					var existing_point: BasePoint = points_row[col_ind - 1]
					lines.append(_add_grid_line(existing_point, new_point))
				# Connect from above (the simpler way - left or right depends on row)
				if row_ind > 0 and col_ind < _grid_points[row_ind - 1].size():
					var existing_point = _grid_points[row_ind - 1][col_ind]
					lines.append(_add_grid_line(existing_point, new_point))
				# Connect from above (the other way)
				if row_ind > 0 and col_ind + ind_offset >= 0 and col_ind + ind_offset < _grid_points[row_ind - 1].size():
					var existing_point = _grid_points[row_ind - 1][col_ind + ind_offset]
					lines.append(_add_grid_line(existing_point, new_point))
				
				col_ind += 1
			_grid_points.append(points_row)
			row_ind += 1
		
		# Go through the points and create triangles "upstream"
		# I.e.: Triangles together with points only greater than the current point
		var tri_row_ind : int = 0
		for row in _grid_points:
			var tri_row : Array = []
			var tri_col_ind : int = 0
			for point in row:
				# Get connections, find connects between higher points
				for first_line in point.higher_connections():
					var second_point: BasePoint = first_line.other_point(point)
					for second_line in second_point.higher_connections_to_point(point):
						var third_point: BasePoint = second_line.other_point(second_point)
						var third_line: BaseLine = third_point.connection_to_point(point)
						tri_row.append(BaseTriangle.new(first_line, second_line, third_line, tri_col_ind, tri_row_ind))
						_cell_count += 1
						tri_col_ind += 1
			if not tri_row.empty():
				_grid_tris.append(tri_row)
				tri_row_ind += 1
		
		for tri_row in _grid_tris:
			for tri in tri_row:
				tri.update_neighbours_from_edges()
	
	func status_text() -> String:
		return "Creating grid..."
	
	func get_point_rows() -> Array:
		"""Returns the array of rows of points"""
		return _grid_points
	
	func _add_grid_line(a: BasePoint, b: BasePoint) -> BaseLine:
		var new_line := BaseLine.new(a, b)
		a.add_connection(new_line)
		b.add_connection(new_line)
		_grid_lines.append(new_line)
		# Save a special ring of edges near the center for river heads
		if new_line.center_in_ring(_center, 30.0, 30.0 + _tri_side):
			_near_center_edges.append(new_line)
		return new_line
	
	func update_image(image: Image) -> void:
		image.lock()
		for line in _grid_lines:
			line.draw_line_on_image(image, _color)
		image.unlock()
		.update_image(image)
	
	func get_cell_count() -> int:
		return _cell_count
	
	func get_middle_triangle() -> BaseTriangle:
		var mid_row = _grid_tris[_grid_tris.size() / 2]
		return mid_row[mid_row.size() / 2]
	
	func get_nearest_triangle_to(point: Vector2) -> BaseTriangle:
		# What are the coords again?
		# For now: Just find a nearish one, then follow the neighbours until we get there
		var grid_row = int((point.y - _tri_height) / _tri_height)
		grid_row = min(grid_row, len(_grid_tris) - 1)
		var row_pos = int((point.x - _tri_side / 2.0) / _tri_side)
		row_pos = min(row_pos, len(_grid_tris[grid_row]) - 1)
		
		var nearest : BaseTriangle = _grid_tris[grid_row][row_pos]
		var current_sqr_dist : float = point.distance_squared_to(nearest.get_pos())
		var next_nearest : = nearest.get_closest_neighbour_to(point)
		var next_sqr_dist : float = point.distance_squared_to(next_nearest.get_pos())
		while point.distance_squared_to(next_nearest.get_pos()) < current_sqr_dist:
			nearest = next_nearest
			current_sqr_dist = next_sqr_dist
			next_nearest = nearest.get_closest_neighbour_to(point)
			next_sqr_dist = point.distance_squared_to(next_nearest.get_pos())
		return nearest
	
	func get_near_center_edges() -> Array:
		return _near_center_edges.duplicate()
	
	func get_center() -> Vector2:
		return _center


class TriBlob extends Stage:
	var _grid: BaseGrid
	var _land_color: Color
	var _perimeter_color: Color
	var _cells: Array
	var _cell_limit: int
	var _blob_front: Array
	var _perimeter: Array
	var _expansion_done: bool
	var _perimeter_done: bool
	var _rng: RandomNumberGenerator
	
	func _init(grid: BaseGrid, land_color: Color, perimeter_color: Color, cell_limit: int, rng_seed: int):
		_grid = grid
		_land_color = land_color
		_perimeter_color = perimeter_color
		_cells = []
		_cell_limit = cell_limit
		_blob_front = []
		_perimeter = []
		_expansion_done = false
		_perimeter_done = false
		_rng = RandomNumberGenerator.new()
		_rng.seed = rng_seed
		var start = grid.get_middle_triangle()
		add_triangle_as_cell(start)
	
	func status_text() -> String:
		return "Generating the initial bounds of the island..."
	
	func add_triangle_as_cell(triangle: BaseTriangle) -> void:
		triangle.set_parent(self)
		_cells.append(triangle)
		# Remove this one from the _blob_front
		if triangle in _blob_front:
			_blob_front.erase(triangle)  # Not a super fast action
		# Add neighbours to _blob_front
		for neighbour in triangle.get_neighbours_no_parent():
			if not neighbour in _blob_front:
				_blob_front.append(neighbour)
			
		if triangle.is_on_field_boundary():
			_perimeter.append_array(triangle.get_edges_on_field_boundary())
	
	func draw_triangles(image: Image, color: Color) -> void:
		image.lock()
		for cell in _cells:
			cell.draw_triangle_on_image(image, color)
		image.unlock()
	
	func _add_non_perimeter_boundaries() -> void:
		"""
		Find triangles on the boundary front that aren't against the perimeter and
		assume they're inside the total shape. Add them and any unparented neighbours
		to the blob. 
		"""
		var remove_from_front: Array = []
		for front_triangle in _blob_front:
			var has_edge_in_perimeter := false
			for edge in front_triangle.get_edges():
				if edge in _perimeter:
					has_edge_in_perimeter = true
					break
			if not has_edge_in_perimeter:
				front_triangle.set_parent(self)
				_cells.append(front_triangle)
				remove_from_front.append(front_triangle)
				# Is there are any triangles adjacent that are null parented, add to _blob_front
				for neighbour_triangle in front_triangle.get_neighbours():
					if neighbour_triangle.get_parent() == null and not neighbour_triangle in _blob_front:
						_blob_front.append(neighbour_triangle)
		
		for front_triangle in remove_from_front:
			_blob_front.erase(front_triangle)
	
	func get_perimeter_lines() -> Array:
		if _perimeter_done:
			return _perimeter
		
		var blob_front := _blob_front.duplicate()
		
		# using the _blob_front, get all the lines joining to parented cells
		while not blob_front.empty():
			var outer_triangle = blob_front.pop_back()
			var borders : Array = outer_triangle.get_neighbour_borders_with_parent(self)
			_perimeter.append_array(borders)
		
		# Identify chains by tracking each point in series of perimeter lines
		var chains: Array = _get_chains_from_lines(_perimeter)
		
		# Set the _perimeter to the longest chain
		var max_chain: Array = chains.back()
		for chain in chains:
			if len(max_chain) < len(chain):
				max_chain = chain
		_perimeter = max_chain
		
		# Include threshold triangles that are not on the perimeter path
		_add_non_perimeter_boundaries()
		
		_perimeter_done = true
		return _perimeter
	
	func get_some_triangles(count: int) -> Array:
		"""This *could* be random, but for now will use the last added triangles"""
		return _cells.slice(len(_cells)-count, len(_cells)-1)
	
	func update_data_tick(return_after: float) -> void:
		while OS.get_ticks_msec() < return_after:
			if not _expansion_done:
				shuffle(_rng, _blob_front)
				add_triangle_as_cell(_blob_front.back())
				if _cells.size() >= _cell_limit:
					_expansion_done = true
				continue
			
			if not _perimeter_done:
				var _lines := get_perimeter_lines()
				_perimeter_done = true
	
	func update_complete() -> bool:
		return _expansion_done and _perimeter_done
	
	func draw_perimeter_lines(image: Image, color: Color) -> void:
		image.lock()
		for line in get_perimeter_lines():
			line.draw_line_on_image(image, color)
		image.unlock()
		
	func update_image(image: Image) -> void:
		if _perimeter_done:
			draw_perimeter_lines(image, _perimeter_color)
		else:
			draw_triangles(image, _land_color)
		.update_image(image)


class MouseTracker extends Stage:
	var _grid: BaseGrid
	var _status_text: String
	var _color: Color
	var _mouse_coords: Vector2
	
	func _init(grid: BaseGrid, color: Color) -> void:
		_grid = grid
		_color = color
		_status_text = "Initialising mouse tracking..."
	
	func status_text() -> String:
		return _status_text
	
	func update_mouse_coords(mouse_coords: Vector2) -> void:
		_mouse_coords = mouse_coords
	
	func update_image(image: Image) -> void:
		image.lock()
		var triangle: BaseTriangle = _grid.get_nearest_triangle_to(_mouse_coords)
		triangle.draw_triangle_on_image(image, _color)
		image.unlock()
		# .update_image(image) not needed, we don't want to keep these frames
		# Get triangle stats
		_status_text = triangle.get_status()


class Region extends Utils:
	var _parent: TriBlob
	var _debug_color: Color
	var _cells: Array
	var _region_front: Array
	var _rng: RandomNumberGenerator
	
	func _init(parent: TriBlob, start_triangle: BaseTriangle, debug_color: Color, rng_seed: int) -> void:
		_parent = parent
		_debug_color = debug_color
		_cells = []
		_region_front = [start_triangle]
		_rng = RandomNumberGenerator.new()
		_rng.seed = rng_seed
	
	func expand_tick() -> bool:
		if _region_front.empty():
			return true
		shuffle(_rng, _region_front)
		add_triangle_as_cell(_region_front.back())
		return false
	
	func add_triangle_as_cell(triangle: BaseTriangle) -> void:
		triangle.set_parent(self)
		_cells.append(triangle)
		# Remove this one from the _blob_front
		_region_front.erase(triangle)
		# Add neighbours to _blob_front
		for neighbour in triangle.get_neighbours_with_parent(_parent):
			if not neighbour in _region_front:
				_region_front.append(neighbour)
	
	func remove_triangle_as_cell(triangle: BaseTriangle) -> void:
			triangle.set_parent(_parent)
			_cells.erase(triangle)
	
	func draw_triangles(image: Image) -> void:
		for cell in _cells:
			cell.draw_triangle_on_image(image, _debug_color)
	
	func expand_margins() -> void:
		var border_cells: Array = []
		for cell in _cells:
			if cell.count_neighbours_with_parent(self) < 3:
				border_cells.append(cell)
			elif cell.count_corner_neighbours_with_parent(self) < 9:
				border_cells.append(cell)
		# Return the border cells to the parent
		for border_cell in border_cells:
			remove_triangle_as_cell(border_cell)
	
	func get_some_triangles(count: int) -> Array:
		var random_cells = []
		for _i in range(min(count, len(_cells))):
			random_cells.append(_cells[_rng.randi() % len(_cells)])
		return random_cells
	
	func get_debug_color() -> Color:
		return _debug_color


class RegionManager extends Stage:
	var _parent: TriBlob
	var _colors: Array
	var _started: bool
	var _regions: Array
	var _regions_done: bool
	var _margins_done: bool
	var _rng: RandomNumberGenerator
	
	func _init(parent: TriBlob, colors: Array, rng_seed: int) -> void:
		_parent = parent
		_colors = colors
		_started = false
		_regions = []
		_regions_done = false
		_margins_done = false
		_rng = RandomNumberGenerator.new()
		_rng.seed = rng_seed
	
	func status_text() -> String:
		return "Sectioning off the island..."
	
	func _setup_regions() -> void:
		var start_triangles = _parent.get_some_triangles(len(_colors))
		for i in range(min(len(_colors), len(start_triangles))):
			_regions.append(Region.new(_parent, start_triangles[i], _colors[i], _rng.randi()))
	
	func update_data_tick(return_after: float) -> void:
		while OS.get_ticks_msec() < return_after:
			if not _started:
				_setup_regions()
				_started = true
				continue
			
			if not _regions_done:
				var done = true
				for region in _regions:
					if not region.expand_tick():
						done = false
				if done:
					_regions_done = true
				continue
			
			if not _margins_done:
				expand_margins()
				_margins_done = true
			
	
	func update_complete() -> bool:
		return _regions_done and _margins_done
	
	func update_image(image: Image) -> void:
		# Don't draw these regions, unless we're still in the creation steps
		if not update_complete():
			image.lock()
			for region in _regions:
				region.draw_triangles(image)
			image.unlock()
		.update_image(image)
	
	func expand_margins() -> void:
		for region in _regions:
			region.expand_margins()
	
	func get_regions() -> Array:
		return _regions


class SubRegion extends Utils:
	var _parent: Region
	var _debug_color: Color
	var _cells: Array
	var _perimeter_points: Array
	var _inner_perimeter: Array
	var _region_front: Array
	var _rng: RandomNumberGenerator
	
	func _init(parent: Region, start_triangle: BaseTriangle, debug_color: Color, rng_seed: int) -> void:
		_parent = parent
		_debug_color = debug_color
		_cells = []
		_perimeter_points = []
		_region_front = [start_triangle]
		_rng = RandomNumberGenerator.new()
		_rng.seed = rng_seed
	
	func expand_tick() -> bool:
		if _region_front.empty():
			return true
		shuffle(_rng, _region_front)
		add_triangle_as_cell(_region_front.back())
		return false
	
	func add_triangle_as_cell(triangle: BaseTriangle) -> void:
		triangle.set_parent(self)
		_cells.append(triangle)
		# Remove this one from the _blob_front
		_region_front.erase(triangle)
		# Add neighbours to _blob_front
		for neighbour in triangle.get_neighbours_with_parent(_parent):
			if not neighbour in _region_front:
				_region_front.append(neighbour)
	
	func remove_triangle_as_cell(triangle: BaseTriangle) -> void:
			triangle.set_parent(_parent)
			_cells.erase(triangle)
	
	func draw_triangles(image: Image, color: Color = self._debug_color) -> void:
		for cell in _cells:
			cell.draw_triangle_on_image(image, color)
	
	func expand_margins() -> void:
		var border_cells: Array = []
		for cell in _cells:
			if cell.count_neighbours_with_parent(self) < 3:
				border_cells.append(cell)
			elif cell.count_corner_neighbours_with_parent(self) < 9:
				border_cells.append(cell)
		# Return the border cells to the parent
		for border_cell in border_cells:
			remove_triangle_as_cell(border_cell)
	
	func get_some_triangles(count: int) -> Array:
		var random_cells = []
		for _i in range(count):
			random_cells.append(_cells[_rng.randi() % len(_cells)])
		return random_cells
	
	func _get_points_in_region() -> Array:
		"""Get all the points within the region"""
		var points: Array = []
		for triangle in _cells:
			for point in triangle.get_points():
				if not point in points:
					points.append(point)
		return points
	
	func identify_perimeter_points() -> void:
		var region_points : Array = _get_points_in_region()
		for point in region_points:
			if point.has_polygon_with_parent(_parent):
				_perimeter_points.append(point)
		
		for outer_point in _perimeter_points:
			for point in outer_point.get_connected_points():
				if (
					not point in _perimeter_points 
					and point in region_points
					and not point in _inner_perimeter
				):
					_inner_perimeter.append(point)
	
	func get_outer_perimeter_points() -> Array:
		return _perimeter_points
	
	func get_inner_perimeter_points() -> Array:
		return _inner_perimeter


class SubRegionManager extends Stage:
	var _parent_manager: RegionManager
	var _colors: Array
	var _started: bool
	var _regions: Array
	var _regions_done: bool
	var _margins_done: bool
	var _perimeters_done: bool
	var _rng: RandomNumberGenerator
	
	func _init(parent_manager: RegionManager, colors: Array, rng_seed: int) -> void:
		_parent_manager = parent_manager
		_colors = colors
		_started = false
		_regions = []
		_regions_done = false
		_margins_done = false
		_perimeters_done = false
		_rng = RandomNumberGenerator.new()
		_rng.seed = rng_seed
	
	func status_text() -> String:
		return "Sub sectioning the sections of the island..."
	
	func _setup_subregions() -> void:
		for parent in _parent_manager.get_regions():
			# The parent region might not be big enought to have subregions
			var start_triangles = parent.get_some_triangles(len(_colors))
			for i in range(min(len(_colors), len(start_triangles))):
				_regions.append(SubRegion.new(parent, start_triangles[i], _colors[i], _rng.randi()))
	
	func update_data_tick(return_after: float) -> void:
		while OS.get_ticks_msec() < return_after:
			if not _started:
				_setup_subregions()
				_started = true
				continue
			
			if not _regions_done:
				var done = true
				for region in _regions:
					if not region.expand_tick():
						done = false
				if done:
					_regions_done = true
				continue
			
			if not _margins_done:
				expand_margins()
				_margins_done = true
			
			if not _perimeters_done:
				identify_perimeters()
				_perimeters_done = true
	
	func update_complete() -> bool:
		return _perimeters_done
	
	func update_image(image: Image) -> void:
		# Don't draw these regions, unless we're still in the creation steps
		if not update_complete():
			image.lock()
			for region in _regions:
				region.draw_triangles(image)
			image.unlock()
		.update_image(image)
	
	func expand_margins() -> void:
		for region in _regions:
			region.expand_margins()
	
	func identify_perimeters() -> void:
		for region in _regions:
			region.identify_perimeter_points()
	
	func sub_region_for_edge(edge: BaseLine):
		for tri in edge.get_bordering_triangles():
			var sub_region = tri.get_parent()
			if sub_region in _regions:
				return sub_region
		return null
	
	func sub_region_for_point(point: BasePoint):
		for region in _regions:
			if point.has_polygon_with_parent(region):
				return region
		return null


class PointHeightsManager extends Stage:
	var _grid: BaseGrid
	var _island: TriBlob
	var _lake_manager: SubRegionManager
	var _color: Color
	var _diff_height: float = 1.0
	var _sealevel_points: Array
	var _downhill_front: Array
	var _downhill_height: float = -_diff_height
	var _uphill_front: Array
	var _uphill_height: float = _diff_height
	var _sealevel_started: bool
	var _height_fronts_started: bool
	var _downhill_complete: bool
	var _uphill_complete: bool
	
	func _init(grid: BaseGrid, island: TriBlob, lake_manager: SubRegionManager, color: Color) -> void:
		_grid = grid
		_island = island
		_lake_manager = lake_manager
		_color = color
		_sealevel_started = false
		_height_fronts_started = false
		_downhill_complete = false
		_uphill_complete = false
	
	func status_text() -> String:
		return "Generating height map..."
	
	func _setup_sealevel() -> void:
		_sealevel_points = []
		for line in _island.get_perimeter_lines():
			for point in line.get_points():
				if not point in _sealevel_points:
					point.set_height(0.0)
					_sealevel_points.append(point)
	
	func _setup_height_fronts() -> void:
		for center_point in _sealevel_points:
			for point in center_point.get_connected_points():
				if not point.height_set():
					# Uphill or downhill neighbour?
					if point.has_polygon_with_parent(_island):
						point.set_height(_uphill_height)
						_uphill_front.append(point)
					else:
						point.set_height(_downhill_height)
						_downhill_front.append(point)
	
	func _step_downhill() -> void:
		_downhill_height -= _diff_height
		var new_downhill_front: Array = []
		for center_point in _downhill_front:
			for point in center_point.get_connected_points():
				if not point.height_set():
					point.set_height(_downhill_height)
					new_downhill_front.append(point)
		_downhill_front = new_downhill_front
	
	func _step_uphill() -> void:
		# TODO: Take account of lakes (and rivers? or ignore?)
		_uphill_height += _diff_height
		var new_uphill_front: Array = []
		for center_point in _uphill_front:
			for point in center_point.get_connected_points():
				if not point.height_set():
					new_uphill_front.append(point)
					# If this point is on a sub-region lake,
					var lake : SubRegion = _lake_manager.sub_region_for_point(point)
					if lake:
						#  add the perimeter points to the uphill
						new_uphill_front.append_array(lake.get_outer_perimeter_points())
						
						# and any inside points to the downhill,
						var inside_points : Array = lake.get_inner_perimeter_points()
						if not inside_points.empty():
							#  reset the downhill state, and set the downhill height
							_downhill_height = _uphill_height - _diff_height
							_downhill_front.append_array(inside_points)
							_downhill_complete = false
		
		for point in new_uphill_front:
			point.set_height(_uphill_height)
		_uphill_front = new_uphill_front
			
		if not _downhill_front.empty():
			for point in _downhill_front:
				point.set_height(_downhill_height)
	
	func update_data_tick(return_after: float) -> void:
		while OS.get_ticks_msec() < return_after:
			if not _sealevel_started:
				_setup_sealevel()
				_sealevel_started = true
				continue
			
			if not _height_fronts_started:
				_setup_height_fronts()
				_height_fronts_started = true
				continue
			
			if not _downhill_complete:
				_step_downhill()
				if _downhill_front.empty():
					_downhill_complete = true
				continue
			
			if not _uphill_complete:
				_step_uphill()
				if _uphill_front.empty():
					_uphill_complete = true
				continue
	
	func update_complete() -> bool:
		return _uphill_complete
	
	func _draw_points_as_heights(image):
		for row in _grid.get_point_rows():
			for point in row:
				point.draw_as_height(image, _color)
	
	func update_image(image: Image):
		image.lock()
		_draw_points_as_heights(image)
		image.unlock()
		.update_image(image)


class RiverManager extends Stage:
	var _rivers: Array
	var _grid: BaseGrid
	var _subregion_manager: SubRegionManager
	var _river_count: int
	var _river_color: Color
	var _lake_color: Color
	var _started: bool
	var _rng: RandomNumberGenerator
	
	func _init(
		grid: BaseGrid, subregion_manager: SubRegionManager, river_count: int, river_color: Color, lake_color: Color, rng_seed: int
	) -> void:
		_grid = grid
		_subregion_manager = subregion_manager
		_river_count = river_count
		_river_color = river_color
		_lake_color = lake_color
		_rng = RandomNumberGenerator.new()
		_rng.seed = rng_seed
	
	func _setup_rivers():
		_rivers = []
		
		var near_center_edges := _grid.get_near_center_edges()
		shuffle(_rng, near_center_edges)
		
		for _i in range(_river_count):
			_rivers.append(create_river(near_center_edges.pop_back()))
	
	func update_data_tick(_return_after: float) -> void:
		if not _started:
			_setup_rivers()
			_started = true
	
	func update_complete() -> bool:
		return _started
	
	func create_river(start_edge: BaseLine) -> Array:
		"""Create a chain of edges from near center to outer bounds"""
		if not start_edge:
			return []
		
		var center := _grid.get_center()
		var river := [start_edge]
		# get furthest end from center, then extend the river until it hits the boundary
		var connection_point: BasePoint = start_edge.end_point_farthest_from(center)
		while len(connection_point.get_connections()) >= 6:
			# Get a random edge that moves away from the center
			var connections: Array = Array(connection_point.get_connections())
			shuffle(_rng, connections)
			var try_edge : BaseLine = connections.pop_back()
			while not connections.empty() and try_edge.end_point_farthest_from(center) == connection_point:
				try_edge = connections.pop_back()
			# This shouldn't happen:
			if try_edge.end_point_farthest_from(center) == connection_point:
				printerr("All edges point towards the center")
			
			# Move along the random edge
			river.append(try_edge)
			connection_point = try_edge.other_point(connection_point)
		
		return river
	
	func identify_lakes_on_course(river: Array) -> Array:
		# TODO: Need to modify - want to only draw the river parts that aren't between 
		# the first entry edge on the lake and the last exit edge on the lake
		# Maybe even split rivers
		var lakes := []
		for edge in river:
			var lake = _subregion_manager.sub_region_for_edge(edge)
			if lake != null and not lake in lakes:
				lakes.append(lake)
		return lakes
		
	func update_image(image: Image) -> void:
		image.lock()
		for river in _rivers:
			for edge in river:
				edge.draw_line_on_image(image, _river_color)
			var lakes := identify_lakes_on_course(river)
			for lake in lakes:
				lake.draw_triangles(image, _lake_color)
		image.unlock()
		.update_image(image)


func _ready() -> void:
	stage_pos = 0
	var base_rng := RandomNumberGenerator.new()
	base_rng.seed = OS.get_system_time_msecs()  # Fix this value for repeatability
	
	var base_grid := BaseGrid.new(CELL_EDGE, rect_size, GRID_COLOR)
	var island_cells_target : int = (base_grid.get_cell_count() / 3)
	var land_blob := TriBlob.new(base_grid, LAND_COLOR, COAST_COLOR, island_cells_target, base_rng.randi())
	var mouse_tracker := MouseTracker.new(base_grid, CURSOR_COLOR)
	var region_manager := RegionManager.new(land_blob, REGION_COLORS, base_rng.randi())
	var sub_regions_manager := SubRegionManager.new(region_manager, SUB_REGION_COLORS, base_rng.randi())
	var height_manager := PointHeightsManager.new(base_grid, land_blob, sub_regions_manager, Color8(255,255,255,255))
#	var river_manager := RiverManager.new(base_grid, sub_regions_manager, RIVER_COUNT, RIVER_COLOR, LAKE_COLOR, base_rng.randi())
	
	stages = [
		base_grid,
		land_blob,
		region_manager,
		sub_regions_manager,
		height_manager,
#		river_manager,
		mouse_tracker
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
		image.fill(BASE_COLOR)
	
	# Play the current stage ontop of the previous image
	var current_stage: Stage = stages[stage_pos]
	current_stage.update_mouse_coords(get_viewport().get_mouse_position())
	status_label.bbcode_text = current_stage.status_text()
	var return_after: float = OS.get_ticks_msec() + FRAME_DATA_TIME_MILLIS
	current_stage.update_data_tick(return_after)
	current_stage.update_image(image)
	imageTexture.create_from_image(image)
	texture = imageTexture

	# Advance to the next stage if the current is complete and there are more stages
	if stage_pos < len(stages) - 1 and current_stage.update_complete(): 
		stage_pos += 1
