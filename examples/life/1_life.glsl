#version 430
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

