shader_type canvas_item;
// Soft warm screen-space vignette that frames the playfield.

uniform vec4 tint : source_color = vec4(0.10, 0.18, 0.12, 1.0);
uniform float strength = 0.22;
uniform float inner = 0.55;
uniform float outer = 1.25;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.0, 1.25);
	float d = length(p) * 2.0;
	float v = smoothstep(inner, outer, d);
	COLOR = vec4(tint.rgb, v * strength);
}
