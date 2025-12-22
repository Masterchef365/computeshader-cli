#version 430
layout(local_size_x = 16, local_size_y = 16) in;
layout(rgba32f, binding = 0) uniform image2D wave;
layout(rgba32f, binding = 1) uniform image2D wave_copy;

const float c = 0.5; // Courant number

vec2 coord_to_uv(vec2 coord, vec2 resolution) {
    vec2 uv = coord / resolution;
    uv = uv * 2.0 - 1.0;
    uv.x *= resolution.x / resolution.y;
    return uv;
}

float wavepacket(vec2 coord, vec2 k, float falloff) {
    return exp(-dot(coord, coord)*falloff) * cos(dot(coord, k));
}

float init_wave(vec2 coord, vec2 iResolution) {
    return 10. * wavepacket(coord - iResolution.xy/2. - vec2(-100, 0), vec2(1,0), 0.01);
        //+ 10. * wavepacket(coord - iResolution.xy/2. - vec2(100, 0), vec2(0.1,0), 0.01);
}

float potential(vec2 coord, vec2 resolution) {
    vec2 v = coord/resolution;
    //v *= 5. * 3.141592;
    //float V = (cos(v.x) * cos(v.y) + 1.0) / 2.0;;
    //V /= 20.;
    //return V;

    //v = coord_to_uv(coord, resolution);
    //return min(dot(v,v)/2., 1.0);

    //return v.y/10. + (v.x-0.5)*(v.x-0.5) / 2.;
    return 0.0;
}

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(wave);
    
    if (pos.x >= size.x || pos.y >= size.y) return;
    
    vec2 fragCoord = vec2(pos) + 0.5;
    vec2 iResolution = vec2(size);
    vec2 uv = coord_to_uv(fragCoord, iResolution);
    
    // Border
    const float border = 1.0;
    bool in_border = any(lessThan(fragCoord, vec2(border)))
        || any(greaterThan(fragCoord, iResolution - vec2(border)));
    
    // Obstacles (borders)
    if (in_border) {
        imageStore(wave, pos, vec4(0.0));
        return;
    }
    
    // Initialization
    if (frame <= 1) {
        float k = init_wave(fragCoord, iResolution);
        imageStore(wave, pos, vec4(k, k, 0.0, 1.0));
        return;
    }
    
    // Compute kernel - read from previous frame
    vec4 center_prev = imageLoad(wave_copy, pos);
    float center = center_prev.x;
    float prev = center_prev.y;
    bool obstacle = center_prev.z > 0.0;
    
    float up = imageLoad(wave_copy, pos + ivec2(0, 1)).x;
    float down = imageLoad(wave_copy, pos + ivec2(0, -1)).x;
    float right = imageLoad(wave_copy, pos + ivec2(-1, 0)).x;
    float left = imageLoad(wave_copy, pos + ivec2(1, 0)).x;
    
    float next;
    
    // Solve differential equation
    float ddy = (up - 2.0 * center + down);
    float ddx = (right - 2.0 * center + left);
    
    if (frame <= 2) {
        // n = 1 special case (frame 2 because frame 0-1 are init)
        next = center - 0.5 * c * (ddy + ddx);
    } else {
        float m = 1.0;
        float l = 9e-4 * float(fragCoord.y > iResolution.y/2.);
        float upd = ddy + ddx - m*m * center + l * center*center*center - potential(fragCoord, iResolution) * center;
        next = -prev + 2.0 * center + 0.5 * c * upd;
    }
    
    if (obstacle) next = 0.0;
    
    imageStore(wave, pos, vec4(next, center, obstacle ? 1.0 : 0.0, 1.0));
}
