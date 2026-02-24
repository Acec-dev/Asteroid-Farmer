shader_type spatial;

uniform float edge_width : hint_range(0.01, 0.5) = 0.05;
uniform float emission_strength : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    // Make the base color black
    ALBEDO = vec3(0.0);

    // Use screen-space derivatives of the world normal to detect edges
    vec3 normal = NORMAL;
    float edge = 1.0 - smoothstep(0.0, edge_width, abs(dot(normal, VIEW)));

    EMISSION = vec3(edge) * emission_strength;
}