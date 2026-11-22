shader_type canvas_item;

uniform vec4 ray_color : source_color = vec4(1.0, 0.97, 0.80, 0.20);
uniform float angle = 0.42;
uniform float speed = 0.22;
uniform float ray_count = 4.5;

void fragment() {
	vec2 uv = UV;
	float diag = uv.x * cos(angle) - uv.y * sin(angle);
	float t = TIME * speed;

	float wave1 = sin(diag * ray_count * 6.28318 + t) * 0.5 + 0.5;
	float wave2 = sin(diag * (ray_count * 1.73) * 6.28318 - t * 0.65 + 1.4) * 0.5 + 0.5;
	float beam = pow(wave1 * 0.65 + wave2 * 0.35, 2.2);

	// Fade gently from top-left skylight down toward bottom-right
	float top_fade = smoothstep(0.0, 0.10, uv.y) * (1.0 - smoothstep(0.35, 1.0, uv.y));
	float side_fade = smoothstep(0.0, 0.15, uv.x) * (1.0 - smoothstep(0.82, 1.0, uv.x));
	float alpha = beam * top_fade * side_fade * ray_color.a;

	COLOR = vec4(ray_color.rgb, alpha);
}
