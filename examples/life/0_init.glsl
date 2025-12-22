#version 430
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

