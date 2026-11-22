shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.55, 0.18, 0.28);
uniform float speed = 3.2;
uniform float density = 10.0;

void fragment() {
	vec2 uv = UV;
	float shimmer = sin(uv.y * density - TIME * speed + sin(uv.x * 8.0) * 1.4) * 0.5 + 0.5;
	float edge_x = smoothstep(0.0, 0.20, uv.x) * (1.0 - smoothstep(0.80, 1.0, uv.x));
	float edge_y = smoothstep(0.0, 0.18, uv.y) * (1.0 - smoothstep(0.75, 1.0, uv.y));
	float a = (0.45 + 0.55 * shimmer) * edge_x * edge_y * glow_color.a;
	COLOR = vec4(glow_color.rgb, a);
}
