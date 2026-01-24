#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform vec2 uResolution;
uniform float uAudio; // Bass level (0.0 to 1.0)
uniform float uSpeed;
uniform float uIntensity;
uniform vec4 uColor1;
uniform vec4 uColor2;

out vec4 fragColor;

void main() {
    vec2 st = FlutterFragCoord().xy / uResolution;
    
    // Use uSpeed to control time speed
    float t = uTime * uSpeed;
    
    // Use uniforms for colors
    vec3 color1 = uColor1.rgb; 
    vec3 color2 = uColor2.rgb;
    // Keep a hardcoded 3rd color or mix? Let's infer 3rd or just mix 2.
    // For simplicity, let's mix the two user colors.
    
    // Wave patterns
    float wave1 = sin(st.x * 10.0 + t) * 0.5 + 0.5;
    float wave2 = cos(st.y * 8.0 - t * 1.5) * 0.5 + 0.5;
    
    // Audio reactivity - boost brightness or mix
    // Use uIntensity to scale the audio effect
    float brightness = 1.0 + (uAudio * uIntensity * 2.0); 
    
    vec3 mixed = mix(color1, color2, wave1);
    mixed = mix(mixed, color2, wave2); // Simplification for 2 colors
    
    fragColor = vec4(mixed * brightness, uColor1.a); // Use alpha from color1? Or 1.0?
}

