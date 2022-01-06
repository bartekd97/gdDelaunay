extends Reference

class_name Delaunay

# ==== CLASSES ====

class Edge:
	var a: Vector2
	var b: Vector2
	
	func _init(a: Vector2, b: Vector2):
		self.a = a
		self.b = b
		
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
	
	func _init(a: Vector2, b: Vector2, c: Vector2):
		self.a = a
		self.b = b
		self.c = c
		edge_ab = Edge.new(a,b)
		edge_bc = Edge.new(b,c)
		edge_ca = Edge.new(c,a)
		recalculate_circumcircle()
		
		
	func recalculate_circumcircle() -> void:
		var sA2 = sin(angle(a, b, c) * 2)
		var sB2 = sin(angle(b, a, c) * 2)
		var sC2 = sin(angle(c, a, b) * 2)
		
		var xNum = a.x * sA2 + b.x * sB2 + c.x * sC2
		var yNum = a.y * sA2 + b.y * sB2 + c.y * sC2
		var den = sA2 + sB2 + sC2
		
		center = Vector2(xNum / den, yNum / den)
		radius_sqr = center.distance_squared_to(a)
	
	func angle(corner: Vector2, a: Vector2, b: Vector2) -> float:
		var ca = corner.direction_to(a)
		var cb = corner.direction_to(b)
		var dot = ca.dot(cb)
		return acos(dot)
		
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
	var polygon: PoolVector2Array # points in absolute position, clockwise
	var source_triangles: Array # of Triangle's that create this site internally
	var neightbours: Array # of VoronoiEdge
	
	func _init(center: Vector2):
		self.center = center
		
	func _sort_source_triangles(a: Triangle, b: Triangle) -> bool:
		var da = center.direction_to(a.center).angle()
		var db = center.direction_to(b.center).angle()
		return da < db # clockwise sort
		
	func get_relative_polygon() -> PoolVector2Array: # return points in relative position to center
		var polygon_local: PoolVector2Array
		for point in polygon:
			polygon_local.append(point - center)
		return polygon_local


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


# ==== PUBLIC VARIABLES ====
var points: PoolVector2Array


# ==== PRIVATE VARIABLES ====
var _rect: Rect2
var _rect_corners: Array
var _rect_triangle1: Triangle
var _rect_triangle2: Triangle


# ==== CONSTRUCTOR ====
func _init(rect: Rect2):
	# calcualte and cache triangles for super rectangle
	var c0 = Vector2(rect.position)
	var c1 = Vector2(rect.position + Vector2(rect.size.x,0))
	var c2 = Vector2(rect.position + Vector2(0,rect.size.y))
	var c3 = Vector2(rect.end)
	_rect = rect
	_rect_corners.append_array([c0,c1,c2,c3])
	_rect_triangle1 = Triangle.new(c0,c1,c2)
	_rect_triangle2 = Triangle.new(c1,c2,c3)


# ==== PUBLIC FUNCTIONS ====

func add_point(point: Vector2) -> void:
	points.append(point)


func is_border_triangle(triangle: Triangle) -> bool:
	return _rect_corners.has(triangle.a) || _rect_corners.has(triangle.b) || _rect_corners.has(triangle.c)


func remove_border_triangles(triangulation: Array) -> void:
	var border_triangles: Array
	for triangle in triangulation:
		if is_border_triangle(triangle):
			border_triangles.append(triangle)
	for border_triangle in border_triangles:
		triangulation.erase(border_triangle)


func triangulate() -> Array: # of Triangle
	var triangulation: Array # of Triangle
	
	triangulation.append(_rect_triangle1)
	triangulation.append(_rect_triangle2)
	
	var bad_triangles: Array # of Triangle
	var polygon: Array # of Edge
	
	for point in points:
		bad_triangles.clear()
		polygon.clear()
		
		_find_bad_triangles(point, triangulation, bad_triangles)
		for bad_tirangle in bad_triangles:
			triangulation.erase(bad_tirangle)
			
		_make_outer_polygon(bad_triangles, polygon)
		for edge in polygon:
			triangulation.append(Triangle.new(point, edge.a, edge.b))
			
	return triangulation



