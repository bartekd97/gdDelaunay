extends Resource
class_name Delaunay

# ==== CLASSES ====

class Edge:
	var a: Vector2
	var b: Vector2

	func _init(a_: Vector2, b_: Vector2):
		self.a = a_
		self.b = b_

	func equals(edge: Edge) -> bool:
		return (a == edge.a && b == edge.b) || (a == edge.b && b == edge.a)

	func length() -> float:
		return a.distance_to(b)

	func center() -> Vector2:
		return (a + b) * 0.5


class Triangle:
	var a: Vector2
	var b: Vector2
	var c: Vector2

	var edge_ab: Edge
	var edge_bc: Edge
	var edge_ca: Edge

	var center: Vector2
	var radius_sqr: float

	func _init(a_: Vector2, b_: Vector2, c_: Vector2):
		self.a = a_
		self.b = b_
		self.c = c_
		edge_ab = Edge.new(a,b)
		edge_bc = Edge.new(b,c)
		edge_ca = Edge.new(c,a)
		recalculate_circumcircle()


	func recalculate_circumcircle() -> void:
		var ab := a.length_squared()
		var cd := b.length_squared()
		var ef := c.length_squared()

		var cmb := c - b
		var amc := a - c
		var bma := b - a

		var circum := Vector2(
			(ab * cmb.y + cd * amc.y + ef * bma.y) / (a.x * cmb.y + b.x * amc.y + c.x * bma.y),
			(ab * cmb.x + cd * amc.x + ef * bma.x) / (a.y * cmb.x + b.y * amc.x + c.y * bma.x)
		)

		center = circum * 0.5
		radius_sqr = a.distance_squared_to(center)

	func is_point_inside_circumcircle(point: Vector2) -> bool:
		return center.distance_squared_to(point) < radius_sqr

	func is_corner(point: Vector2) -> bool:
		return point == a || point == b || point == c

	func get_corner_opposite_edge(corner: Vector2) -> Edge:
		if corner == a:
			return edge_bc
		elif corner == b:
			return edge_ca
		elif corner == c:
			return edge_ab
		else:
			return null


class VoronoiSite:
	var center: Vector2
	var polygon: PackedVector2Array # points in absolute position, clockwise
	var source_triangles: Array[Triangle] # Triangle's that create this site internally
	var neighbours: Array[VoronoiEdge]

	func _init(center_: Vector2):
		self.center = center_

	func _sort_source_triangles(a: Triangle, b: Triangle) -> bool:
		var da := center.direction_to(a.center).angle()
		var db := center.direction_to(b.center).angle()
		return da < db # clockwise sort

	func get_relative_polygon() -> PackedVector2Array: # return points in relative position to center
		var polygon_local: PackedVector2Array = []
		for point in polygon:
			polygon_local.append(point - center)
		return polygon_local

	func get_boundary() -> Rect2:
		var rect := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			rect = rect.expand(point)
		return rect


class VoronoiEdge:
	var a: Vector2
	var b: Vector2
	var this: VoronoiSite
	var other: VoronoiSite

	func equals(edge: VoronoiEdge) -> bool:
		return (a == edge.a && b == edge.b) || (a == edge.b && b == edge.a)

	func length() -> float:
		return a.distance_to(b)

	func center() -> Vector2:
		return (a + b) * 0.5

	func normal() -> Vector2:
		return a.direction_to(b).orthogonal()


# ==== PUBLIC STATIC FUNCTIONS ====

# calculates rect that contains all given points
static func calculate_rect(points_: PackedVector2Array, padding: float = 0.0) -> Rect2:
	var rect := Rect2(points_[0], Vector2.ZERO)
	for point in points_:
		rect = rect.expand(point)
	return rect.grow(padding)


# ==== PUBLIC VARIABLES ====
var points: PackedVector2Array


# ==== PRIVATE VARIABLES ====
var _rect: Rect2
var _rect_super: Rect2
var _rect_super_corners: Array[Vector2]
var _rect_super_triangle1: Triangle
var _rect_super_triangle2: Triangle


# ==== CONSTRUCTOR ====
func _init(rect := Rect2()):
	if (rect.has_area()):
		set_rectangle(rect)


