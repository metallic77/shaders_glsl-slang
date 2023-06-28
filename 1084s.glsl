/*
Commodore 1084 controls shader
DariusG @2023

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option)
any later version.

*/

#pragma parameter GREEN "Green" 0.0 0.0 1.0 1.0
#pragma parameter TINT "Tint" 0.0 -0.5 0.5 0.01
#pragma parameter COLOR "Color" 1.0 0.0 2.0 0.01
#pragma parameter CONTRAST "Contrast" 1.0 0.0 2.0 0.01
#pragma parameter BRIGHTNESS "Brightness" 1.0 0.0 2.0 0.01
#pragma parameter HPHASE "H. Phase" 0.0 -1.0 1.0 0.01
#pragma parameter HORIZSIZE "Horiz. Size" 1.0 0.5 2.0 0.01
#pragma parameter VERTSIZE "Vertical Size" 1.0 0.5 2.0 0.01
#pragma parameter VERTSHIFT "Vertical Shift" 0.0 -1.0 1.0 0.01
#pragma parameter CVBSRGB "CVBS/RGB" 1.0 0.0 1.0 1.0
#pragma parameter NTSC "NTSC Aspect" 0.0 0.0 1.0 1.0
#pragma parameter EXTRA "    EXTRA Settings" 0.0 0.0 1.0 1.0
#pragma parameter MSK "Mask Strength" 0.7 0.0 1.0 0.05
#pragma parameter SCAN "Scanline Strength" 1.20 0.5 3.0 0.05
#pragma parameter TEMP "Color Temperature in Kelvins"  9311.0 1031.0 12047.0 72.0
#pragma parameter gamma_out_red "Gamma out Red" 2.2 1.0 4.0 0.05
#pragma parameter gamma_out_green "Gamma out Green" 2.2 1.0 4.0 0.05
#pragma parameter gamma_out_blue "Gamma out Blue" 2.2 1.0 4.0 0.05
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
uniform COMPAT_PRECISION float NTSC;
uniform COMPAT_PRECISION float MSK;
uniform COMPAT_PRECISION float SCAN;
uniform COMPAT_PRECISION float HPHASE;
uniform COMPAT_PRECISION float VERTSHIFT;
uniform COMPAT_PRECISION float HORIZSIZE;
uniform COMPAT_PRECISION float VERTSIZE;
uniform COMPAT_PRECISION float BRIGHTNESS;
uniform COMPAT_PRECISION float COLOR;
uniform COMPAT_PRECISION float CONTRAST;
uniform COMPAT_PRECISION float GREEN;
uniform COMPAT_PRECISION float CVBSRGB;
uniform COMPAT_PRECISION float TINT;
uniform COMPAT_PRECISION float TEMP;
uniform COMPAT_PRECISION float gamma_out_blue; 
uniform COMPAT_PRECISION float gamma_out_green; 
uniform COMPAT_PRECISION float gamma_out_red; 

#else

#define NTSC 0.0
#define MSK 0.3
#define SCAN 0.6
#define HPHASE 0.0
#define VERTSHIFT 0.0
#define HORIZSIZE 1.0
#define VERTSIZE 1.0
#define BRIGHTNESS 1.0
#define COLOR 1.0
#define CONTRAST 1.0
#define GREEN 0.0
#define CVBSRGB 0.0
#define TINT 0.0
#define TEMP 9300.0
#define gamma_out_blue 2.2
#define gamma_out_green 2.2
#define gamma_out_red 2.2
#endif

#define blur_y -0.15/(TextureSize.y*2.0)
#define blur_x 1.75/(TextureSize.x*2.0)

float sw (float y, float l)
{
    float scan = mix(8.0, 12.0, y);
    float tmp = mix(SCAN, SCAN*0.7, l);
    float ex = y*tmp;
    return exp2(-scan*ex*ex);
}

 vec3 Mask(vec2 pos)
{
    if (OutputSize.y > 1600.0) pos /=2.0;
    vec3 mask = vec3(0.5);
    float line = 1.5;
        float odd  = 0.0;

        if (fract(pos.x/4.0) < 0.5)
            odd = 1.0;
        if (fract((pos.y + odd)/2.0) < 0.5)
            line = 0.5;

        pos.x = fract(pos.x*0.5);
    
        if  (pos.x < 0.5) {mask.r = 1.; mask.b = 1.;}
        else  mask.g = 1.;   
        mask*=line;  
        return mask;
}

vec2 Warp(vec2 pos)
{
    pos  = pos*2.0-1.0;    
    pos *= vec2(1.0 + (pos.y*pos.y)*0.03, 1.0 + (pos.x*pos.x)*0.05);
    
    return pos*0.5 + 0.5;
}


float corner(vec2 coord)
{
                coord *= TextureSize/InputSize,InputSize/TextureSize;
                coord = (coord - vec2(0.5)) * 1.0 + vec2(0.5);
                coord = min(coord, vec2(1.0)-coord) * vec2(1.0, InputSize.y/InputSize.x);
                vec2 cdist = vec2(0.02);
                coord = (cdist - min(coord,cdist));
                float dist = sqrt(dot(coord,coord));
                return clamp((cdist.x-dist)*300.0,0.0, 1.0);
}  

vec3 toGrayscale(vec3 color, float average)
{
  return vec3(average);
}

