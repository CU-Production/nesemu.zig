@vs vs
in vec4 position;
in vec2 texcoord0;

out vec2 uv;

void main() {
    gl_Position = position;
    uv = texcoord0;
}
@end

@fs fs
layout(binding=0) uniform texture2D tex;
layout(binding=0) uniform sampler   smp;
in vec2 uv;
out vec4 frag_color;

void main() {
    frag_color = texture(sampler2D(tex, smp), uv);
    // frag_color = vec4(uv, 0.0f, 1.0f);
}
@end

@program triangle vs fs