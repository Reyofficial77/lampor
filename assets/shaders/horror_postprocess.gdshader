shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.5;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.6;
uniform vec4 vignette_color : source_color = vec4(0.05, 0.0, 0.0, 1.0);
uniform float aberration_amount : hint_range(0.0, 0.05) = 0.002;
uniform float grain_amount : hint_range(0.0, 0.2) = 0.03;
uniform float pulse_speed : hint_range(0.0, 10.0) = 1.0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.0;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(uv, center);
    
    // Dynamic pulse
    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    float current_aberration = aberration_amount + pulse * pulse_intensity * 0.01;
    
    // Chromatic Aberration
    vec2 dir = normalize(uv - center);
    float r = texture(screen_texture, uv + dir * current_aberration).r;
    float g = texture(screen_texture, uv).g;
    float b = texture(screen_texture, uv - dir * current_aberration).b;
    vec3 color = vec3(r, g, b);
    
    // Vignette
    float vig = smoothstep(0.8, 0.8 - vignette_intensity, dist * (1.0 + pulse * pulse_intensity * 0.3));
    color = mix(vignette_color.rgb, color, vig);
    
    // Film grain
    float grain = (random(uv + vec2(TIME * 0.1, TIME * 0.2)) - 0.5) * grain_amount;
    color += grain;
    
    COLOR = vec4(color, 1.0);
}
