// NOTE: Shader automatically converted from Godot Engine 3.5.beta4's SpatialMaterial.

shader_type spatial;
render_mode async_visible,blend_mul,depth_draw_never,cull_back,diffuse_burley,specular_schlick_ggx,unshaded;
uniform vec4 albedo : hint_color;
uniform sampler2D texture_albedo : hint_albedo;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;


void vertex() {
	UV2=UV2*uv2_scale.xy+uv2_offset.xy;
}

vec3 lerp(vec3 a, vec3 b, float x)
{
    return a*(1.0-x) + b*x;
}

void fragment() {
	vec3 albedo_tex = texture(texture_albedo,UV2).xyz;
	albedo_tex *= albedo.rgb;
    float amount = (albedo_tex.r + albedo_tex.g + albedo_tex.b)/3.0;
    if (amount > 0.0)
        ALBEDO = lerp(albedo_tex / amount, vec3(1.0, 1.0, 1.0), 1.0-pow(amount, 2.1));
    else
        ALBEDO = vec3(1.0, 1.0, 1.0);
}