# ==== PUBLIC FUNCTIONS ====
func add_point(point: Vector2) -> void:
	points.append(point)


func set_rectangle(rect: Rect2) -> void:
	_rect = rect # save original rect

	# we expand rect to super rect to make sure
	# all future points won't be too close to broder
	var rect_max_size = max(_rect.size.x, _rect.size.y)
	_rect_super = _rect.grow(rect_max_size * 1)

	# calcualte and cache triangles for super rectangle
	var c0 := Vector2(_rect_super.position)
	var c1 := Vector2(_rect_super.position + Vector2(_rect_super.size.x,0))
	var c2 := Vector2(_rect_super.position + Vector2(0,_rect_super.size.y))
	var c3 := Vector2(_rect_super.end)
	_rect_super_corners.append_array([c0,c1,c2,c3])
	_rect_super_triangle1 = Triangle.new(c0,c1,c2)
	_rect_super_triangle2 = Triangle.new(c1,c2,c3)


func is_border_triangle(triangle: Triangle) -> bool:
	return _rect_super_corners.has(triangle.a) || _rect_super_corners.has(triangle.b) || _rect_super_corners.has(triangle.c)


func remove_border_triangles(triangulation: Array[Triangle]) -> void:
	var border_triangles: Array[Triangle] = []
	for triangle in triangulation:
		if is_border_triangle(triangle):
			border_triangles.append(triangle)
	for border_triangle in border_triangles:
		triangulation.erase(border_triangle)


func is_border_site(site: VoronoiSite) -> bool:
	return !_rect.encloses(site.get_boundary())

### XN: Helper function to get the site polygons or if the site is a border site, get the clipped polygon.
func get_polygon_site(site: VoronoiSite) -> PackedVector2Array:
	if !is_border_site(site):
		return site.polygon

	# reconstruct the bounding rectangle into polygon
	var bound_rect = PackedVector2Array([
		_rect.position,
		_rect.position + Vector2(_rect.size.x, 0),
		_rect.end,
		_rect.position + Vector2(0, _rect.size.y),
		])

	var intersects = Geometry2D.intersect_polygons(site.polygon, bound_rect)
	if intersects.size() > 1 :
		print_debug("Warning: more than 1 intersect areas, return the first intersect area")

	return intersects[0]

func remove_border_sites(sites: Array[VoronoiSite]) -> void:
	var border_sites: Array[VoronoiSite] = []
	for site in sites:
		if is_border_site(site):
			border_sites.append(site)
	for border_site in border_sites:
		sites.erase(border_site)


func triangulate() -> Array[Triangle]:
	var triangulation: Array[Triangle] = []

	# calculate rectangle if none
	if !(_rect.has_area()):
		set_rectangle(calculate_rect(points))

	triangulation.append(_rect_super_triangle1)
	triangulation.append(_rect_super_triangle2)

	var bad_triangles: Array[Triangle] =[]
	var polygon: Array[Edge] = []

	for point in points:
		var local_bad_triangles := _find_bad_triangles(point, triangulation)
		for bad_triangle in local_bad_triangles:
			var circum_center := bad_triangle.center
			triangulation.erase(bad_triangle)

		var local_polygon := _make_outer_polygon(local_bad_triangles)
		for edge in local_polygon:
			triangulation.append(Triangle.new(point, edge.a, edge.b))

	return triangulation


