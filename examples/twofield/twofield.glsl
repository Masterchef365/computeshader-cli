#version 430
layout(local_size_x = 16, local_size_y = 16) in;
layout(rgba32f, binding = 0) uniform image2D wave;
layout(rgba32f, binding = 1) uniform image2D wave2;
layout(rgba32f, binding = 3) uniform image2D wave_copy;
layout(rgba32f, binding = 2) uniform image2D wave2_copy;

#define grad(img, pos)\
    -imageLoad(img, pos) * 4.0\
    + imageLoad(img, pos + ivec2(0, -1))\
    + imageLoad(img, pos + ivec2(0, 1))\
    + imageLoad(img, pos + ivec2(-1, 0))\
    + imageLoad(img, pos + ivec2(1, 0))

const float c = 1./4.; // Courant number

vec2 coord_to_uv(vec2 coord, vec2 resolution) {
    vec2 uv = coord / resolution;
    uv = uv * 2.0 - 1.0;
    uv.x *= resolution.x / resolution.y;
    return uv;
}

vec2 wavepacket(vec2 coord, vec2 k, float w, float falloff) {
    float mag = exp(-dot(coord, coord)*falloff);
    float time_phase = c * w;

    float space_phase = dot(coord, k);
    return mag * vec2(cos(space_phase + time_phase), cos(space_phase));
}

vec2 normalize_or_zero(vec2 v) {
    if (dot(v, v) == 0.0) {
        return vec2(0);
    } else {
        return normalize(v);
    }
}

vec2 init_wave(vec2 coord, vec2 iResolution) {
    return wavepacket(coord - iResolution.xy/2. - vec2(0, 0), vec2(0.,0.), 1., 0.01);
}
vec2 init_wave2(vec2 coord, vec2 iResolution) {
    return wavepacket(coord - iResolution.xy/2. - vec2(200, 0), vec2(1.0,0.), 1., 0.01);
}


float potential(vec2 coord, vec2 resolution) {
    vec2 v = coord/resolution;
    //v *= 5. * 3.141592;
    //float V = (cos(v.x) * cos(v.y) + 1.0) / 2.0;;
    //V /= 20.;
    //return V;

    //v = coord_to_uv(coord, resolution);
    //return dot(v,v);

    //return v.y/10. + (v.x-0.5)*(v.x-0.5) / 2.;
    return 0.0;
}

vec4 kern(vec4 center_prev, vec4 center_grad, vec4 other_read, ivec2 size) {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    
    if (pos.x >= size.x || pos.y >= size.y) return vec4(0);
    
    vec2 fragCoord = vec2(pos) + 0.5;
    vec2 iResolution = vec2(size);
    vec2 uv = coord_to_uv(fragCoord, iResolution);
    
    // Border
    const float border = 1.0;
    bool in_border = any(lessThan(fragCoord, vec2(border)))
        || any(greaterThan(fragCoord, iResolution - vec2(border)));
    
    // Obstacles (borders)
    if (in_border) {
        return vec4(0);
    }
    
    // Compute kernel - read from previous frame
    float center = center_prev.x;
    float prev = center_prev.y;
    bool obstacle = center_prev.z > 0.0;

    float next;
    
    if (frame <= 2) {
        // n = 1 special case (frame 2 because frame 0-1 are init)
        next = center - 0.5 * c * center_grad.x;
    } else {
        float m2 = 1.0;
        float V = potential(fragCoord, iResolution);
        float other_V = other_read.x*other_read.x * 50.;
        float update = center_grad.x - (m2 + V + other_V) * center;
        next = -prev + 2.0 * center + 0.5 * c * update;
    }
    
    if (obstacle) next = 0.0;

    return vec4(next, center, obstacle ? 1.0 : 0.0, 1.0);
}
    
void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(wave_copy);
    
    vec2 fragCoord = vec2(pos) + 0.5;
    vec2 iResolution = vec2(size);

    // Initialization
    if (frame <= 3) {
        vec2 k = init_wave(fragCoord, iResolution);
        imageStore(wave, pos, vec4(k, vec2(0, 1)));
        vec2 k2 = init_wave2(fragCoord, iResolution);
        imageStore(wave2, pos, vec4(k2, vec2(0, 1)));
        return;
    } 

    vec4 wavenext = kern(imageLoad(wave_copy, pos), grad(wave_copy, pos), imageLoad(wave2_copy, pos), size);
    vec4 wave2next = kern(imageLoad(wave2_copy, pos), grad(wave2_copy, pos), imageLoad(wave_copy, pos), size);
    imageStore(wave, pos, wavenext);
    imageStore(wave2, pos, wave2next);
}

