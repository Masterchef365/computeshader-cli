#version 430
layout(local_size_x = 16, local_size_y = 16) in;
layout(rgba32f, binding = 0) uniform image2D cells;
layout(rgba32f, binding = 1) uniform image2D cells_copy;

//	----    ----    ----    ----    ----    ----    ----    ----
//  Shader developed by Slackermanz
//
//  Info/Code:
//   - Website: https://slackermanz.com
//   - Github: https://github.com/Slackermanz
//   - Shadertoy: https://www.shadertoy.com/user/SlackermanzCA
//   - Discord: https://discord.gg/hqRzg74kKT
//  
//  Socials:
//   - Discord DM: Slackermanz#3405
//   - Reddit DM: https://old.reddit.com/user/slackermanz
//   - Twitter: https://twitter.com/slackermanz
//   - YouTube: https://www.youtube.com/c/slackermanz
//   - Older YT: https://www.youtube.com/channel/UCZD4RoffXIDoEARW5aGkEbg
//   - TikTok: https://www.tiktok.com/@slackermanz
//  
//  Communities:
//   - Reddit: https://old.reddit.com/r/cellular_automata
//   - Artificial Life: https://discord.gg/7qvBBVca7u
//   - Emergence: https://discord.com/invite/J3phjtD
//   - ConwayLifeLounge: https://discord.gg/BCuYCEn
//	----    ----    ----    ----    ----    ----    ----    ----

const uint MAX_NH_SIZE = 16u;

uint u32_upk(uint u32, uint bts, uint off) { return (u32 >> off) & ((1u << bts)-1u); }

float tp(uint n, float s) {
			float	pscale	= s * 0.5;
return (float(n+1u)/256.0) * (pscale/128.0); }
    
float gdv(ivec2 off, int v) {
//	Get Div Value: Return the value of a specified pixel
//		x, y : 	Relative integer-spaced coordinates to origin [ 0.0, 0.0 ]
//		v	 :	Colour channel [ 0, 1, 2 ]
	ivec4	dm		= ivec4(imageSize(cells_copy).xy,1,0);
	vec4 	fc 		= vec4(gl_GlobalInvocationID.xy,0,0);
	vec2	dc		= vec2( dm[0]/dm[2], dm[1]/dm[2] );
	float	cx		= mod(fc[0]+float(off[0]), dc[0]) + floor(fc[0]/dc[0])*dc[0];
	float	cy		= mod(fc[1]+float(off[1]), dc[1]) + floor(fc[1]/dc[1])*dc[1];
	vec4 	pxdata 	= imageLoad( cells_copy, ivec2(cx, cy));
	return 	pxdata[v]; }

vec2 ring( vec2 r, int c ) {
	const	float	w = 1.0; // atan(1.0*(1.0-(d*PI)/r));
	const	uint	tmx = 65536u;
//	const	uint	chk = 2147483648u / (
//					( 	uint(float(r[0])*float(r[0])*PI + float(r[0])*PI + PI	)
//					- 	uint(float(r[1])*float(r[1])*PI + float(r[1])*PI		) ) * 128 );
//	const	float	psn = (chk >= tmx) ? float(tmx) : float(chk);
	const	float	psn = float(tmx);
			float 	d = 0.0;
			float 	a = 0.0;
			float 	b = 0.0;
			float	t = 0.0;
	for(float i = -r[0]; i <= r[0]; i+=1.0) {
		for(float j = -r[0]; j <= r[0]; j+=1.0) {
			d = round(sqrt(i*i+j*j));
			if( d <= r[0] && d > r[1] ) {
				t  = gdv( ivec2(i,j), c ) * w * psn;
				a += t - fract(t);
				b += w * psn; } } }
	return vec2(a, b); }
                
//	Used to reseed the surface with lumpy noise
float get_xc(float x, float y, float xmod) {
	float sq = sqrt(mod(x*y+y, xmod)) / sqrt(xmod);
	float xc = mod((x*x)+(y*y), xmod) / xmod;
	return clamp((sq+xc)*0.5, 0.0, 1.0); }
float shuffle(float x, float y, float xmod, float val) {
	val = val * mod( x*y + x, xmod );
	return (val-floor(val)); }
float get_xcn(float x, float y, float xm0, float xm1, float ox, float oy) {
	float  xc = get_xc(x+ox, y+oy, xm0);
	return shuffle(x+ox, y+oy, xm1, xc); }
