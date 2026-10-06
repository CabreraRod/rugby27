class_name TackleModel
extends RefCounted
## Pure tackle resolution. No nodes; seeded RNG; unit-tested.
##
## A tackle compares the tackler's POWER with the carrier's RESISTANCE:
##   power      = mass^0.7 × (brace + speed_weight × closing speed) × skill × angle × dive × sidestep
##   resistance = mass^0.7 × (brace + speed_weight × carrier speed)  × strength × fend
## score = ln(power / resistance)
##   P(break)    = logistic(steep × (center − score))   clamped [break_min, break_max]
##   P(dominant) = (score − dominant_start) × slope      clamped [0, dominant_max], if held
##
## "brace" makes technique matter more than raw speed (a set defender stops
## a sprinter most of the time), mass^0.7 makes forwards matter without
## making them unstoppable. Calibrated: typical back-on-back break ~9 %,
## carrier sprinting ~17 %, prop carrying into a wing ~30 %.

enum Outcome { DOMINANT, HELD, BROKEN }


class Contact:
	var tackler_mass := 95.0
	var tackler_vel := Vector2.ZERO
	var tackler_pos := Vector2.ZERO
	var tackling := 0.7      ## attribute 0..1
	var carrier_mass := 90.0
	var carrier_vel := Vector2.ZERO
	var carrier_pos := Vector2.ZERO
	var strength := 0.7      ## attribute 0..1
	var dive := false
	var fend := false        ## carrier fending, effective vs. front/side tackles
	var sidestep := false    ## carrier mid-sidestep: tackler wrong-footed


class Result:
	var outcome: Outcome = Outcome.HELD
	var p_break := 0.0
	var p_dominant := 0.0
	var score := 0.0
	## -1 = carrier runs into the tackler head-on, 0 = side, +1 = from behind.
	var approach := 0.0
	var spill := false


static func contact_mass(kg: float, t: TackleTuning) -> float:
	return pow(maxf(kg, 40.0) / t.mass_ref, t.mass_exp)


## -1 head-on .. 0 side .. +1 from behind (relative to the carrier's run).
static func approach(inp: Contact) -> float:
	var run := inp.carrier_vel
	if run.length() < 0.5:
		return 0.0
	var to_tackler := (inp.tackler_pos - inp.carrier_pos)
	if to_tackler.length() < 0.01:
		return 0.0
	return -run.normalized().dot(to_tackler.normalized())


static func angle_mult(appr: float, t: TackleTuning) -> float:
	if appr < -0.5:
		return t.headon_mult
	if appr > 0.5:
		return t.behind_mult
	return t.side_mult


static func evaluate(inp: Contact, t: TackleTuning) -> Result:
	var r := Result.new()
	r.approach = approach(inp)
	var n := inp.carrier_pos - inp.tackler_pos
	n = n.normalized() if n.length() > 0.01 else inp.tackler_vel.normalized()
	var closing := maxf(0.0, inp.tackler_vel.dot(n))
	var skill := lerpf(t.skill_min, t.skill_max, inp.tackling)
	var strength := lerpf(t.strength_min, t.strength_max, inp.strength)
	var power := contact_mass(inp.tackler_mass, t) * (t.brace + t.speed_weight * closing) * skill * angle_mult(r.approach, t)
	if inp.dive:
		power *= t.dive_power_mult
	if inp.sidestep:
		power *= t.sidestep_power_mult
	var resist := contact_mass(inp.carrier_mass, t) * (t.brace + t.speed_weight * inp.carrier_vel.length()) * strength
	if inp.fend and r.approach < 0.5:
		resist *= t.fend_mult
	r.score = log(power / maxf(resist, 0.001))
	r.p_break = clampf(1.0 / (1.0 + exp(t.break_steep * (r.score - t.break_center))), t.break_min, t.break_max)
	r.p_dominant = clampf((r.score - t.dominant_start) * t.dominant_slope, 0.0, t.dominant_max)
	return r


static func resolve(inp: Contact, rng: RandomNumberGenerator, t: TackleTuning) -> Result:
	var r := evaluate(inp, t)
	if rng.randf() < r.p_break:
		r.outcome = Outcome.BROKEN
		return r
	r.outcome = Outcome.DOMINANT if rng.randf() < r.p_dominant else Outcome.HELD
	var spill_p := t.spill_dominant if r.outcome == Outcome.DOMINANT else t.spill_normal
	r.spill = rng.randf() < spill_p
	return r


## Carrier velocity right after the tackle (the slide as they go down, or
## the stumble when breaking through).
static func carrier_velocity_after(outcome: Outcome, carrier_vel: Vector2, tackler_vel: Vector2, t: TackleTuning) -> Vector2:
	match outcome:
		Outcome.BROKEN:
			return carrier_vel * t.broken_keep
		Outcome.DOMINANT:
			# Driven back: the tackler's momentum wins.
			var back := tackler_vel.normalized() * carrier_vel.length() * absf(t.dominant_slide)
			return back if tackler_vel.length() > 0.5 else carrier_vel * t.dominant_slide
		_:
			return carrier_vel * t.normal_slide
