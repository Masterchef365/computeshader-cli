#version 430
out vec4 fragColor;
uniform vec2 resolution;
layout(rgba32f, binding = 0) uniform image2D wave;
layout(rgba32f, binding = 1) uniform image2D wave2;

void main() {
    ivec2 pos = ivec2(gl_FragCoord.xy);
    vec4 w = imageLoad(wave, pos);
    vec4 w2 = imageLoad(wave2, pos);
    float mag = dot(w.xy, w.xy);
    float mag2 = dot(w2.xy, w2.xy);

    vec3 color = mag * vec3(1,0,0);//vec3(0.2, 0.7, 0.5);
    color += mag2 * vec3(0,1,0);//vec3(0.7, 0.2, 0.0);

    //color = abs(vec3(w.xy, w2.x));
    color /= pow(1024., 2.0) / 10.;

    fragColor = vec4(color, 1.);
}
