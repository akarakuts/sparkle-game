shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.9, 0.4, 0.6);
uniform float pulse_speed = 1.5;
uniform float intensity = 1.0;

void fragment() {
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	vec4 base = texture(TEXTURE, UV);
	float edge = 1.0 - smoothstep(0.3, 0.5, length(UV - 0.5));
	vec3 glow = glow_color.rgb * edge * pulse * intensity;
	COLOR = vec4(base.rgb + glow, base.a + edge * glow_color.a * pulse * 0.5);
}
