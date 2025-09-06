#version 110

/*
   A shader by DariusG 2025
   This program is free software; you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by the Free
   Software Foundation; either version 2 of the License, or (at your option)
   any later version.
*/
#pragma parameter A_CURV          "Curvature" 0.12 0.0 0.3 0.01
#pragma parameter A_FOCUS         "CRT Focus" 0.8 0.5 1.0 0.01
#pragma parameter SCANLINE_WEIGHT "Scanline Weight" 0.3 0.2 0.6 0.05
#pragma parameter MASK_BR         "Mask Brightness" 0.7 0.0 1.0 0.05
#pragma parameter A_MASK          "Mask Fine/Coarse" 2.0 2.0 3.0 1.0
#pragma parameter A_SLOT          "Slot Mask On/Off" 0.0 0.0 1.0 1.0
#pragma parameter A_LUM           "Luminance" 0.03 0.0 1.0 0.01
#pragma parameter A_GLOW          "Glow strength" 0.08 0.0 1.0 0.01
#pragma parameter A_SAT           "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter A_NTSC_J        "NTSC-Japan Colors" 0.0 0.0 1.0 1.0

#define PI   3.14159265358979323846
#define tau  6.283185

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
COMPAT_VARYING vec2 TEX1;
COMPAT_VARYING vec2 screenscale;
COMPAT_VARYING vec2 pixel;
COMPAT_VARYING vec2 maskpos;
COMPAT_VARYING float inv_foc;
COMPAT_VARYING vec2 ogl2pos;
COMPAT_VARYING vec2 dx;
COMPAT_VARYING vec2 dy;

vec4 _oPosition1; 
uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

// compatibility #defines
#define vTexCoord TEX0.xy
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float A_FOCUS;
#else
#define A_FOCUS 0.75
#endif

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    TEX0.xy = TexCoord.xy*1.0001;
    screenscale = SourceSize.xy/InputSize.xy;
    TEX1 = TEX0.xy*screenscale;
    maskpos = TEX0.xy*OutputSize.xy*screenscale.xy;
    pixel = 1.0/TextureSize;
    ogl2pos = TEX0.xy*screenscale-vec2(0.5);    
    dx = vec2(pixel.x * 0.5,0.0);    
    dy = vec2(0.0,pixel.y * 0.25);
    inv_foc = 1.0-A_FOCUS;
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
uniform sampler2D PassPrev3Texture;

COMPAT_VARYING vec4 TEX0;
COMPAT_VARYING vec2 TEX1;
COMPAT_VARYING vec2 maskpos;
COMPAT_VARYING float inv_foc;
COMPAT_VARYING vec2 screenscale;
COMPAT_VARYING vec2 pixel;
COMPAT_VARYING vec2 ogl2pos;
COMPAT_VARYING vec2 dx;
COMPAT_VARYING vec2 dy;

// compatibility #defines
#define vTexCoord TEX0.xy
#define Source Texture
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float SCANLINE_WEIGHT;
uniform COMPAT_PRECISION float A_LUM;
uniform COMPAT_PRECISION float MASK_BR;
uniform COMPAT_PRECISION float A_FOCUS;
uniform COMPAT_PRECISION float A_GLOW;
uniform COMPAT_PRECISION float A_CURV;
uniform COMPAT_PRECISION float A_SAT;
uniform COMPAT_PRECISION float A_MASK;
uniform COMPAT_PRECISION float A_SLOT;
uniform COMPAT_PRECISION float A_NTSC_J;

#else
#define SCANLINE_WEIGHT 0.3
#define A_LUM 0.0
#define A_FOCUS 0.75
#define A_MASK 2.0
#define MASK_BR 0.0
#define A_GLOW 0.15
#define A_CURV 0.12
#define A_SAT 1.0
#define A_SLOT 0.0
#define A_NTSC_J 1.0

#endif

float scanlineWeights(float distance, vec3 color)
{
  float c = dot(color, vec3(1.0)); // simple luminance approximation
  c = clamp(c,0.0,1.0);c *= c;
  float wid = SCANLINE_WEIGHT + 0.1*c;
  float weights = (distance / wid);
  return (A_LUM + SCANLINE_WEIGHT + 0.1) * exp(-weights * weights) / wid;
}

mat3 hue = mat3(                    
0.9501  ,   -0.0431 ,   0.0857  ,
0.0265  ,   0.9278  ,   0.0432  ,
0.0011  ,   -0.0206 ,   1.3153  );

void main() 
{
COMPAT_PRECISION vec2 xy = TEX1;
 
COMPAT_PRECISION float cx = ogl2pos.x; // -0.5 to 0.5
COMPAT_PRECISION float cy = ogl2pos.y; // -0.5 to 0.5
    xy.x = xy.x + (cy * cy * A_CURV * cx);
    xy.y = xy.y + (cx * cx * A_CURV * cy);
COMPAT_PRECISION vec2 cpos = xy;
    xy /= screenscale;
// quillez Y axis
COMPAT_PRECISION float p = xy.y * TextureSize.y ;
COMPAT_PRECISION float i = floor(p) + 0.50;
COMPAT_PRECISION float f = p - i;
float ff = f*f;
p = (i + 16.0*ff*ff*f)*pixel.y;

vec2 ratio_scale = xy*TextureSize ;
float factor = InputSize.y >300.0? 0.5 : 1.0;
vec2 uv_ratio = fract(ratio_scale*factor)-0.25;
xy.y = p;

vec3  col  = COMPAT_TEXTURE(PassPrev3Texture, xy     ).rgb*A_FOCUS;
      col += COMPAT_TEXTURE(PassPrev3Texture, xy + dx).rgb*inv_foc;

vec3 col2  = COMPAT_TEXTURE(PassPrev3Texture, xy + dy).rgb*A_FOCUS;
     col2 += COMPAT_TEXTURE(PassPrev3Texture, xy + dx + dy).rgb*inv_foc;

float w1 = scanlineWeights(uv_ratio.y,col);
float w2 = scanlineWeights(1.0-uv_ratio.y,col2);

vec3 res = col*w1 + col2*w2;

vec3 Glow = COMPAT_TEXTURE(Source,xy).rgb;
    res = res + Glow*A_GLOW;  
if (A_NTSC_J == 1.0){res *=hue;}

float lum = dot(vec3(0.3,0.6,0.1),res);
res = mix(vec3(lum),res, A_SAT);

// get pixel position in screen space
float pix =  floor(maskpos.x);
float pix_step = mod(pix,A_MASK);
float line = 1.0;
float slot_pix_step = 1.0;
float line_step = 1.0;

// MASK CODE
// Mask out every other line
if (pix_step == 0.0) {
    res *= MASK_BR; // mask
  }  else res *= 1.0+lum;

// slot  
if (A_SLOT == 1.0){
    line = floor(maskpos.y);
    slot_pix_step = mod(pix,A_MASK*2.0);
    line_step = mod(line,2.0);   
    if (slot_pix_step < A_MASK  && line_step == 1.0 || 
        slot_pix_step >= A_MASK && line_step == 0.0)
    {
        res *= MASK_BR;
    }

}
// MASK CODE END

// fade screen edges (linear falloff)
float fade_x = smoothstep(0.0, 0.015, cpos.x) *
               smoothstep(0.0, 0.015, 1.0 - cpos.x);
float fade_y = smoothstep(0.0, 0.015, cpos.y) *
               smoothstep(0.0, 0.015, 1.0 - cpos.y);
// combine fades
float fade = fade_x * fade_y;
res *= fade;
FragColor.rgb = sqrt(res);
}
#endif