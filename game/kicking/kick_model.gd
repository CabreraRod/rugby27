class_name KickModel
extends RefCounted
## Pure kicking maths (no nodes, deterministic, unit-tested).
##
## Rugby 08 style: hold to charge, release to kick. The charge sets the
## distance (between a minimum and the kicker's full range, which grows with
## his kicking attribute); the kicking attribute also sets accuracy.
##   LONG (✕)  — flat, long: clearances, touch-finders.
##   HIGH (□)  — a parabola: up and under.
##   LOW  (△)  — a grubber driven into the ground.
##   BOX  (△ by the 9 at the base of a ruck) — a steep box kick.
##   DROP (○)  — at the posts; the charge has a sweet spot: too little
##               falls short, too much flies wide.
## Flights are simulated with the same gravity + air damping as the ball,
## so the arrow and the AI see where a kick will really land.

enum Type { LONG, HIGH, LOW, DROP, BOX }

const STEP := 1.0 / 60.0


class Flight:
	var landing := Vector2.ZERO        ## first touch of the ground
	var flight_time := 0.0
	var apex := 0.0
	var catch_point := Vector2.ZERO    ## where it comes down through catch height
	var catch_time := 0.0
	var has_catch := false


class Strike:
	var velocity := Vector3.ZERO
	var contact := Vector3.ZERO
	var aim := Vector2.ZERO            ## final direction after error
	var planned := 0.0                 ## planned distance (m)
	var drop_error := 0.0              ## drop: charge - sweet spot


static func type_name(t: Type) -> String:
	return ["LONG KICK", "HIGH KICK", "GRUBBER", "DROP GOAL", "BOX KICK"][t]


# --- flight ----------------------------------------------------------------------------

## Ballistic flight until the ball first reaches the ground.
static func simulate(p0: Vector3, v0: Vector3, damp: float, g: float, radius: float, catch_h: float = 1.5, max_time: float = 10.0) -> Flight:
	var f := Flight.new()
	var p := p0
	var v := v0
	var t := 0.0
	f.apex = p0.y
	while t < max_time:
		v.y -= g * STEP
		v *= maxf(0.0, 1.0 - damp * STEP)
		var np := p + v * STEP
		t += STEP
		f.apex = maxf(f.apex, np.y)
		if not f.has_catch and v.y < 0.0 and np.y <= catch_h and p.y > catch_h:
			var k := (p.y - catch_h) / maxf(p.y - np.y, 1e-6)
			var c := p.lerp(np, k)
			f.catch_point = Vector2(c.x, c.z)
			f.catch_time = t - STEP * (1.0 - k)
			f.has_catch = true
		if np.y <= radius:
			var k := (p.y - radius) / maxf(p.y - np.y, 1e-6)
			var l := p.lerp(np, clampf(k, 0.0, 1.0))
			f.landing = Vector2(l.x, l.z)
			f.flight_time = t - STEP * (1.0 - k)
			break
		p = np
	if not f.has_catch:
		f.catch_point = f.landing
		f.catch_time = f.flight_time
	return f


## Height (y) of the ball when it crosses the plane x = plane_x, or -INF if it lands first.
static func height_at_plane(p0: Vector3, v0: Vector3, damp: float, g: float, radius: float, plane_x: float) -> Vector2:
	var p := p0
	var v := v0
	var side := signf(plane_x - p0.x)
	for i in 900:
		v.y -= g * STEP
		v *= maxf(0.0, 1.0 - damp * STEP)
		var np := p + v * STEP
		if signf(plane_x - np.x) != side:
			var k := (plane_x - p.x) / maxf(absf(np.x - p.x), 1e-6) * side
			var c := p.lerp(np, clampf(k, 0.0, 1.0))
			return Vector2(c.y, c.z)
		if np.y <= radius:
			return Vector2(-INF, np.z)
		p = np
	return Vector2(-INF, p.z)


static func launch(dir: Vector2, angle_deg: float, speed: float) -> Vector3:
	var a := deg_to_rad(angle_deg)
	var h := dir.normalized() * speed * cos(a)
	return Vector3(h.x, speed * sin(a), h.y)


## Launch speed that lands the ball `dist` metres away (horizontally).
static func solve_speed(p0: Vector3, dir: Vector2, angle_deg: float, dist: float, damp: float, g: float, radius: float) -> float:
	var lo := 0.5
	var hi := 60.0
	for i in 32:
		var mid := (lo + hi) * 0.5
		var f := simulate(p0, launch(dir, angle_deg, mid), damp, g, radius)
		var d := f.landing.distance_to(Vector2(p0.x, p0.z))
		if d < dist:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


# --- charge -> distance ---------------------------------------------------------------

static func angle_of(type: Type, t: KickTuning) -> float:
	match type:
		Type.HIGH:
			return t.high_angle
		Type.BOX:
			return t.box_angle
		Type.DROP:
			return t.drop_angle
	return t.long_angle


static func charge_time_of(type: Type, t: KickTuning) -> float:
	match type:
		Type.BOX:
			return t.box_charge_time
		Type.DROP:
			return t.drop_charge_time
	return t.charge_time


static func min_distance(type: Type, t: KickTuning) -> float:
	match type:
		Type.HIGH:
			return t.high_min
		Type.BOX:
			return t.box_min
	return t.long_min


static func max_distance(type: Type, kicking: float, t: KickTuning) -> float:
	var k := clampf(kicking, 0.0, 1.0)
	match type:
		Type.HIGH:
			return lerpf(t.high_max_lo, t.high_max_hi, k)
		Type.BOX:
			return lerpf(t.box_max_lo, t.box_max_hi, k)
	return lerpf(t.long_max_lo, t.long_max_hi, k)


