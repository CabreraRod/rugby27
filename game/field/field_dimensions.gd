class_name FieldDimensions
extends RefCounted
## Single source of truth for pitch geometry (World Rugby Law 1 maxima).
##
## Coordinate convention used everywhere in Rugby 27:
##   +X  along the pitch (try line to try line). Halfway line at X = 0.
##   +Z  across the pitch (touchline to touchline). Centre at Z = 0.
##   +Y  up. Pitch surface at Y = 0.

const HALF_LENGTH := 50.0        ## Halfway -> try line (100 m field of play).
const IN_GOAL := 10.0            ## Try line -> dead-ball line.
const HALF_WIDTH := 35.0         ## Centre -> touchline (70 m wide).
const LINE_22_FROM_TRY := 22.0
const LINE_10_FROM_HALFWAY := 10.0
const LINE_5_FROM_TRY := 5.0
const LINE_5_FROM_TOUCH := 5.0
const LINE_15_FROM_TOUCH := 15.0
const LINE_WIDTH := 0.12

const POST_GAP := 5.6            ## Inside distance between uprights.
const CROSSBAR_HEIGHT := 3.0
const POST_HEIGHT := 13.0
const POST_RADIUS := 0.09


static func dead_ball_x() -> float:
	return HALF_LENGTH + IN_GOAL


static func line_22_x() -> float:
	return HALF_LENGTH - LINE_22_FROM_TRY


## True if a ground point is inside the field of play (touchlines/try lines excluded).
static func in_field_of_play(p: Vector2) -> bool:
	return absf(p.x) < HALF_LENGTH and absf(p.y) < HALF_WIDTH


## True if inside the playing enclosure (field of play + in-goals).
static func in_playing_area(p: Vector2) -> bool:
	return absf(p.x) < dead_ball_x() and absf(p.y) < HALF_WIDTH
