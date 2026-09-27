shader_type spatial;
// Rocketbox skin/cloth: color + normal + specular (spec is converted to roughness).
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D spec_tex : hint_default_black, filter_linear_mipmap;
uniform float rough_min = 0.32;
uniform float rough_max = 0.92;
uniform float wetness = 0.0;
uniform float dirt = 0.0;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	// A little grime and sweat for the adventure look.
	c = mix(c, c * vec3(0.78, 0.7, 0.6), dirt);
	ALBEDO = c;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	float spec = texture(spec_tex, UV).r;
	ROUGHNESS = mix(rough_max, rough_min, spec) * (1.0 - wetness * 0.4);
	SPECULAR = 0.35 + spec * 0.3;
	SSS_STRENGTH = 0.0;
}