func make_voronoi(triangulation: Array[Triangle]) -> Array[VoronoiSite]:
	var sites: Array[VoronoiSite] = []
	var completion_counter: Array[Vector2] = []# no PackedVector2Array to allow more oeprations
	var triangle_usage: Dictionary = {} # { Triangle : Array[VoronoiSite] }, used for neighbour scan
	for triangle in triangulation:
		triangle_usage[triangle] = []

	for point in points:
		var site := VoronoiSite.new(point)

		completion_counter.clear()

		for triangle in triangulation:
			if not triangle.is_corner(point):
				continue

			site.source_triangles.append(triangle)

			var edge: Edge = triangle.get_corner_opposite_edge(point)
			completion_counter.erase(edge.a)
			completion_counter.erase(edge.b)
			completion_counter.append(edge.a)
			completion_counter.append(edge.b)

		var is_complete := completion_counter.size() == site.source_triangles.size()
		if not is_complete:
			continue # do not add sites without complete polygon, usually only corner sites than come from Rect boundary

		var sort_func := Callable(site, "_sort_source_triangles")
		sort_func.bind(site.source_triangles)
		site.source_triangles.sort_custom(sort_func)
		#site.source_triangles.sort_custom(site, "_sort_source_triangles")

		var polygon: PackedVector2Array = []
		for triangle in site.source_triangles:
			polygon.append(triangle.center)
			triangle_usage[triangle].append(site)

		site.polygon = polygon
		sites.append(site)

	# scan for neighbours
	for site in sites:
		for triangle in site.source_triangles:
			var posibilities: Array[VoronoiSite] = triangle_usage[triangle]
			var neighbour := _find_voronoi_neighbour(site, triangle, posibilities)
			if neighbour != null:
				site.neighbours.append(neighbour)

	return sites


# ==== PRIVATE FUNCTIONS ====
func _make_outer_polygon(triangles: Array[Triangle]) -> Array[Edge]:
	var result: Array[Edge] = []
	var duplicates: Array[Edge] = []

	for triangle in triangles:
		result.append(triangle.edge_ab)
		result.append(triangle.edge_bc)
		result.append(triangle.edge_ca)

	for e_1 in range(result.size()):
		for e_2 in range(e_1 + 1, result.size()):
			var edge1 := result[e_1]
			var edge2 := result[e_2]
			if edge1.equals(edge2):
				# duplicates.append(edge1) # Only one of them counts as a duplicate (?)
				duplicates.append(edge2)

	return result.filter(func(e: Edge): return not duplicates.has(e) )


func _find_bad_triangles(point: Vector2, triangles: Array[Triangle]) -> Array[Triangle]:
	return triangles.filter(func(t: Triangle): return t.is_point_inside_circumcircle(point))


func _find_voronoi_neighbour(site: VoronoiSite, triangle: Triangle, possibilities: Array[VoronoiSite]) -> VoronoiEdge:
	var triangle_index := site.source_triangles.find(triangle)
	var next_triangle_index := wrapi(triangle_index + 1, 0, site.source_triangles.size())
	var next_triangle: Triangle = site.source_triangles[next_triangle_index]

	var opposite_edge := triangle.get_corner_opposite_edge(site.center)
	var opposite_edge_next := next_triangle.get_corner_opposite_edge(site.center)
	var common_point := opposite_edge.a
	if common_point != opposite_edge_next.a and common_point != opposite_edge_next.b:
		common_point = opposite_edge.b

	for pos_site in possibilities:
		if pos_site.center != common_point:
			continue

		var edge := VoronoiEdge.new()
		edge.a = triangle.center
		edge.b = next_triangle.center
		edge.this = site
		edge.other = pos_site
		return edge

	return null


# super triangle is not used since this method was giving worse results than super rectangle
# but I'm leaving this function because it works if someone needs it
func _calculate_super_triangle() -> Triangle:
	# calculate super rectangle
	var minp: Vector2 = points[0]
	var maxp: Vector2 = points[0]
	for point in points:
		minp.x = min(minp.x, point.x)
		minp.y = min(minp.y, point.y)
		maxp.x = max(maxp.x, point.x)
		maxp.y = max(maxp.y, point.y)

	# add extra safe space padding
	minp = minp - (maxp - minp) * 0.25
	maxp = maxp + (maxp - minp) * 0.25

	# extend rectangle to square
	var a := maxp.x - minp.x
	var b := maxp.y - minp.y
	var hd = abs(a - b) * 0.5
	if a > b:
		minp.y = minp.y - hd
		maxp.y = maxp.y + hd
		b = a
	elif a < b:
		minp.x = minp.x - hd
		maxp.x = maxp.x + hd
		a = b

	# make equilateral triangle that contains such square
	var b2 := b * 0.5
	var a4 := a * 0.25

	var p1 := Vector2((minp.x + maxp.x) * 0.5, minp.y - b2)
	var p2 := Vector2(minp.x - a4, maxp.y)
	var p3 := Vector2(maxp.x + a4, maxp.y)

	return Triangle.new(p1, p2, p3)
