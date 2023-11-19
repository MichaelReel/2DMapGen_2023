shader_type canvas_item;

uniform vec2 iResolution;
uniform float speed = 1.0;
uniform float zoom = 2.0;

uniform float dx = 1.0;


mat2 rotate2d(float _angle_rads) {
	return mat2(vec2(cos(_angle_rads),-sin(_angle_rads)), vec2(sin(_angle_rads),cos(_angle_rads)));
}

float height( in float amp, in float wavlen, in float spd) {
	return amp * sin(wavlen * zoom * PI + TIME * spd);
}

float wave_derivative(in float amp, in float wavlen, in float spd) {
	return zoom * amp * dx * cos(wavlen * zoom + TIME * spd);
}

vec3 wave(in float amp, in vec2 pos, in float spd, in float angle) {
	float wavlen = (pos * rotate2d(angle)).x;
	
	vec2 normal = vec2(wave_derivative(amp, wavlen, spd), 0.0) * rotate2d(-angle);
	
	return vec3(height(amp, wavlen, spd), normal);
}

void fragment() {
	
	vec2 p = UV.xy / iResolution.xy;
	
	vec2 uv = p * vec2(iResolution.x / iResolution.y, 1.0);
	
	vec3 f = vec3(0.0);
	
	mat2 m = mat2( vec2(1.6,  1.2), vec2(-1.2,  1.6) );
	
	f += wave( 1.0, uv, speed, 45.0);
//	f += wave( 0.5, uv * 1.30, speed * 1.3, 20.0);
//	f += wave( 0.25, uv * .80, speed * 3.5, 30.0);
//	f += wave( 0.125, uv * 1.70, speed * 2.7, 40.0);

	f = vec3(0.5) + 0.5 * f;
	
	COLOR = vec4( f, 1.0 );
}