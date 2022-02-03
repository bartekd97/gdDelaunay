# GDScript Delaunay + Voronoi
A [Bowyer-Watson](https://en.wikipedia.org/wiki/Bowyer–Watson_algorithm) algorithm implementation for [Delaunay triangulation](https://en.wikipedia.org/wiki/Delaunay_triangulation) for [Godot](https://godotengine.org).

Also generates [Voronoi](https://en.wikipedia.org/wiki/Voronoi_diagram) diagram from triangulation, including neightbour cells scanning.

Written as a single GDScript file.

![Preview](preview.png)


## How it works
Algorithm returns list of triangles for given set of points.

To calcualte it, Bowyer-Watson algorithm originally generates super-triangle that contains all points.
Unfortunetly, it wasn't giving good results on marginal points, so I've decided to implement "super-rectangle".
It means that you need to specify a ractangle, that will contains all points.

After that you can generate list of triangles, that will also contains **border triangles** - triangles that share rectange corner.
Those triangles improves Voronoi diagram generation but for triangulation you will most likely don't want them. You can remove them with `remove_border_triangles()` function or manually check `is_border_triangle()` while processing them in a loop.


## Example

Check [example.tscn](example.tscn) which is 2d scene with embedded full example script.

```GDScript
var delone = Delaunay.new(Rect2(0,0,1200,700))
for i in range(10):
  for j in range(10):
    delone.add_point(Vector2(50 + i*100 + rand_range(-15,15), 50 + j * 50 + rand_range(-15,15)))
    
var triangles = delone.triangulate()
for triangle in triangles:
  if !delone.is_border_triangle(triangle): # do not render border triangles
    show_triangle(triangle)
    
var sites = delone.make_voronoi(triangles)
for site in sites:
  show_site(site)
  if site.neightbours.size() == site.source_triangles.size(): # sites on edges will have incomplete neightbours information
    for neightbour_edge in site.neightbours:
      show_neightbour(neightbour_edge)
```


## Data structs / API

Check [source code](addons/gdDelaunay/Delaunay.gd) for more details

```GDScript
class_name Delaunay

# ==== CLASSES ====
class Edge: # Delaunay.Edge
	var a: Vector2
	var b: Vector2
	func equals(edge: Edge) -> bool
	func length() -> float
	func center() -> Vector2

class Triangle: # Delaunay.Triangle
	var a: Vector2
	var b: Vector2
	var c: Vector2
	var edge_ab: Edge
	var edge_bc: Edge
	var edge_ca: Edge
	var center: Vector2
	var radius_sqr: float
	func recalculate_circumcircle() -> void
	func angle(corner: Vector2, a: Vector2, b: Vector2) -> float
	func is_point_inside_circumcircle(point: Vector2) -> bool
	func is_corner(point: Vector2) -> bool
	func get_corner_opposite_edge(corner: Vector2) -> Edge

class VoronoiSite: # Delaunay.VoronoiSite
	var center: Vector2
	var polygon: PoolVector2Array # clockwise points in absolute position
	var source_triangles: Array # of Triangle's that create this site internally, also clockwise
	var neightbours: Array # of VoronoiEdge, also clockwise
	func get_relative_polygon() -> PoolVector2Array # clockwise points in relative position to center

class VoronoiEdge: # Delaunay.VoronoiEdge
	var a: Vector2
	var b: Vector2
	var this: VoronoiSite
	var other: VoronoiSite
	func equals(edge: Edge) -> bool
	func length() -> float
	func center() -> Vector2
  
  
# ==== PUBLIC STATIC FUNCTIONS ====
static func calculate_rect(points: PoolVector2Array) -> Rect2:
 
# ==== PUBLIC VARIABLES ====
var points: PoolVector2Array

# ==== CONSTRUCTOR ====
func _init(rect: Rect2) -> Delaunay

# ==== PUBLIC FUNCTIONS ====
func add_point(point: Vector2) -> void
func is_border_triangle(triangle: Triangle) -> bool
func remove_border_triangles(triangulation: Array) -> void
func triangulate() -> Array # of Triangle
func make_voronoi(triangulation: Array) -> Array # of VoronoiSite
```


## To Do

- [ ] Implement [Lloyd's relaxation algorithm](https://en.wikipedia.org/wiki/Lloyd%27s_algorithm)
- [ ] Automatically shrink border Voronoi cell polygons to rectangle border edges
