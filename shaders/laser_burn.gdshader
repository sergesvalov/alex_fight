// The mark a laser shot leaves (hit_marker.tscn): a round scorch with a ragged edge and a
// centre that is white-hot at first and cools to nothing. Drawn entirely here - there is no
// texture, so there is no square of one around the mark.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform float heat : hint_range(0.0, 1.0) = 1.0;  // 1 the moment it is hit, 0 once cooled
uniform float fade : hint_range(0.0, 1.0) = 1.0;  // the whole mark's opacity, for its last moments
uniform float seed = 0.0;                         // turns the ragged edge, so no two marks match

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = atan(p.y, p.x);
	float r = length(p) + 0.04 * sin(angle * 3.0 + seed) + 0.03 * sin(angle * 7.0 + seed * 2.3)
		+ 0.02 * sin(angle * 13.0 - seed);

	float soot = smoothstep(0.8, 0.25, r);
	float ember = heat * smoothstep(0.5, 0.05, r);
	float core = smoothstep(0.25, 0.0, r);

	vec3 glow = mix(vec3(1.0, 0.22, 0.02), vec3(1.0, 0.85, 0.55), core * heat) * (1.0 + 2.5 * core * heat);
	ALBEDO = mix(vec3(0.02, 0.015, 0.01), glow, ember);
	ALPHA = max(soot * 0.85, ember) * fade;
}
