shader_type canvas_item;

uniform vec4 twinkle_color : source_color = vec4(1.0, 1.0, 0.8, 1.0);
uniform float speed = 2.0;
uniform float density = 12.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV * density;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float h = hash(cell);
	float t = TIME * speed + h * 6.28;
	float pulse = smoothstep(0.0, 1.0, sin(t) * 0.5 + 0.5);
	float star = smoothstep(0.35, 0.0, length(f - 0.5));
	float alpha = star * pulse * twinkle_color.a;
	COLOR = vec4(twinkle_color.rgb, alpha);
}
