/*
crt-geom scanlines

DariusG @2023 with previous basis work by CGWG.

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option)
any later version.

*/

#define CURVATURE

#pragma parameter scanline_weight "Scanline Weight" 0.3 0.0 1.0 0.05
#pragma parameter MASK "Mask " 0.3 0.0 1.0 0.1

#ifdef GL_ES
#define COMPAT_PRECISION mediump
precision mediump float;
#else
#define COMPAT_PRECISION
#endif

uniform vec2 TextureSize;
varying vec2 TEX0;

#if defined(VERTEX)
uniform mat4 MVPMatrix;
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
uniform vec2 InputSize;
uniform vec2 OutputSize;

void main()
{
    TEX0 = TexCoord*1.0001;                    
    gl_Position = MVPMatrix * VertexCoord;     
}

#elif defined(FRAGMENT)

uniform sampler2D Texture;
uniform vec2 OutputSize;
uniform vec2 InputSize;

#define vTexCoord TEX0.xy
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define FragColor gl_FragColor
#define Source Texture


#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float scanline_weight;
uniform COMPAT_PRECISION float MASK;


#else

#define scanline_weight 0.3
#define MASK 0.3

#endif

vec4 scanlineWeights(float distance, vec4 color)
        {
    // "wid" controls the width of the scanline beam, for each RGB
    // channel The "weights" lines basically specify the formula
    // that gives you the profile of the beam, i.e. the intensity as
    // a function of distance from the vertical center of the
    // scanline. In this case, it is gaussian if width=2, and
    // becomes nongaussian for larger widths. Ideally this should
    // be normalized so that the integral across the beam is
    // independent of its width. That is, for a narrower beam
    // "weights" should have a higher peak at the center of the
    // scanline than for a wider beam.

    vec4 wid = 2.0 + 2.0 * color;
    vec4 weights = vec4(distance / scanline_weight);
    return 1.4 * exp(-pow(weights * inversesqrt(0.5 * wid), wid)) / (0.6 + 0.2 * wid);

        }

// Distortion of scanlines, and end of screen alpha.
vec2 Warp(vec2 pos)
{
    pos  = pos*2.0-1.0;    
    pos *= vec2(1.0 + (pos.y*pos.y)*0.03, 1.0 + (pos.x*pos.x)*0.05);
    
    return pos*0.5 + 0.5;
}
void main()
{
    float filter_ = InputSize.y/OutputSize.y; //fwidth(ratio_scale.y);
    
#ifdef CURVATURE    
    vec2 xy = Warp(TEX0.xy*(TextureSize/InputSize))*InputSize/TextureSize; 
#else 
    vec2 xy = TEX0.xy;
#endif

    vec2 OGL2Pos = xy * TextureSize;
    vec2 pC4 = floor(OGL2Pos) + 0.5;
    vec2 coord = pC4 / TextureSize;

    vec2 tc = vec2(xy.x, coord.y);
    vec4 res = texture2D(Source, tc);
    vec4 res2 = res;

/// scanlines    
    vec2 ratio_scale = (xy * TextureSize - vec2(0.5));
    vec2 uv_ratio = fract(ratio_scale);
    uv_ratio.y = uv_ratio.y + filter_*0.33;
    
    vec4 weights  = scanlineWeights(uv_ratio.y, res);
    vec4 weights2 = scanlineWeights(1.0 - uv_ratio.y, res2);
    
    weights  = (weights + scanlineWeights(uv_ratio.y, res))/3.0;
    weights2 = (weights2 + scanlineWeights(abs(1.0 - uv_ratio.y), res2))/3.0;
    
    uv_ratio.y = uv_ratio.y-2.0/3.0*filter_;
    
    weights = weights+scanlineWeights(abs(uv_ratio.y), res)/3.0;
    weights2 = weights2+scanlineWeights(abs(1.0-uv_ratio.y), res2)/3.0;

    vec3 mul_res  = (res * weights + res2 * weights2).rgb ;
/// scanlines    

    mul_res = pow(mul_res, vec3(2.2));
    mul_res *= MASK*sin(gl_FragCoord.x*3.14159)+1.0-MASK;
    mul_res = sqrt(mul_res);

    vec2 bordertest = (tc);
    if ( bordertest.x > 0.0001 && bordertest.x < 0.9999 && bordertest.y > 0.0001 && bordertest.y < 0.9999)
        mul_res = mul_res;  else
        mul_res = vec3(0.,0.,0.);

    mul_res *= mix(1.35,1.15,dot(mul_res,vec3(0.3,0.6,0.1)));    
    FragColor = vec4(mul_res,1.0);
}
#endif
