shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Hair cards, eyelashes: alpha from the opacity texture.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float alpha_cut = 0.35;

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.55;
	SPECULAR = 0.5;
	ANISOTROPY = 0.6;
}
