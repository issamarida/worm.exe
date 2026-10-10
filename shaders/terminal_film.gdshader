shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float grain_strength : hint_range(0.0, 0.05) = 0.012;
uniform float scanline_strength : hint_range(0.0, 0.1) = 0.028;
uniform bool reduced_motion = false;

float noise(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 color = texture(screen_texture, uv).rgb;
	float grain = noise(uv * vec2(1440.0, 900.0) + (reduced_motion ? 0.0 : floor(TIME * 8.0)));
	float scanline = sin(uv.y / SCREEN_PIXEL_SIZE.y * 3.14159) * scanline_strength;
	float vignette = 1.0 - smoothstep(0.18, 0.92, length((uv - 0.5) * vec2(0.9, 1.0)));
	color *= 0.93 + 0.07 * vignette;
	color += (grain - 0.5) * grain_strength;
	color *= 1.0 - scanline;
	COLOR = vec4(color, 1.0);
}
