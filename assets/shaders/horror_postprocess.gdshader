shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.5;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.6;
uniform vec4 vignette_color : source_color = vec4(0.05, 0.0, 0.0, 1.0);
uniform float aberration_amount : hint_range(0.0, 0.05) = 0.002;
uniform float grain_amount : hint_range(0.0, 0.2) = 0.03;
uniform float pulse_speed : hint_range(0.0, 10.0) = 1.0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float dizzy_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float grain_multiplier : hint_range(0.0, 1.0) = 1.0;
uniform float fast_mode : hint_range(0.0, 1.0) = 0.0;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = vec2(0.5, 0.5);
    if (dizzy_intensity > 0.001) {
        vec2 sway = vec2(
            sin(TIME * 2.4 + uv.y * 5.0) * 0.008,
            cos(TIME * 1.9 + uv.x * 4.5) * 0.006
        ) * dizzy_intensity;
        uv = clamp(uv + sway, vec2(0.002), vec2(0.998));
    }
    float dist = distance(uv, center);
    
    // Dynamic pulse
    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    vec3 color;
    if (fast_mode > 0.5 && dizzy_intensity <= 0.001 && pulse_intensity <= 0.12) {
        color = texture(screen_texture, uv).rgb;
    } else {
        float current_aberration = aberration_amount + pulse * pulse_intensity * 0.01 + dizzy_intensity * 0.008;
        vec2 dir = normalize(uv - center + vec2(0.0001));
        float r = texture(screen_texture, uv + dir * current_aberration).r;
        float g = texture(screen_texture, uv).g;
        float b = texture(screen_texture, uv - dir * current_aberration).b;
        color = vec3(r, g, b);
    }
    
    // Vignette
    float vig = smoothstep(0.8, 0.8 - vignette_intensity, dist * (1.0 + pulse * pulse_intensity * 0.3));
    color = mix(vignette_color.rgb, color, vig);
    
    // Film grain (skipped on low quality preset via grain_multiplier = 0.0)
    if (grain_multiplier > 0.01) {
        float grain = (random(uv + vec2(TIME * 0.1, TIME * 0.2)) - 0.5) * grain_amount * grain_multiplier;
        color += grain;
    }
    
    COLOR = vec4(color, 1.0);
}
