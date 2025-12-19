import glfw
import argparse
import numpy as np
from OpenGL.GL import *
from OpenGL.GL.shaders import compileShader, compileProgram
import sys
import pathlib

# =========================
# Default Compute Shader
# =========================
DEFAULT_COMPUTE_SHADER = r"""
#version 430

layout (local_size_x = 16, local_size_y = 16) in;

layout(rgba32f, binding = 0) readonly uniform image2D srcTex;
layout(rgba32f, binding = 1) writeonly uniform image2D dstTex;

ivec2 size = imageSize(srcTex);

int alive(ivec2 p) {
    p = (p + size) % size;
    return imageLoad(srcTex, p).r > 0.5 ? 1 : 0;
}

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    if (pos.x >= size.x || pos.y >= size.y) return;

    int n =
        alive(pos + ivec2(-1,-1)) +
        alive(pos + ivec2( 0,-1)) +
        alive(pos + ivec2( 1,-1)) +
        alive(pos + ivec2(-1, 0)) +
        alive(pos + ivec2( 1, 0)) +
        alive(pos + ivec2(-1, 1)) +
        alive(pos + ivec2( 0, 1)) +
        alive(pos + ivec2( 1, 1));

    float state = imageLoad(srcTex, pos).r;
    float next = state;

    if (state > 0.5 && (n < 2 || n > 3)) next = 0.0;
    if (state < 0.5 && n == 3) next = 1.0;

    imageStore(dstTex, pos, vec4(next, 0.0, 0.0, 1.0));
}
"""

# =========================
# Vertex / Fragment Shaders
# =========================
VERT_SHADER = """
#version 330
out vec2 uv;
void main() {
    vec2 p = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
    uv = p;
    gl_Position = vec4(p * 2.0 - 1.0, 0, 1);
}
"""

FRAG_SHADER = """
#version 330
in vec2 uv;
out vec4 fragColor;
uniform sampler2D tex;
void main() {
    float v = texture(tex, uv).r;
    fragColor = vec4(v, v, v, 1);
}
"""

# =========================
# Helpers
# =========================
def make_texture(w, h, data=None):
    tex = glGenTextures(1)
    glBindTexture(GL_TEXTURE_2D, tex)
    glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA32F, w, h)
    if data is not None:
        glTexSubImage2D(
            GL_TEXTURE_2D, 0, 0, 0, w, h,
            GL_RGBA, GL_FLOAT, data
        )
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    return tex

# =========================
# Main
# =========================
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compute", type=pathlib.Path,
                        help="Path to compute shader GLSL file")
    parser.add_argument("--size", type=int, default=512)
    args = parser.parse_args()

    if not glfw.init():
        sys.exit(1)

    glfw.window_hint(glfw.CONTEXT_VERSION_MAJOR, 4)
    glfw.window_hint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.window_hint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

    win = glfw.create_window(800, 800, "Game of Life (Compute)", None, None)
    glfw.make_context_current(win)

    # Load compute shader source
    if args.compute:
        compute_src = args.compute.read_text()
    else:
        compute_src = DEFAULT_COMPUTE_SHADER

    compute_prog = compileProgram(
        compileShader(compute_src, GL_COMPUTE_SHADER)
    )

    render_prog = compileProgram(
        compileShader(VERT_SHADER, GL_VERTEX_SHADER),
        compileShader(FRAG_SHADER, GL_FRAGMENT_SHADER)
    )

    size = args.size

    # Initial random state
    init = np.zeros((size, size, 4), dtype=np.float32)
    init[..., 0] = (np.random.rand(size, size) > 0.8).astype(np.float32)
    init[..., 3] = 1.0

    tex_a = make_texture(size, size, init)
    tex_b = make_texture(size, size)

    front, back = tex_a, tex_b

    vao = glGenVertexArrays(1)

    while not glfw.window_should_close(win):
        glfw.poll_events()

        # --- Compute pass ---
        glUseProgram(compute_prog)
        glBindImageTexture(0, front, 0, GL_FALSE, 0, GL_READ_ONLY, GL_RGBA32F)
        glBindImageTexture(1, back,  0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F)

        gx = (size + 15) // 16
        gy = (size + 15) // 16
        glDispatchCompute(gx, gy, 1)
        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT)

        # Retain both buffers, explicit swap
        front, back = back, front

        # --- Render pass ---
        glClear(GL_COLOR_BUFFER_BIT)
        glUseProgram(render_prog)
        glBindVertexArray(vao)
        glActiveTexture(GL_TEXTURE0)
        glBindTexture(GL_TEXTURE_2D, front)
        glDrawArrays(GL_TRIANGLES, 0, 3)

        glfw.swap_buffers(win)

    glfw.terminate()

if __name__ == "__main__":
    main()
