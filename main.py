#!/usr/bin/env python3
"""
OpenGL Compute Shader Pipeline
Automatically infers buffers from shader code and executes compute shaders in sequence.
"""

import sys
import re
import argparse
from OpenGL.GL import *
from OpenGL.GL.shaders import compileShader, compileProgram
import glfw
import numpy as np


def parse_shader_buffers(shader_code):
    """Extract buffer names from shader code (layout declarations)."""
    # Match patterns like: layout(rgba32f, binding = N) uniform image2D buffer_name;
    pattern = r'layout\s*\([^)]*\)\s*uniform\s+image2D\s+(\w+)\s*;'
    matches = re.findall(pattern, shader_code)
    return matches


def inject_uniforms(shader_code, is_compute=True):
    """Inject uniform declarations for frame and resolution into shader."""
    # Check if uniforms already exist
    has_frame = 'uniform int frame' in shader_code or 'uniform uint frame' in shader_code
    has_resolution = 'uniform vec2 resolution' in shader_code or 'uniform ivec2 resolution' in shader_code
    
    if not has_frame or not has_resolution:
        uniform_decls = ""
        if not has_frame:
            uniform_decls += "uniform int frame;\n"
        if not has_resolution:
            uniform_decls += "uniform vec2 resolution;\n"
        
        # Insert after #version directive
        lines = shader_code.split('\n')
        for i, line in enumerate(lines):
            if line.strip().startswith('#version'):
                lines.insert(i + 1, uniform_decls)
                break
        else:
            # No #version found, add at beginning
            lines.insert(0, uniform_decls)
        
        shader_code = '\n'.join(lines)
    
    return shader_code


def create_compute_shader(source, frame_uniform, resolution_uniform):
    """Compile a compute shader with uniform locations."""
    try:
        shader = compileShader(source, GL_COMPUTE_SHADER)
    except Exception as e:
        try:
            print(e.args[0])
        except Exception as _:
            pass

        raise e
    program = compileProgram(shader)
    
    # Get uniform locations
    glUseProgram(program)
    frame_loc = glGetUniformLocation(program, "frame")
    res_loc = glGetUniformLocation(program, "resolution")
    
    return program, frame_loc, res_loc


def create_render_shader(vertex_src, fragment_src, frame_uniform, resolution_uniform):
    """Compile vertex and fragment shaders."""
    vert_shader = compileShader(vertex_src, GL_VERTEX_SHADER)
    frag_shader = compileShader(fragment_src, GL_FRAGMENT_SHADER)
    program = compileProgram(vert_shader, frag_shader)
    
    glUseProgram(program)
    frame_loc = glGetUniformLocation(program, "frame")
    res_loc = glGetUniformLocation(program, "resolution")
    
    return program, frame_loc, res_loc


def create_texture(width, height):
    """Create an RGBA32F texture."""
    texture = glGenTextures(1)
    glBindTexture(GL_TEXTURE_2D, texture)
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, width, height, 0, GL_RGBA, GL_FLOAT, None)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
    return texture


