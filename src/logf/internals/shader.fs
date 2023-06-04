#version 330 core
out vec4 final_color;

in VS_OUT {
  float tex_index;
  vec2 texcoord;
  vec4 color;
  vec2 pixel_position;
  vec2 quad_size;
  float border_radius;
} frag;

#define MAX_TEXTURE 16
uniform sampler2D textures[MAX_TEXTURE];

float gamma = 2.2;
vec3 invGamma = vec3(1.0 / gamma);

void main() {
  int tex_index = int(frag.tex_index);
  vec4 texture_clr = texture(textures[tex_index],frag.texcoord);
  float alpha = 1.0;

  if (frag.border_radius > 0.0) {
    float smooth_value = 0.7;

    vec2 pos = frag.pixel_position;
    float r = frag.border_radius;
    float mrx = frag.quad_size.x - r;
    float mry = frag.quad_size.y - r;

    float smooth_min = r - smooth_value;
    float smooth_max = r + smooth_value;

    if (pos.x < r && pos.y < r) {
      float blend_value = smoothstep(
        smooth_min, smooth_max, length(pos - vec2(r))
      );
      alpha = 1 - blend_value;
    } else if (pos.x > mrx  && pos.y < r) {
      float blend_value = smoothstep(
        smooth_min, smooth_max, length(pos - vec2(mrx, r))
      );
      alpha = 1 - blend_value;
    } else if (pos.x > mrx  && pos.y > mry) {
      float blend_value = smoothstep(
        smooth_min, smooth_max, length(pos - vec2(mrx, mry))
      );
      alpha = 1 - blend_value;
    } else if (pos.x < r  && pos.y > mry) {
      float blend_value = smoothstep(
        smooth_min, smooth_max, length(pos - vec2(r, mry))
      );
      alpha = 1 - blend_value;
    }
	}
  
  final_color = texture_clr * frag.color;
  // final_color.xyz = pow(final_color.xyz, invGamma);
  final_color.a = min(final_color.a, alpha);
}