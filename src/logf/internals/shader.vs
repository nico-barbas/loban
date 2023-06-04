#version 330 core
layout (location = 0) in vec4 a_position;
layout (location = 2) in vec4 a_texcoord;
layout (location = 3) in vec4 a_color;

out VS_OUT {
  float tex_index;
  vec2 texcoord;
  vec4 color;
  vec2 pixel_position;
  vec2 quad_size;
  float border_radius;
} frag;


uniform mat4 mat_proj;

void main() {
  frag.tex_index = a_texcoord.z;
  frag.texcoord = a_texcoord.xy;
  frag.color = a_color;
  frag.quad_size = a_position.zw;
  frag.pixel_position = frag.texcoord * frag.quad_size;
  frag.border_radius = a_texcoord.w;
  gl_Position = mat_proj * vec4(a_position.xy, 0, 1);
}