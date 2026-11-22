shader_type canvas_item;
// Liquid iris transition. progress 0 = fully open, 1 = fully covered.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 curtain_color : source_color = vec4(0.16, 0.52, 0.68, 1.0);
uniform vec2 center = vec2(0.5, 0.5);
uniform float aspect = 0.5625;

float corner_dist(vec2 c) {
	float m = 0.0;
	m = max(m, length(vec2((0.0 - c.x) * aspect, 0.0 - c.y)));
	m = max(m, length(vec2((1.0 - c.x) * aspect, 0.0 - c.y)));
	m = max(m, length(vec2((0.0 - c.x) * aspect, 1.0 - c.y)));
	m = max(m, length(vec2((1.0 - c.x) * aspect, 1.0 - c.y)));
	return m;
}

void fragment() {
	vec2 d = UV - center;
	d.x *= aspect;
	float dist = length(d);
	float ang = atan(d.y, d.x);
	float maxd = corner_dist(center);

	float radius = mix(maxd + 0.10, -0.10, progress);
	float wobble = sin(ang * 6.0 + TIME * 5.0) * 0.014 + sin(ang * 11.0 - TIME * 3.4) * 0.007;
	float sd = dist + wobble - radius;

	float mask = smoothstep(-0.003, 0.003, sd);
	float rim = smoothstep(0.0, 0.02, sd) * (1.0 - smoothstep(0.035, 0.075, sd));
	float depth = clamp(dist / maxd, 0.0, 1.0);

	vec3 base = curtain_color.rgb * (0.78 + 0.32 * (1.0 - depth));
	// soft diagonal caustic shimmer
	float caustic = sin((UV.x + UV.y) * 18.0 + TIME * 1.5) * sin((UV.x - UV.y) * 14.0 - TIME * 1.1);
	base += vec3(0.05) * caustic;
	vec3 col = mix(base, mix(curtain_color.rgb, vec3(1.0), 0.55), rim * 0.85);
	COLOR = vec4(col, mask * curtain_color.a);
}
