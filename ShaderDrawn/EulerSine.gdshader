shader_type canvas_item;

uniform vec2 iResolution;
uniform float startAmplitude = 0.35;
uniform float multiplyAmplitude = 0.82;
uniform float startAngle = 6.283185307;
uniform float multiplyAngle = 0.92;
uniform vec2 offsetPosition = vec2(0.0);
uniform float multiplyPosition = 1.18;
uniform int detailLevel = 16;
uniform float warping = 0.0;
uniform float speed = 1.0;
uniform float zoom = 2.0;

uniform float dx = 1.0;

mat2 rotate2d(float _angle_rads) {
	return mat2(vec2(cos(_angle_rads),-sin(_angle_rads)), vec2(sin(_angle_rads),cos(_angle_rads)));
}

float height( in float amp, in float wavlen, in float spd) {
	return amp * pow(E, sin(wavlen * zoom * PI + TIME * spd) - 1.0);
}

float wave_derivative(in float amp, in float wavlen, in float spd) {
	return zoom * amp * dx * pow(E, sin(wavlen * zoom * PI + TIME * spd) - 1.0) * cos(wavlen * zoom * PI + TIME * spd);
}

vec3 wave(in float amp, in vec2 pos, in float spd, in float angle) {
	float wavlen = (pos * rotate2d(angle)).x;
	
	float height = height(amp, wavlen, spd);
	vec2 normal = vec2(wave_derivative(amp, wavlen, spd), 0.0) * rotate2d(-angle);
	
	return vec3(normal, height);
}

void fragment() {
	vec2 p = UV.xy / iResolution.xy;
	vec2 uv = p * vec2(iResolution.x / iResolution.y, 1.0);
	vec3 f = vec3(0.0);
	vec2 last_wave = f.yz;
	
	float amp = startAmplitude;
	vec2 pos = uv + offsetPosition;
	float spd = speed;
	float angle = startAngle;
	
	for (int i = 0; i <= detailLevel; i ++) {
		amp = amp * multiplyAmplitude;
		pos = pos * multiplyPosition + last_wave * warping;
		angle = angle * multiplyAngle;
		
		f += wave( amp, pos, spd, angle);
		
		last_wave = f.yz;
	}
	
	COLOR = vec4( vec3(f), 1.0 );
}