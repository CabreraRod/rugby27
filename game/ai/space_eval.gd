class_name SpaceEval
extends RefCounted
## Pure spatial reasoning for the AI: where is the space, where are the
## gaps, is a passing lane safe, where can a chaser intercept a runner.
## Works on ground-plane positions; no nodes.


## How much room there is running from `from` along `dir`: the smallest
## "clearance" over defenders ahead, where clearance = distance of the
## defender from the running line + half its distance down the line
## (a defender far ahead and off the line is not yet a problem).
static func ray_space(from: Vector2, dir: Vector2, defenders: Array[Vector2], max_range: float) -> float:
	var best := max_range
	for d in defenders:
		var rel := d - from
		var along := rel.dot(dir)
		if along < -1.0 or along > max_range:
			continue
		var off := absf(rel.dot(Vector2(-dir.y, dir.x)))
		best = minf(best, off + maxf(along, 0.0) * 0.5)
	return best


## Best running direction around `attack` (±max_angle, `steps` rays).
## Returns [dir, score]. Penalises lines that run into touch.
static func best_line(from: Vector2, attack: Vector2, defenders: Array[Vector2], max_angle_deg: float, steps: int, max_range: float, straight_bias: float, touch_avoid: float) -> Array:
	var best_dir := attack
	var best_score := -INF
	for i in steps:
		var a := deg_to_rad(lerpf(-max_angle_deg, max_angle_deg, float(i) / float(maxi(steps - 1, 1))))
		var dir := attack.rotated(a)
		var score := ray_space(from, dir, defenders, max_range) + straight_bias * dir.dot(attack) * 2.0
		var end := from + dir * 8.0
		var to_touch := FieldDimensions.HALF_WIDTH - absf(end.y)
		if to_touch < touch_avoid:
			score -= (touch_avoid - to_touch) * 1.5
		if score > best_score:
			best_score = score
			best_dir = dir
	return [best_dir, best_score]


## Distance from the nearest defender to point p.
static func space_at(p: Vector2, defenders: Array[Vector2]) -> float:
	var best := INF
	for d in defenders:
		best = minf(best, d.distance_to(p))
	return best


## Smallest distance from any defender to the segment a-b (a passing lane).
static func lane_clearance(a: Vector2, b: Vector2, defenders: Array[Vector2]) -> float:
	var best := INF
	var ab := b - a
	var len2 := maxf(ab.length_squared(), 0.0001)
	for d in defenders:
		var t := clampf((d - a).dot(ab) / len2, 0.15, 1.0)   # ignore defenders on the passer
		best = minf(best, d.distance_to(a + ab * t))
	return best


## Lateral centre of the widest gap between defenders near `lateral`
## (positions projected on the axis `side`), or NAN if none in the window.
static func gap_near(lateral: float, side: Vector2, defenders: Array[Vector2], window: float) -> float:
	var lats: Array[float] = []
	for d in defenders:
		lats.append(d.dot(side))
	lats.sort()
	var best_center := NAN
	var best_width := 0.0
	for i in lats.size() - 1:
		var lo := lats[i]
		var hi := lats[i + 1]
		var center := (lo + hi) * 0.5
		if absf(center - lateral) > window:
			continue
		if hi - lo > best_width:
			best_width = hi - lo
			best_center = center
	return best_center


## Time for a chaser (max speed s) to intercept a runner at c moving with v,
## or -1 if he can't. Solves |c + v t − p| = s t.
static func intercept_time(p: Vector2, s: float, c: Vector2, v: Vector2) -> float:
	var d := c - p
	var a := v.dot(v) - s * s
	var b := 2.0 * v.dot(d)
	var cc := d.dot(d)
	if absf(a) < 0.0001:
		return -cc / b if b < 0.0 else -1.0
	var disc := b * b - 4.0 * a * cc
	if disc < 0.0:
		return -1.0
	var sq := sqrt(disc)
	var t1 := (-b - sq) / (2.0 * a)
	var t2 := (-b + sq) / (2.0 * a)
	var t := INF
	for x in [t1, t2]:
		if x > 0.0 and x < t:
			t = x
	return t if t < INF else -1.0


static func positions(players: Array[RugbyPlayer], only_standing: bool = true) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in players:
		if only_standing and not (p.is_controllable() or p.is_diving()):
			continue
		out.append(p.planar_position())
	return out
