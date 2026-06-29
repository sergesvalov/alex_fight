shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float curvature : hint_range(0.0, 1.0) = 0.15;
uniform float scan_line_opacity : hint_range(0.0, 1.0) = 0.3;
uniform float noise_strength : hint_range(0.0, 0.1) = 0.02;

void fragment() {
    vec2 uv = UV;
    
    // CRT-кривизна
    vec2 curved = uv - 0.5;
    curved *= 1.0 + dot(curved, curved) * curvature;
    uv = curved + 0.5;
    
    // Горизонтальные полосы сканлайна
    float scan = sin(uv.y * 800.0) * scan_line_opacity;
    
    // Шум
    float noise = fract(sin(dot(uv, vec2(12.9898, 78.233)) + TIME) * 43758.5453) * noise_strength;
    
    // RGB-смещение (хроматическая аберрация)
    vec4 color;
    color.r = texture(screen_texture, uv + vec2(0.001, 0.0)).r;
    color.g = texture(screen_texture, uv).g;
    color.b = texture(screen_texture, uv - vec2(0.001, 0.0)).b;
    color.a = 1.0;
    
    COLOR = color - vec4(scan) + vec4(noise);
}
