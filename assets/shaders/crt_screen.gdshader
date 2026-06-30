shader_type spatial;
render_mode unshaded;

uniform sampler2D screen_texture;
uniform float noise_amount : hint_range(0.0, 1.0) = 0.2;
uniform float scanline_amount : hint_range(0.0, 1.0) = 0.5;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
    vec4 tex_color = texture(screen_texture, UV);
    
    // Add static TV noise
    float noise = random(UV + vec2(TIME * 100.0, TIME * 50.0));
    vec3 color_with_noise = mix(tex_color.rgb, vec3(noise), noise_amount);
    
    // Add scrolling scanlines
    float scanline = sin(UV.y * 200.0 - TIME * 5.0) * 0.5 + 0.5;
    color_with_noise -= scanline * scanline_amount * 0.2;
    
    // Flickering
    float flicker = random(vec2(TIME, 0.0));
    color_with_noise *= (0.9 + flicker * 0.1);
    
    ALBEDO = color_with_noise;
}
