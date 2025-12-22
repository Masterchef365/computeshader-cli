#version 430
layout(local_size_x = 16, local_size_y = 16) in;
layout(rgba32f, binding = 0) uniform image2D wave;
layout(rgba32f, binding = 1) uniform image2D wave2;
layout(rgba32f, binding = 3) uniform image2D wave_copy;
layout(rgba32f, binding = 2) uniform image2D wave2_copy;

const float c = 1./4.; // Courant number

vec2 coord_to_uv(vec2 coord, vec2 resolution) {
    vec2 uv = coord / resolution;
    uv = uv * 2.0 - 1.0;
    uv.x *= resolution.x / resolution.y;
    return uv;
}

float wavepacket(vec2 coord, vec2 k, float falloff) {
    return exp(-dot(coord, coord)*falloff) * (cos(dot(coord, k)) - sin(dot(coord, k)));
}

vec2 normalize_or_zero(vec2 v) {
    if (dot(v, v) == 0.0) {
        return vec2(0);
    } else {
        return normalize(v);
    }
}

float init_wave(vec2 coord, vec2 iResolution) {
    return wavepacket(coord - iResolution.xy/2. - vec2(0, 0), normalize_or_zero(vec2(0.,0.)), 0.01);
}
float init_wave2(vec2 coord, vec2 iResolution) {
    return wavepacket(coord - iResolution.xy/3. - vec2(0, 0), normalize_or_zero(vec2(0.,0.)), 0.01);
}


float potential(vec2 coord, vec2 resolution) {
    vec2 v = coord/resolution;
    //v *= 5. * 3.141592;
    //float V = (cos(v.x) * cos(v.y) + 1.0) / 2.0;;
    //V /= 20.;
    //return V;

    v = coord_to_uv(coord, resolution);
    return dot(v,v);

    //return v.y/10. + (v.x-0.5)*(v.x-0.5) / 2.;
    //return 0.0;
}

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(wave_copy);
    
    vec2 fragCoord = vec2(pos) + 0.5;
    vec2 iResolution = vec2(size);

    // Initialization
    if (frame <= 3) {
        float k = init_wave(fragCoord, iResolution);
        imageStore(wave, pos, vec4(k, k, 0.0, 1.0));
        float k2 = init_wave2(fragCoord, iResolution);
        imageStore(wave2, pos, vec4(k2, k2, 0.0, 1.0));
        return;
    } 

    // Compute wave kernel
    {
        // Border
        const float border = 1.0;
        bool in_border = any(lessThan(fragCoord, vec2(border)))
            || any(greaterThan(fragCoord, iResolution - vec2(border)));
        
        if (in_border) {
            imageStore(wave, pos, vec4(0));
        } else {
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
                float m2 = 1.0;
                float V = potential(fragCoord, iResolution);
                float del = ddy + ddx;
                float other_read = imageLoad(wave2_copy, pos).x;
                float other_V = other_read*other_read * 50.;
                float update = del - (m2 + V + other_V) * center;
                next = -prev + 2.0 * center + 0.5 * c * update;
            }
            
            if (obstacle) next = 0.0;
            
            imageStore(wave, pos, vec4(next, center, obstacle ? 1.0 : 0.0, 1.0));
        }
    }

    // Compute wave2 kernel
    {
        // Border
        const float border = 1.0;
        bool in_border = any(lessThan(fragCoord, vec2(border)))
            || any(greaterThan(fragCoord, iResolution - vec2(border)));
        
        if (in_border) {
            imageStore(wave2, pos, vec4(0));
        } else {
            // Compute kernel - read from previous frame
            vec4 center_prev = imageLoad(wave2_copy, pos);
            float center = center_prev.x;
            float prev = center_prev.y;
            bool obstacle = center_prev.z > 0.0;
            
            float up = imageLoad(wave2_copy, pos + ivec2(0, 1)).x;
            float down = imageLoad(wave2_copy, pos + ivec2(0, -1)).x;
            float right = imageLoad(wave2_copy, pos + ivec2(-1, 0)).x;
            float left = imageLoad(wave2_copy, pos + ivec2(1, 0)).x;
            
            float next;
            
            // Solve differential equation
            float ddy = (up - 2.0 * center + down);
            float ddx = (right - 2.0 * center + left);
            
            if (frame <= 2) {
                // n = 1 special case (frame 2 because frame 0-1 are init)
                next = center - 0.5 * c * (ddy + ddx);
            } else {
                float m2 = 1.0;
                float V = potential(fragCoord, iResolution);
                float del = ddy + ddx;
                float other_read = imageLoad(wave_copy, pos).x;
                float other_V = other_read*other_read * 50.;
                float update = del - (m2 + V + other_V) * center;
                next = -prev + 2.0 * center + 0.5 * c * update;
            }
            
            if (obstacle) next = 0.0;
            
            imageStore(wave2, pos, vec4(next, center, obstacle ? 1.0 : 0.0, 1.0));
        }
    }
}