def main():
    parser = argparse.ArgumentParser(description='OpenGL Compute Shader Pipeline')
    parser.add_argument('--width', type=int, default=512, help='Buffer width')
    parser.add_argument('--height', type=int, default=512, help='Buffer height')
    parser.add_argument('--compute', nargs='+', help='Compute shader files (in execution order)')
    parser.add_argument('--fragment', help='Fragment shader file (optional)')
    parser.add_argument('--steps', type=int, default=1, help='Number of compute steps per frame (frame-skip)')
    parser.add_argument('--example', action='store_true', help='Run Conway\'s Game of Life example')
    
    args = parser.parse_args()
    
    # Initialize GLFW
    if not glfw.init():
        sys.exit(1)
    
    glfw.window_hint(glfw.CONTEXT_VERSION_MAJOR, 4)
    glfw.window_hint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.window_hint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    
    window = glfw.create_window(args.width, args.height, "Compute Shader Pipeline", None, None)
    if not window:
        glfw.terminate()
        sys.exit(1)
    
    glfw.make_context_current(window)
    glfw.swap_interval(1)  # VSync
    
    print(f"OpenGL Version: {glGetString(GL_VERSION).decode()}")
    
    # Example shaders for Conway's Game of Life
    if args.example:
        init_source = '''#version 430
layout(local_size_x = 16, local_size_y = 16) in;
layout(rgba32f, binding = 0) uniform image2D cells;

// Simple hash function for pseudo-random numbers
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(cells);
    
    if (pos.x >= size.x || pos.y >= size.y) return;
    
    // Only initialize on frame 0
    if (frame > 0) return;
    
    // Generate pseudo-random value (20% alive)
    float random = hash(vec2(pos) + 0.5);
    float alive = random < 0.2 ? 1.0 : 0.0;
    
    imageStore(cells, pos, vec4(alive, alive, alive, 1.0));
}
'''
        
        compute_source = '''#version 430
layout(local_size_x = 16, local_size_y = 16) in;
layout(rgba32f, binding = 0) uniform image2D cells;
layout(rgba32f, binding = 1) uniform image2D cells_copy;

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(cells);
    
    if (pos.x >= size.x || pos.y >= size.y) return;
    
    // Skip frame 0 (let init shader run first)
    if (frame == 0) return;
    
    // Count alive neighbors
    int count = 0;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            
            ivec2 neighbor = pos + ivec2(dx, dy);
            // Wrap around edges
            neighbor = (neighbor + size) % size;
            
            vec4 cell = imageLoad(cells_copy, neighbor);
            if (cell.r > 0.5) count++;
        }
    }
    
    // Conway's rules
    vec4 current = imageLoad(cells_copy, pos);
    float alive = current.r > 0.5 ? 1.0 : 0.0;
    
    float new_state = 0.0;
    if (alive > 0.5) {
        // Cell is alive
        if (count == 2 || count == 3) new_state = 1.0;
    } else {
        // Cell is dead
        if (count == 3) new_state = 1.0;
    }
    
    imageStore(cells, pos, vec4(new_state, new_state, new_state, 1.0));
}
'''
        
        fragment_source = None  # Will use default
        compute_sources = [init_source, compute_source]
    else:
        if not args.compute:
            print("Error: Must specify --compute shaders or use --example")
            sys.exit(1)
        
        compute_sources = []
        for compute_file in args.compute:
            with open(compute_file, 'r') as f:
                compute_sources.append(f.read())
        
        fragment_source = None
        if args.fragment:
            with open(args.fragment, 'r') as f:
                fragment_source = f.read()
    
    # Inject uniforms into all shaders
    compute_sources = [inject_uniforms(src, True) for src in compute_sources]
    
    # Parse all compute shaders to find buffers FIRST
    all_buffers = set()
    for compute_src in compute_sources:
        buffers = parse_shader_buffers(compute_src)
        all_buffers.update(buffers)
    
    # Default fragment shader if none provided
    if fragment_source is None:
        # Use first non-_copy buffer as display buffer
        display_buffer = None
        for buf in sorted(all_buffers):
            if not buf.endswith('_copy'):
                display_buffer = buf
                break
        
        if display_buffer is None:
            print("Error: No buffers found to display")
            sys.exit(1)
        
        fragment_source = f'''#version 430
out vec4 fragColor;
uniform vec2 resolution;
layout(rgba32f, binding = 0) uniform image2D {display_buffer};

void main() {{
    ivec2 pos = ivec2(gl_FragCoord.xy);
    vec4 color = imageLoad({display_buffer}, pos);
    fragColor = color;
}}
'''
        print(f"Using default fragment shader to display buffer: {display_buffer}")
    
    fragment_source = inject_uniforms(fragment_source, False)
    
    # Also check fragment shader for additional buffers
    all_buffers.update(parse_shader_buffers(fragment_source))
    
    # Also check fragment shader
    all_buffers.update(parse_shader_buffers(fragment_source))
    
    print(f"Detected buffers: {all_buffers}")
    
    # Create textures for all buffers
    textures = {}
    for buffer_name in all_buffers:
        textures[buffer_name] = create_texture(args.width, args.height)
        print(f"Created texture for buffer: {buffer_name}")
    
    # Compile compute shaders
    compute_programs = []
    for i, compute_src in enumerate(compute_sources):
        program, frame_loc, res_loc = create_compute_shader(compute_src, True, True)
        compute_programs.append((program, frame_loc, res_loc))
        print(f"Compiled compute shader {i}")
    
    # Create vertex shader for fullscreen quad
    vertex_source = '''#version 430
out vec2 texCoord;
void main() {
    vec2 vertices[3] = vec2[3](
        vec2(-1.0, -1.0),
        vec2(3.0, -1.0),
        vec2(-1.0, 3.0)
    );
    gl_Position = vec4(vertices[gl_VertexID], 0.0, 1.0);
    texCoord = vertices[gl_VertexID] * 0.5 + 0.5;
}
'''
    
    render_program, frag_frame_loc, frag_res_loc = create_render_shader(
        vertex_source, fragment_source, True, True
    )
    
    # Create VAO for fullscreen quad
    vao = glGenVertexArrays(1)
    glBindVertexArray(vao)
    
    frame_count = 0
    
    while not glfw.window_should_close(window):
        for _ in range(args.steps):
            # Handle _copy buffers: copy parent to _copy before compute shaders run
            for buffer_name in all_buffers:
                if buffer_name.endswith('_copy'):
                    parent_name = buffer_name[:-5]  # Remove '_copy'
                    if parent_name in textures:
                        # Copy parent to _copy buffer
                        glCopyImageSubData(
                            textures[parent_name], GL_TEXTURE_2D, 0, 0, 0, 0,
                            textures[buffer_name], GL_TEXTURE_2D, 0, 0, 0, 0,
                            args.width, args.height, 1
                        )
            
            # Execute compute shaders in sequence
            for program, frame_loc, res_loc in compute_programs:
                glUseProgram(program)
                
                # Set uniforms
                if frame_loc >= 0:
                    glUniform1i(frame_loc, frame_count)
                if res_loc >= 0:
                    glUniform2f(res_loc, float(args.width), float(args.height))
                
                # Bind all textures to their binding points
                for binding, (buffer_name, texture) in enumerate(sorted(textures.items())):
                    glBindImageTexture(binding, texture, 0, GL_FALSE, 0, GL_READ_WRITE, GL_RGBA32F)
                
                # Dispatch compute shader
                work_groups_x = (args.width + 15) // 16
                work_groups_y = (args.height + 15) // 16
                glDispatchCompute(work_groups_x, work_groups_y, 1)
                glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT)
        
            frame_count += 1
            
        # Render to screen
        glClear(GL_COLOR_BUFFER_BIT)
        glUseProgram(render_program)
        
        # Set uniforms
        if frag_frame_loc >= 0:
            glUniform1i(frag_frame_loc, frame_count)
        if frag_res_loc >= 0:
            glUniform2f(frag_res_loc, float(args.width), float(args.height))
        
        # Bind textures for fragment shader
        for binding, (buffer_name, texture) in enumerate(sorted(textures.items())):
            glBindImageTexture(binding, texture, 0, GL_FALSE, 0, GL_READ_WRITE, GL_RGBA32F)
        
        glBindVertexArray(vao)
        glDrawArrays(GL_TRIANGLES, 0, 3)
        
        glfw.swap_buffers(window)
        glfw.poll_events()
    
    glfw.terminate()


if __name__ == '__main__':
    main()
