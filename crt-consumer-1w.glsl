#version 110

/*
    zfast_crt_composite, A simple CRT shader by metallic 77.

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.
    
*/

#pragma parameter U_SCANLINE "Scanlines" 0.4 0.0 1.0 0.05
#pragma parameter CHROMA_SEP "Chroma Separation" 0.8 -2.0 2.0 0.05
#pragma parameter BRIGHT_B "Bright Boost" 1.25 1.0 2.0 0.05
#pragma parameter U_VIGNETTE "Vignette" 0.1 0.0 0.5 0.01

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
COMPAT_VARYING vec2 TEX0;
COMPAT_VARYING vec2 ogl2pos;
COMPAT_VARYING vec2 invdims;
COMPAT_VARYING vec2 maskpos;
COMPAT_VARYING vec2 scale;

uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float CHROMA_SEP;
#else
#define CHROMA_SEP 0.5

#endif

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy*1.0001;
    ogl2pos = TEX0.xy*TextureSize;
    invdims = CHROMA_SEP/TextureSize;
    scale = TextureSize/InputSize;
    maskpos = TEX0.xy*scale*OutputSize.xy;
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


uniform sampler2D Texture;
COMPAT_VARYING vec2 TEX0;
COMPAT_VARYING vec2 ogl2pos;
COMPAT_VARYING vec2 invdims;
COMPAT_VARYING vec2 maskpos;
COMPAT_VARYING vec2 scale;

#define Source Texture
#define vTexCoord TEX0.xy

uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float BRIGHT_B;
uniform COMPAT_PRECISION float U_SCANLINE;
uniform COMPAT_PRECISION float U_VIGNETTE;
#else
#define BRIGHT_B 1.25
#define U_SCANLINE 0.3
#define U_VIGNETTE 0.1

#endif

#define GAMMAIN(color) color*color 
#define PI 3.14159265358979323846 
#define TAU 6.2831852

vec3 toLinear(vec3 c) { return c * c; }
vec3 toGamma(vec3 c) { return sqrt(c); }

void main() {
    // uv in [0,1]
    vec2 uv = TEX0*scale*0.95+0.025;

    // --- Barrel warp ---
    // normalized coords centered at 0
    vec2 n = uv * 2.0 - 1.0;
    // polynomial warp
    n *= 1.0 + 0.06 * dot(n, n);
    uv = (n + 1.0) * 0.5;
    uv /= scale;
  
    // pixel size for subpixel offsets
    float px = invdims.x;
    // chroma separation: shift R and B horizontally by +/- small amounts
    vec2 offR = vec2(  px, 0.0);
    vec2 offB = vec2(- px, 0.0);

    // fetch center (G), left/right for R/B
    vec3 colG = COMPAT_TEXTURE(Texture, uv).rgb;
    vec3 colR = COMPAT_TEXTURE(Texture, uv + offR).rgb;
    vec3 colB = COMPAT_TEXTURE(Texture, uv + offB).rgb;

    // reconstruct approximate RGB (we sampled full RGB for each tap,
    // but treat them as subpixel contributions)
    vec3 col = vec3(colR.r, colG.g, colB.b);

    // --- Scanlines / Mask ---
    float scan = 0.5*sin((uv.y*TextureSize.y-0.25)*TAU)+0.5;
    float mask = 0.5*sin(maskpos.x*PI)+0.5;
    col *= mix(BRIGHT_B, scan*mask, U_SCANLINE);

    // --- Vignette ---
    float vig = 1.0 - U_VIGNETTE * pow(length(n), 1.5);
    col *= vig;
  
  // discard outside (soft border)
    if (uv.x < 0.00001 || uv.x > 0.99999 || uv.y < 0.00001 || uv.y > 0.99999) {
        FragColor = vec4(0.0);
        return;
    }

    FragColor = vec4(col, 1.0);
}

#endif