shader_type canvas_item;

uniform vec3 dc_offset = vec3(0.5, 0.5, 0.5);
uniform vec3 amp = vec3(0.5, 0.5, 0.5);
uniform vec3 freq = vec3(1.0, 1.0, 1.0);
uniform vec3 phase = vec3(0.263, 0.416, 0.557);

uniform float partition_scale = 1.5;
uniform float partition_distance_scale = 0.01;

// https://www.youtube.com/watch?v=f4s1h2YETNY

vec3 palette(float t, vec3 dc_o, vec3 a, vec3 f, vec3 p) {
	// See: http://dev.thi.ng/gradients/
	return dc_o + a * cos( 6.28318 * (f * t * p));
}

void fragment() {
	 // Match to shadertoy origin at bottom left, and center the UV
	vec2 uv = vec2(UV.x, 1.0f - UV.y) * 2.0 - 1.0;
	// Maintain aspect ratio
	uv.x /= SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;

	// Using FRAGCOORD to achieve the same as above:
	// uv = (vec2(FRAGCOORD.x, (1.0 / SCREEN_PIXEL_SIZE.y) - FRAGCOORD.y) * 2.0 - (1.0 / SCREEN_PIXEL_SIZE.xy)) * SCREEN_PIXEL_SIZE.y;

	// Record the full screen coordinated before we perform space repetition
	vec2 uv_0 = uv;
	// Get distance to the universal center
	float d_0 = length(uv_0);
	
	// Initialise the final color to black
	vec3 finalColor = vec3(0.0);

	for (float i = 0.0; i < 4.0; i += 1.0) {
		// space repetition:
		// Split the space into smaller ranges using some fractional part of the UV
		uv = fract(uv * partition_scale) - 0.5;

		// Get distance to the local center
		float d = length(uv);
		
		// Multiply the local distance by an exponential
		d *= exp(-d_0);
		
		// Get the paletted color based on time and distance from the original center
		vec3 col = palette(d_0 + i * 0.4 + TIME * 0.4, dc_offset, amp, freq, phase);

		d = sin(d * 8.0 + TIME) / 8.0;
		d = abs(d);

		// Scale the local partition distance
		d = partition_distance_scale / d;
		
		// Enhance the image using powers
		d = pow(d, 1.2);
		
		finalColor += col * d;
	}

	COLOR = vec4(finalColor, 1.0);
	
	// Debug the partition space:
//	COLOR = vec4(uv, 0.0, 1.0);
}