float get_lump(float x, float y, float nhsz, float xm0, float xm1) {
	float 	nhsz_c 	= 0.0;
	float 	xcn 	= 0.0;
	float 	nh_val 	= 0.0;
	for(float i = -nhsz; i <= nhsz; i += 1.0) {
		for(float j = -nhsz; j <= nhsz; j += 1.0) {
			nh_val = round(sqrt(i*i+j*j));
			if(nh_val <= nhsz) {
				xcn = xcn + get_xcn(x, y, xm0, xm1, i, j);
				nhsz_c = nhsz_c + 1.0; } } }
	float 	xcnf 	= ( xcn / nhsz_c );
	float 	xcaf	= xcnf;
	for(float i = 0.0; i <= nhsz; i += 1.0) {
			xcaf 	= clamp((xcnf*xcaf + xcnf*xcaf) * (xcnf+xcnf), 0.0, 1.0); }
	return xcaf; }
float reseed(int seed) {
	vec4	fc = vec4(gl_GlobalInvocationID.xy, 0, 0);
	float 	r0 = get_lump(fc[0], fc[1],  2.0, 19.0 + mod(float(seed),17.0), 23.0 + mod(float(seed),43.0));
	float 	r1 = get_lump(fc[0], fc[1], 14.0, 13.0 + mod(float(seed),29.0), 17.0 + mod(float(seed),31.0));
	float 	r2 = get_lump(fc[0], fc[1],  6.0, 13.0 + mod(float(seed),11.0), 51.0 + mod(float(seed),37.0));
	return clamp((r0+r1)-r2,0.0,1.0); }

void main() {
    vec2 fragCoord = vec2(gl_GlobalInvocationID.xy);
    
//	----    ----    ----    ----    ----    ----    ----    ----
//	Shader Setup
//	----    ----    ----    ----    ----    ----    ----    ----

	const 	ivec2	origin  = ivec2(0, 0);
            float	ref_r	= gdv( origin, 0 );	//	Origin value reference
            float	ref_g	= gdv( origin, 1 );	//	Origin value reference
            float	ref_b	= gdv( origin, 2 );	//	Origin value reference

//	----    ----    ----    ----    ----    ----    ----    ----
//	Rule Initilisation
//	----    ----    ----    ----    ----    ----    ----    ----

//	Output Values
	vec3 res_c = vec3(ref_r, ref_g, ref_b );

//	----    ----    ----    ----    ----    ----    ----    ----
//	Transition Functions
//	----    ----    ----    ----    ----    ----    ----    ----

    vec2 nh_0 = ring(vec2(7,4),0);
    float nh0 = nh_0[0] / nh_0[1];

    vec2 nh_1 = ring(vec2(3,0),0);
    float nh1 = nh_1[0] / nh_1[1];

    if( nh0 >= 0.185	&& nh0 <= 0.200 ) { res_c[0] = 1.0; }
    if( nh0 >= 0.343	&& nh0 <= 0.580 ) { res_c[0] = 0.0; }
    if( nh0 >= 0.750	&& nh0 <= 0.850 ) { res_c[0] = 0.0; }
    if( nh1 >= 0.150	&& nh1 <= 0.280 ) { res_c[0] = 0.0; }
    if( nh1 >= 0.445	&& nh1 <= 0.680 ) { res_c[0] = 1.0; }
    if( nh0 >= 0.150	&& nh0 <= 0.180 ) { res_c[0] = 0.0; }

	res_c[1] = res_c[0];
	res_c[2] = res_c[0];
    
//	----    ----    ----    ----    ----    ----    ----    ----
//	Shader Output
//	----    ----    ----    ----    ----    ----    ----    ----

    /*
    if (iMouse.z > 0. && length(iMouse.xy - fragCoord) < 14.0) {
        res_c[0] = round(mod(float(frame),2.0));
        res_c[1] = 0.0;
        res_c[2] = 0.0; }
    */

    if (frame == 0) { res_c[0] = reseed(0); res_c[1] = reseed(1); res_c[2] = reseed(2); }
    vec4 retcolor = vec4(res_c[0],res_c[1],res_c[2],1.0);

    imageStore(cells, ivec2(gl_GlobalInvocationID.xy), retcolor);
}

