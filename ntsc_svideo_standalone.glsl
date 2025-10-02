#version 110

/*
S-video NTSC shader by DariusG 2025

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option)
any later version.
*/
#pragma parameter ResY "BW Resolution" 230.0 25.0 300.0 25.0
#pragma parameter ResI "I Resolution" 150.0 25.0 300.0 5.0
#pragma parameter ResQ "Q Resolution" 70.0 25.0 300.0 5.0
#pragma parameter chroma_gain "Chroma Gain" 2.0 0.0 4.0 0.05
#pragma parameter u_warp "Curvature" 0.12 0.0 0.3 0.01
#pragma parameter u_border "Border Smoothness" 0.01 0.0 0.1 0.005
#pragma parameter scanL "Scanlines Low" 0.4 0.0 0.5 0.05
#pragma parameter scanH "Scanlines High" 0.2 0.0 0.5 0.05
#pragma parameter u_mask "Mask Brightness" 0.7 0.0 1.0 0.05
#pragma parameter u_noise "Glass Dust/Noise" 0.2 0.0 1.0 0.05



#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying 
#define COMPAT_ATTRIBUTE attribute 
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 COL0;
COMPAT_VARYING vec4 TEX0;
COMPAT_VARYING vec2 ogl2pos;
COMPAT_VARYING vec2 pix;
COMPAT_VARYING vec2 screenscale;
COMPAT_VARYING float maskpos;

vec4 _oPosition1; 
uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

// compatibility #defines
#define vTexCoord TEX0.xy

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float WHATEVER;
#else
#define WHATEVER 0.0
#endif

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    TEX0.xy = TexCoord.xy*1.0001;
    ogl2pos = TEX0.xy*TextureSize;
    pix = 1.0/TextureSize;
    screenscale = TextureSize/InputSize;
    maskpos = ogl2pos.x*OutputSize.x/InputSize.x;
}

#elif defined(FRAGMENT)

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
    #ifdef GL_FRAGMENT_PRECISION_HIGH
    precision highp float;
    #else
    precision mediump float;
    #endif
#define COMPAT_PRECISION mediump
#else
    #define COMPAT_PRECISION 
#endif

uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;
COMPAT_VARYING vec2 ogl2pos;
COMPAT_VARYING vec2 pix;
COMPAT_VARYING float maskpos;
COMPAT_VARYING vec2 screenscale;

// compatibility #defines
#define vTexCoord TEX0.xy
#define Source Texture

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float ResY;
uniform COMPAT_PRECISION float ResI;
uniform COMPAT_PRECISION float ResQ;
uniform COMPAT_PRECISION float u_border;
uniform COMPAT_PRECISION float u_mask;
uniform COMPAT_PRECISION float chroma_gain;
uniform COMPAT_PRECISION float u_noise;
uniform COMPAT_PRECISION float u_warp;
uniform COMPAT_PRECISION float scanL;
uniform COMPAT_PRECISION float scanH;

#else
#define ResY 300.0
#define ResI 120.0
#define ResQ 50.0
#define u_border 0.015
#define u_mask 0.7
#define chroma_gain 2.0
#define u_noise 0.15
#define u_warp 0.12
#define scanL 0.4
#define scanH 0.2

#endif

#define PI  3.1415926
#define TAU 6.283185
#define cycles 170.666/InputSize.x*PI
#define u_time mod(float(FrameCount),2.0)
#define timer  float(FrameCount)/60.0

#define GAMMA(col) col*col

vec3 rgb2yiq(vec3 col){ 
    float r = col.r;
    float g = col.g;
    float b = col.b;

    float Y = dot(vec3(0.299, 0.587, 0.114), col);
    float I = dot(vec3(0.596, -0.274, -0.322), col);
    float Q = dot(vec3(0.211, -0.523, 0.312), col);

    return vec3(Y, I, Q);
}

