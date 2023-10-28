shader_type canvas_item;
uniform vec2 iResolution = vec2(1024,1024);

void fragment() {
	vec2 uv = FRAGCOORD.xy / iResolution.xy;
	
	vec3 col = 0.5 + 0.5 * cos(TIME + uv.xyx + vec3(0, 2, 4));
	
	COLOR = vec4( col, 1.0 );
}