func make_voronoi(triangulation: Array) -> Array: # of VoronoiSite
	var sites: Array

	var completion_counter: Array # of Vector2, no PoolVector2Array to allow more oeprations
	var triangle_usage: Dictionary # of Triangle and Array[VoronoiSite], used for neightbour scan
	for triangle in triangulation:
		triangle_usage[triangle] = []
		
	for point in points:
		var site = VoronoiSite.new(point)
		
		completion_counter.clear()
		
		for triangle in triangulation:
			if !triangle.is_corner(point):
				continue
			
			site.source_triangles.append(triangle)
			
			var edge = triangle.get_corner_opposite_edge(point)
			completion_counter.erase(edge.a)
			completion_counter.erase(edge.b)
			completion_counter.append(edge.a)
			completion_counter.append(edge.b)
		
		var is_complete = completion_counter.size() == site.source_triangles.size()
		if !is_complete:
			continue # do not add sites without complete polygon, usually only corner sites than come from Rect boundary
		
		site.source_triangles.sort_custom(site, "_sort_source_triangles")
		
		var polygon: PoolVector2Array
		for triangle in site.source_triangles:
			polygon.append(triangle.center)
			triangle_usage[triangle].append(site)
		
		site.polygon = polygon	
		sites.append(site)
		
		
	# scan for neightbours
	for site in sites:
		for triangle in site.source_triangles:
			var posibilities = triangle_usage[triangle]
			var neightbour = _find_voronoi_neightbour(site, triangle, posibilities)
			if neightbour != null:
				site.neightbours.append(neightbour)
	
	return sites	
	
	
	
# ==== PRIVATE FUNCTIONS ====
	
func _make_outer_polygon(triangles: Array, out_polygon: Array) -> void:
	var duplicates: Array # of Edge
	
	for triangle in triangles:
		out_polygon.append(triangle.edge_ab)
		out_polygon.append(triangle.edge_bc)
		out_polygon.append(triangle.edge_ca)
		
	for edge1 in out_polygon:
		for edge2 in out_polygon:
			if edge1 != edge2 && edge1.equals(edge2):
				duplicates.append(edge1)
				duplicates.append(edge2)
				
	for edge in duplicates:
		out_polygon.erase(edge)
		
	
func _find_bad_triangles(point: Vector2, triangles: Array, out_bad_triangles: Array) -> void:
	for triangle in triangles:
		if triangle.is_point_inside_circumcircle(point):
			out_bad_triangles.append(triangle)
			
			
func _find_voronoi_neightbour(site: VoronoiSite, triangle: Triangle, possibilities: Array) -> VoronoiEdge:
	var opposite_edge = triangle.get_corner_opposite_edge(site.center)
	var angle_a = site.center.direction_to(opposite_edge.a).angle()
	var angle_b = site.center.direction_to(opposite_edge.b).angle()
	var nb_point = opposite_edge.b
	if angle_a < angle_b:
		nb_point = opposite_edge.a
		
	var triangle_index = site.source_triangles.find(triangle)
	var next_triangle_index = triangle_index + 1
	if (next_triangle_index == site.source_triangles.size()):
		next_triangle_index = 0
	var next_triangle = site.source_triangles[next_triangle_index]
		
	for pos_site in possibilities:
		if pos_site.center != nb_point:
			continue
		
		var edge = VoronoiEdge.new()
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
	var a = maxp.x - minp.x
	var b = maxp.y - minp.y
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
	var b2 = b * 0.5
	var a4 = a * 0.25
	
	var p1 = Vector2((minp.x + maxp.x) * 0.5, minp.y - b2)
	var p2 = Vector2(minp.x - a4, maxp.y)
	var p3 = Vector2(maxp.x + a4, maxp.y)
		
	return Triangle.new(p1, p2, p3)
	
