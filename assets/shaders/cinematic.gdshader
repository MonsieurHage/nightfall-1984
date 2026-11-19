shader_type canvas_item;
render_mode blend_mul;

// Vignettage cinématographique + grain d'argentique léger (1984).
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.85;
uniform float grain_strength : hint_range(0.0, 0.15) = 0.025;

void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	float v = clamp(1.0 - dot(c, c) * vignette_strength * 2.0, 0.18, 1.0);
	float n = fract(sin(dot(SCREEN_UV * vec2(1273.7, 913.1), vec2(12.9898, 78.233)) + TIME * 7.0) * 43758.5453);
	float g = 1.0 + (n - 0.5) * grain_strength;
	COLOR = vec4(vec3(v * g), 1.0);
}