vec3 yiq2rgb(vec3 col){
    float Y = col.r;
    float I = col.g;
    float Q = col.b;

    float r = Y + 0.956 * I + 0.621 * Q;
    float g = Y - 0.272 * I - 0.647 * Q;
    float b = Y - 1.106 * I + 1.703 * Q;

    return vec3(r, g, b);
}

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

vec3 mod_demod(int steps, vec2 px, vec2 coords)
{
    float sum = 0.0;
    vec3 final = vec3(0.0);
    vec2 xy = floor(coords*TextureSize);
    float fp = dot(xy,vec2(1.0,-1.0));
    
for (int i=-steps; i<=steps; i++){
    float n = float(i);
    float w = exp(-0.3*n*n);
    float phase = (fp + n + u_time)*cycles;
    float cs = cos(phase);
    float sn = sin(phase);
    vec3 res = rgb2yiq(GAMMA(COMPAT_TEXTURE(Source,coords + n*px).rgb));
    res.gb *= vec2(cs,sn);
  
    float comp = dot(vec2(1.0),res.gb); // keep it s-video for performance
    final.r += res.r*w;
    final.g += comp*cs*w*chroma_gain;
    final.b += comp*sn*w*chroma_gain;
    sum += w;
} 

    return final/sum;
}

void main(){
vec2 dx = vec2(pix.x,0.0);
vec2 pos = vTexCoord*screenscale; // 0.0 to 1.0 range

// curve horizontally & vertically
float cx = pos.x - 0.5; // -0.5 to 0.5
float cy = pos.y - 0.5; // -0.5 to 0.5
    pos.x = pos.x + (cy * cy * u_warp * cx);
    pos.y = pos.y + (cx * cx * u_warp*1.5 * cy);
vec2 cpos = pos;

pos /= screenscale; 
vec2 OGL2pos = pos*TextureSize;
        if (InputSize.y > 300.0) OGL2pos.y += u_time; // screen will alter fields
float scanpos = OGL2pos.y;
        if (InputSize.y > 300.0) scanpos *= 0.5;    // keep scanlines 240p 
vec2 near = floor(OGL2pos)+0.5;
vec2 f = OGL2pos - near;
    pos = (near + 4.0*f*f*f)*pix;
    pos = vec2(cpos.x/screenscale.x, pos.y);
      
int Yres = int(ceil(300.0/ResY/2.0));
int Ires = int(ceil(300.0/ResI/2.0));
int Qres = int(ceil(300.0/ResQ/2.0));
vec3 color = vec3(0.0);
    color.r = (mod_demod(Yres, dx*0.5, pos)).x;  // 1/2 = 150
    color.g = (mod_demod(Ires, dx, pos)).y;      // 1/3 = 100
    color.b = (mod_demod(Qres, dx, pos)).z;      // 1/5 = 60 
   
// Subtle noise/dust
if (u_noise > 0.001) {
float nval = rand(vec2(0.0, pos.y * TextureSize.y + timer));
float dust = smoothstep(0.9 - u_noise * 0.2, 1.0, nval) * 0.08 * u_noise;
    color += dust;
}     

    color   = yiq2rgb(color);

// scanlines    
    float l = dot(vec3(0.333),color);
    float scan = mix(scanL,scanH,l);
    color *= scan*sin((scanpos-0.25)*TAU)+1.0-scan;

// get pixel position in screen space
float msk = floor(maskpos);
// Mask out every other line
if (mod(msk, 2.0) == 0.0) {
    color *= u_mask; // mask
}

// fade screen edges (linear falloff)
float fade_x = smoothstep(0.0, u_border, cpos.x) *
               smoothstep(0.0, u_border, 1.0 - cpos.x);
float fade_y = smoothstep(0.0, u_border, cpos.y) *
               smoothstep(0.0, u_border, 1.0 - cpos.y);
// combine fades
float fade = fade_x * fade_y;
    FragColor.rgb = sqrt(color)*fade;
} 
#endif