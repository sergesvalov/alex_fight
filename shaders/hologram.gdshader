shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform vec4 holo_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float scan_speed : hint_range(0.1, 5.0) = 1.5;
uniform float scan_density : hint_range(10.0, 200.0) = 80.0;
uniform float flicker_speed : hint_range(0.0, 20.0) = 8.0;
uniform float alpha : hint_range(0.0, 1.0) = 0.7;

void fragment() {
    float scan_line = sin(UV.y * scan_density + TIME * scan_speed) * 0.5 + 0.5;
    float flicker = sin(TIME * flicker_speed) * 0.05 + 0.95;
    float edge_fade = 1.0 - abs(UV.x - 0.5) * 2.0;
    
    ALBEDO = holo_color.rgb * scan_line * flicker;
    ALPHA = alpha * scan_line * edge_fade * flicker;
}