vec3 colorize(vec3 grayscale, vec3 color)
{
    return (grayscale * color);
}

 mat3 color = mat3(  1.0,  TINT,  TINT,   //red tint
                    -TINT,   1.0,  -TINT,  //green tint
                    -TINT,  -TINT,   1.0  //blue tint
                     ); //black tint

float saturate(float v) 
    { 
        return clamp(v, 0.0, 1.0);       
    }

vec3 ColorTemp(float temperatureInKelvins)
{
    vec3 retColor;
    temperatureInKelvins = clamp(temperatureInKelvins, 1000.0, 40000.0) / 100.0;
    
    if (temperatureInKelvins <= 66.0)
    {
        retColor.r = 1.0;
        retColor.g = saturate(0.39008157876901960784 * log(temperatureInKelvins) - 0.63184144378862745098);
    }
    else
    {
        float t = temperatureInKelvins - 60.0;
        retColor.r = saturate(1.29293618606274509804 * pow(t, -0.1332047592));
        retColor.g = saturate(1.12989086089529411765 * pow(t, -0.0755148492));
    }
    
    if (temperatureInKelvins >= 66.0)
        retColor.b = 1.0;
    else if(temperatureInKelvins <= 19.0)
        retColor.b = 0.0;
    else
        retColor.b = saturate(0.54320678911019607843 * log(temperatureInKelvins - 10.0) - 1.19625408914);

    return retColor;
}

void main()
{
        vec2 pos = vTexCoord;
        
        if (NTSC == 1.0) {pos.y *=0.833;} 
        pos -= vec2(HPHASE,VERTSHIFT)/10.0;
        pos /= vec2(HORIZSIZE,VERTSIZE);
        
        pos = Warp(pos*TextureSize/InputSize)*(InputSize/TextureSize);
     
        vec2 OGL2Pos = pos * TextureSize;
        vec2 pC4 = floor(OGL2Pos) + 0.5;
        vec2 coord = pC4 / TextureSize;

        vec2 tc = vec2(mix(pos.x,coord.x,0.4), mix(pos.y,coord.y,0.8));

        


//CVBSRGB
        vec4 res, res2, sample1, sample2, sample3, sample1b, sample2b, sample3b;
if (CVBSRGB == 0.0){
      sample1 = texture2D(Source,tc+(vec2(blur_x,-blur_y)));
      sample2 = 0.5*texture2D(Source,tc);
      sample3 = texture2D(Source,tc + vec2(-blur_x,blur_y));

      sample1b = texture2D(Source,tc+ vec2(0.0,SourceSize.w)+(vec2(blur_x,-blur_y)));
      sample2b = 0.5*texture2D(Source,tc+ vec2(0.0,SourceSize.w));
      sample3b = texture2D(Source,tc+ vec2(0.0,SourceSize.w) + vec2(-blur_x,blur_y));
      
      res = vec4(sample1.r*0.5  + sample2.r, 
                     sample1.g*0.25 + sample2.g + sample3.g*0.25, 
                                          sample2.b + sample3.b*0.5, 1.0);
      res2 = vec4(sample1b.r*0.5  + sample2b.r, 
                     sample1b.g*0.25 + sample2b.g + sample3b.g*0.25, 
                                          sample2b.b + sample3b.b*0.5, 1.0);
    }

    else {res = texture2D(Source, tc);
          res2 = texture2D(Source, tc + vec2(0.0,SourceSize.w));}
        

        float lum = dot(vec3(0.3,0.6,0.1),res.rgb);
        float lum2 = dot(vec3(0.3,0.6,0.1),res2.rgb);
if (GREEN == 1.0)
    {
    vec3 col1 = toGrayscale (res.rgb, lum);
    vec3 col2 = toGrayscale (res2.rgb, lum2);
    vec3 c = vec3(0.0, 1.0, 0.0);
    res.rgb = colorize (col1, c);
    res2.rgb = colorize (col2, c);
    }

       //SCANLINES 
        float f = fract(OGL2Pos.y);

        res.rgb = res.rgb*sw(f, lum) + res2.rgb*sw(1.0-f,lum2);
        res.rgb *= BRIGHTNESS; 
        lum = dot(vec3(0.3,0.6,0.1), res.rgb);

       // MASK 
        
        res.r = mix(pow(res.r,2.44),pow(res.r,2.454),res.r);
        res.g = mix(pow(res.g,2.419),pow(res.g,2.397),res.g);
        res.b = mix(pow(res.b,2.50),pow(res.b,2.476),res.g);
        
        res.rgb *= mix(vec3(1.0), Mask(gl_FragCoord.xy), MSK);
        res.rgb *= ColorTemp(TEMP);

        res.rgb = pow(res.rgb, vec3(1.0/gamma_out_red,1.0,1.0));
        res.rgb = pow(res.rgb, vec3(1.0,1.0/gamma_out_green,1.0));
        res.rgb = pow(res.rgb, vec3(1.0,1.0,1.0/gamma_out_blue));

       //SATURATION CONTROLS
        lum = dot(vec3(0.3,0.6,0.1), res.rgb);
        res.rgb = mix(vec3(lum),res.rgb,COLOR);
        res.rgb *= mix(1.3,1.0,lum);
        res.rgb *= color;

        res *=corner(pos);
        vec4 avglum = vec4(0.5);
        res = mix(res, avglum, (1.0 - CONTRAST));
        FragColor = res;

}
#endif