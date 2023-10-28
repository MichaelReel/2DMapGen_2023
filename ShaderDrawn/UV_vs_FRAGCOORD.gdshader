shader_type canvas_item;
uniform vec2 iResolution = vec2(1024,1024);

void fragment() {
	// UV is 0 to 1, FRAGCOORD is the pixel position
	// UV is the same a FRAGCOORD divided by the current screen size in pixels
	// If the resolution is always the screen dimensions, uv_a and uv_b are identical
	vec2 uv_a = FRAGCOORD.xy / iResolution.xy;
	vec2 uv_b = UV.xy;
	
	// We can also use the SCREEN_PIXEL_SIZE to modify FRAGCOORD 
	// to get the equivalent of UV
//	uv_a = FRAGCOORD.xy * SCREEN_PIXEL_SIZE;

	vec3 col_a = 0.5 + 0.5 * cos(TIME + uv_a.xyx + vec3(0, 2, 4));
	vec3 col_b = 0.5 + 0.5 * cos(TIME + uv_b.xyx + vec3(0, 2, 4));

	COLOR = vec4( col_b - col_a, 1.0 );
}