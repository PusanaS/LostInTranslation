shader_type canvas_item;

// mode 0: blur/darken grows out of the old book.
// mode 1: the new level is revealed from its book.
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform vec2 origin = vec2(0.5);
uniform float radius = 0.0;
uniform float mode = 0.0;

void fragment() {
	float distance_from_book = distance(SCREEN_UV, origin);
	float inside = 1.0 - smoothstep(radius - 0.075, radius + 0.015, distance_from_book);
	float veil = mode < 0.5 ? inside : 1.0 - inside;
	vec4 blurred = textureLod(SCREEN_TEXTURE, SCREEN_UV, 3.5 * veil);
	vec3 translated_ink = mix(blurred.rgb, vec3(0.045, 0.10, 0.11), 0.60 * veil);
	COLOR = vec4(translated_ink, veil);
}
