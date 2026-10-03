// Procedural rugby pitch: mowing stripes, grass variation and all markings
// drawn analytically in world space (crisp at any distance, zero textures).
// Geometry uniforms are set from FieldDimensions by FieldBuilder.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 grass_light : source_color = vec3(0.30, 0.55, 0.21);
uniform vec3 grass_dark : source_color = vec3(0.24, 0.47, 0.17);
uniform vec3 in_goal_tint : source_color = vec3(0.96, 1.0, 0.96);
uniform vec3 surround_grass : source_color = vec3(0.19, 0.38, 0.15);
uniform vec3 apron_color : source_color = vec3(0.30, 0.30, 0.31);
uniform vec3 line_color : source_color = vec3(0.94, 0.95, 0.93);

uniform float half_length = 50.0;
uniform float in_goal = 10.0;
uniform float half_width = 35.0;
uniform float line_22_x = 28.0;
uniform float line_10_x = 10.0;
uniform float line_5_try = 5.0;
uniform float line_5_touch = 5.0;
uniform float line_15_touch = 15.0;
uniform float line_width = 0.12;
uniform float stripe_width = 5.0;
uniform float surround_margin = 7.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Anti-aliased band of width w centred on c along coordinate v.
float band(float v, float c, float w) {
	float d = abs(v - c);
	float aa = max(fwidth(v), 0.0001);
	return 1.0 - smoothstep(w * 0.5 - aa, w * 0.5 + aa, d);
}

float within(float v, float lo, float hi) {
	return step(lo, v) * step(v, hi);
}

float dashes(float v, float period, float duty) {
	return step(fract(v / period), duty);
}

void fragment() {
	vec2 p = wpos.xz;
	float dead = half_length + in_goal;
	float ax = abs(p.x);
	float az = abs(p.y);
	float w = line_width;

	float n = vnoise(p * 0.45) * 0.5 + vnoise(p * 2.7) * 0.3 + vnoise(p * 11.0) * 0.2;

	// Mowing stripes across the pitch, every stripe_width metres.
	float stripe = mod(floor((p.x + dead) / stripe_width), 2.0);
	vec3 grass = mix(grass_dark, grass_light, stripe) * (0.9 + 0.2 * n);
	grass *= mix(vec3(1.0), in_goal_tint, step(half_length, ax));

	float inside = within(ax, 0.0, dead) * within(az, 0.0, half_width);
	float near = within(ax, 0.0, dead + surround_margin) * within(az, 0.0, half_width + surround_margin);
	vec3 col = mix(surround_grass * (0.88 + 0.24 * n), grass, inside);
	col = mix(apron_color * (0.92 + 0.12 * n), col, near);

	float on_width = within(az, 0.0, half_width + w * 0.5);
	float on_length = within(ax, 0.0, dead + w * 0.5);

	float L = 0.0;
	L = max(L, band(az, half_width, w) * on_length);                       // touchlines / touch-in-goal
	L = max(L, band(ax, dead, w) * on_width);                              // dead-ball lines
	L = max(L, band(ax, half_length, w) * on_width);                       // try lines
	L = max(L, band(ax, line_22_x, w) * on_width);                         // 22 m lines
	L = max(L, band(p.x, 0.0, w) * on_width);                              // halfway
	L = max(L, band(ax, line_10_x, w) * on_width * dashes(p.y, 2.0, 0.5)); // 10 m (dashed)
	// 5 m from try line (dashed, stops short of the touch zones).
	L = max(L, band(ax, half_length - line_5_try, w) * dashes(p.y, 1.0, 0.5) * within(az, 0.0, half_width - line_15_touch));
	// 5 m and 15 m lines parallel to touch (dashed).
	float inner = within(ax, 0.0, half_length - line_5_try);
	L = max(L, band(az, half_width - line_5_touch, w) * inner * dashes(p.x, 2.0, 0.35));
	L = max(L, band(az, half_width - line_15_touch, w) * inner * dashes(p.x, 2.0, 0.35));
	// Centre mark.
	L = max(L, band(p.y, 0.0, w) * within(ax, 0.0, 0.5));

	col = mix(col, line_color, L * near);
	ALBEDO = col;
	ROUGHNESS = mix(0.93, 0.7, L);
	SPECULAR = 0.2;
}
