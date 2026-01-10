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

vec4 wavepacket(vec2 coord, vec2 k, float w, float falloff) {
    float mag = exp(-dot(coord, coord)*falloff);
    float time_phase = c * w;

    float space_phase = dot(coord, k);
    return mag * vec4(
            cos(space_phase + time_phase), 
            sin(space_phase + time_phase),
            cos(space_phase), 
            sin(space_phase)
    );
}

vec2 normalize_or_zero(vec2 v) {
    if (dot(v, v) == 0.0) {
        return vec2(0);
    } else {
        return normalize(v);
    }
}

vec4 init_wave(vec2 coord, vec2 iResolution) {
    return wavepacket(coord - iResolution.xy/2. - vec2(0, 0), vec2(0.,0.), 1., 0.001);
}
vec4 init_wave2(vec2 coord, vec2 iResolution) {
    return wavepacket(coord - iResolution.xy/2. - vec2(200, 0), vec2(0.0,0.), 1., 0.001);
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
    return 0.0;
}

vec4 kern(vec4 center_prev, vec2 center_grad, vec2 other_read, ivec2 size, float factor) {
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
    vec2 center = center_prev.xy;
    vec2 prev = center_prev.zw;

    vec2 next;
    
    if (frame <= 2) {
        // n = 1 special case (frame 2 because frame 0-1 are init)
        next = center - 0.5 * c * center_grad;
    } else {
        float m2 = 1.0;
        float V = potential(fragCoord, iResolution);
        float other_V = dot(other_read, other_read) * 1.;
        //if (factor > 0.0) {
            other_V = exp(-other_V);
        //}

        vec2 self_interact = dot(center, center) * center * 0.0;
        vec2 update = center_grad - (m2 + V + other_V) * center + self_interact;
        next = -prev + 2.0 * center + 0.5 * c * update;
    }

    return vec4(next, center);
}
    
void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(wave_copy);
    
    vec2 fragCoord = vec2(pos) + 0.5;
    vec2 iResolution = vec2(size);

    // Initialization
    if (frame <= 3) {
        imageStore(wave, pos, init_wave(fragCoord, iResolution));
        imageStore(wave2, pos, init_wave2(fragCoord, iResolution));
        return;
    } 

    vec4 wavenext = kern(imageLoad(wave_copy, pos), (grad(wave_copy, pos)).xy, imageLoad(wave2_copy, pos).xy, size, 1.0);
    vec4 wave2next = kern(imageLoad(wave2_copy, pos), (grad(wave2_copy, pos)).xy, imageLoad(wave_copy, pos).xy, size, 0.0);
    imageStore(wave, pos, wavenext);
    imageStore(wave2, pos, wave2next);
}

