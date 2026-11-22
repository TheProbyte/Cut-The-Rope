shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 curtain_color : source_color = vec4(0.16, 0.52, 0.68, 1.0);
uniform vec4 rim_color : source_color = vec4(0.55, 0.90, 1.0, 1.0);
uniform vec2 center = vec2(0.5, 0.48);

void fragment() {
	vec2 aspect_uv = vec2((UV.x - center.x) * 0.5625, UV.y - center.y);
	float dist = length(aspect_uv);
	float ang = atan(aspect_uv.y, aspect_uv.x);
	// Soft organic water-ripple edge
	float ripple = sin(ang * 7.0 + TIME * 4.5) * 0.012 + cos(ang * 4.0 - TIME * 3.0) * 0.008;
	float radius = mix(0.88, -0.06, progress);
	float d = dist + ripple - radius;

	float mask = smoothstep(-0.015, 0.015, d);
	float rim = smoothstep(-0.045, 0.0, d) * (1.0 - smoothstep(0.0, 0.035, d));

	vec3 col = mix(curtain_color.rgb, rim_color.rgb, rim * 0.75);
	COLOR = vec4(col, mask * curtain_color.a);
}
