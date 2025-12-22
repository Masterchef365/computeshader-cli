/*
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord/iResolution.xy;
    
    // Output to screen
    vec4 r = texture(iChannel0, uv);
    float u = r.x;
    bool obstacle = r.z > 0.;
    
    u *= 20.;
    
    vec3 color;
    if (u > 0.) {
        color = vec3(1., 0.1, 0.1) * u;
    } else {
        color = vec3(0.1, 0.4, 1.) * -u;
    }
    color = vec3(r.x*r.x + r.y*r.y)*1e2 * vec3(0.2, 0.7, 1.0);
    
    if (obstacle) color += vec3(0.1);
   
   
    fragColor = vec4(color, 1.);
    //fragColor = texture(iChannel0, uv);
}
*/

#version 430
out vec4 fragColor;
uniform vec2 resolution;
layout(rgba32f, binding = 0) uniform image2D wave;

void main() {
    ivec2 pos = ivec2(gl_FragCoord.xy);
    vec4 w = imageLoad(wave, pos);
    float mag = dot(w.xy, w.xy);

    vec3 color = mag * vec3(0.2, 0.7, 1.0);;

    fragColor = vec4(color, 1.);
}