## Planned distance for LONG / HIGH / BOX at a charge 0..1.
static func distance_for(type: Type, charge: float, kicking: float, t: KickTuning) -> float:
	return lerpf(min_distance(type, t), max_distance(type, kicking, t), clampf(charge, 0.0, 1.0))


## The charge an AI (or a test) needs for a distance.
static func charge_for(type: Type, dist: float, kicking: float, t: KickTuning) -> float:
	if type == Type.LOW:
		var top := lerpf(t.low_speed_lo, t.low_speed_hi, clampf(kicking, 0.0, 1.0))
		var sp := sqrt(maxf(dist, 0.0) * 2.0 * 2.4 / 0.8)
		return clampf((sp - t.low_speed_min) / maxf(top - t.low_speed_min, 0.01), 0.0, 1.0)
	var lo := min_distance(type, t)
	var hi := max_distance(type, kicking, t)
	return clampf((dist - lo) / maxf(hi - lo, 0.01), 0.0, 1.0)


## Grubber: horizontal speed off the boot.
static func low_speed(charge: float, kicking: float, t: KickTuning) -> float:
	return lerpf(t.low_speed_min, lerpf(t.low_speed_lo, t.low_speed_hi, clampf(kicking, 0.0, 1.0)), clampf(charge, 0.0, 1.0))


## Rough grubber run (flight + roll) for the arrow: bounces lose ~20 %.
static func low_distance(speed: float, roll_decel: float) -> float:
	return speed * speed / (2.0 * maxf(roll_decel, 0.1)) * 0.8


static func dir_error_sd(kicking: float, t: KickTuning) -> float:
	return lerpf(t.dir_err_lo, t.dir_err_hi, clampf(kicking, 0.0, 1.0))


static func dist_error_sd(kicking: float, t: KickTuning) -> float:
	return lerpf(t.dist_err_lo, t.dist_err_hi, clampf(kicking, 0.0, 1.0))


## Clamps an aim to within aim_max_deg of the attack direction.
static func clamp_aim(aim: Vector2, attack: Vector2, t: KickTuning) -> Vector2:
	if aim.length_squared() < 1e-6:
		return attack
	var a := attack.angle_to(aim)
	var m := deg_to_rad(t.aim_max_deg)
	return attack.rotated(clampf(a, -m, m))


# --- drop goal ---------------------------------------------------------------------------

## Half-width of the sweet spot around drop_sweet (charge units).
static func drop_window(kicking: float, dist: float, t: KickTuning) -> float:
	var w := lerpf(t.drop_window_lo, t.drop_window_hi, clampf(kicking, 0.0, 1.0))
	return w * clampf(t.drop_ref_dist / maxf(dist, 1.0), 0.6, 1.4)


## Speed at drop_angle that crosses the goal line at drop_clear metres.
static func drop_needed_speed(p0: Vector3, dir: Vector2, plane_x: float, damp: float, g: float, radius: float, t: KickTuning) -> float:
	var lo := 3.0
	var hi := 60.0
	for i in 32:
		var mid := (lo + hi) * 0.5
		var y := height_at_plane(p0, launch(dir, t.drop_angle, mid), damp, g, radius, plane_x).x
		if y < t.drop_clear:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


## The drop strike for a charge: [speed, yaw_deg]. In the window it flies
## between the posts; under-charged it hooks and falls short; over-charged
## it flies long and wide.
static func drop_strike(charge: float, kicking: float, dist: float, needed: float, rng: RandomNumberGenerator, t: KickTuning) -> Vector2:
	var e := charge - t.drop_sweet
	var w := drop_window(kicking, dist, t)
	# Inside the window the strike is clean; beyond it, short or long.
	var beyond := maxf(absf(e) - w, 0.0)
	var speed := needed * (1.0 - beyond * t.drop_short if e < 0.0 else 1.0 + beyond * t.drop_long)
	speed = minf(speed, lerpf(t.drop_max_speed_lo, t.drop_max_speed_hi, clampf(kicking, 0.0, 1.0)))
	# At the window edge the ball is aimed exactly at an upright.
	var to_post := rad_to_deg(atan((FieldDimensions.POST_GAP * 0.5) / maxf(dist, 1.0)))
	var yaw := (e / maxf(w, 0.001)) * to_post * 0.95 + rng.randfn(0.0, t.drop_noise_deg * (1.0 - 0.5 * kicking))
	return Vector2(speed, yaw)


## Did a ball crossing the goal line at (height, z) go over?
static func drop_good(height: float, z: float) -> bool:
	return height > FieldDimensions.CROSSBAR_HEIGHT and absf(z) < FieldDimensions.POST_GAP * 0.5


# --- catching --------------------------------------------------------------------------

## Chance to take a kick out of the air.
static func catch_chance(handling: float, catcher_speed: float, contested: bool, t: KickTuning) -> float:
	var p := lerpf(t.catch_base_lo, t.catch_base_hi, clampf(handling, 0.0, 1.0))
	if contested:
		p -= t.catch_contest_pen
	p -= t.catch_run_pen * clampf(catcher_speed / maxf(t.catch_run_speed, 0.1), 0.0, 1.0)
	return clampf(p, 0.05, 0.99)


# --- AI helpers ----------------------------------------------------------------------

## Direction for a kick of `dist` metres that lands `margin` beyond the
## nearer touchline (straight at touch if it's further than `dist`).
static func touch_aim(pos: Vector2, attack: Vector2, dist: float, margin: float) -> Vector2:
	var side := signf(pos.y) if absf(pos.y) > 0.5 else 1.0
	var lat := FieldDimensions.HALF_WIDTH + margin - absf(pos.y)
	if dist <= lat:
		return Vector2(0.0, side)
	var along := sqrt(dist * dist - lat * lat)
	return (attack * along + Vector2(0.0, side * lat)).normalized()
