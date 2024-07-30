#version 110

// Parameter lines go here:

#pragma parameter WARP "Curvature" 0.12 0.0 1.0 0.02
#pragma parameter scan1 "Scanline dark" 1.35 0.0 2.5 0.05
#pragma parameter scan2 "Scanline bright" 1.05 0.0 2.5 0.05
#pragma parameter CONVX "Convergence X" 0.35 -2.0 2.0 0.05
#pragma parameter CONVY "Convergence Y" -0.15 -2.0 2.0 0.05
#pragma parameter Shadowmask "Mask:0:CGWG,1-2:Lottes,3:BW,4:Fine slot" 0.0 -1.0 4.0 1.0
#pragma parameter MaskDark "Mask Dark" 0.5 0.0 2.0 0.1
#pragma parameter MaskLight "Mask Light" 1.5 0.0 2.0 0.1
#pragma parameter BRIGHTBOOST1 "Dark boost" 1.35 0.0 2.0 0.05
#pragma parameter SATURATION "Saturation" 1.0 0.0 2.0 0.05



#define PI 3.14159


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
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 TEX0;
COMPAT_VARYING vec2 scale;

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

void main()
{
   gl_Position = MVPMatrix * VertexCoord;
   TEX0.xy = TexCoord.xy*1.0001;
   scale = SourceSize.xy/InputSize.xy;
}

#elif defined(FRAGMENT)

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

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out lowfp vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;
COMPAT_VARYING vec2 scale;

// compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy
#define iTime (float(FrameCount) / 60.0)

#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
// All parameter floats need to have COMPAT_PRECISION in front of them
uniform COMPAT_PRECISION float WARP;
uniform COMPAT_PRECISION float scan1;
uniform COMPAT_PRECISION float scan2;
uniform COMPAT_PRECISION float CONVX;
uniform COMPAT_PRECISION float CONVY;
uniform COMPAT_PRECISION float SATURATION;
uniform COMPAT_PRECISION float BRIGHTBOOST1;
uniform COMPAT_PRECISION float Shadowmask;
uniform COMPAT_PRECISION float MaskDark;
uniform COMPAT_PRECISION float MaskLight;




#else
#define WARP 0.04
#define scan1 1.35
#define scan1 1.05
#define CONVX 0.35
#define CONVY -0.15
#define SATURATION 1.2 
#define BRIGHTBOOST1 1.1 
#define Shadowmask 0.0
#define MaskDark 0.5
#define MaskLight 1.5



#endif

float scanLine (float x,float color)
{
    float scan = mix(6.0,8.0,x);
    float tmp = mix(scan1,scan2, color);
    float ex = x*tmp;
    return exp2(-scan*ex*ex);
}


vec3 mask(vec2 x)
{  

    if (Shadowmask == 0.0)
    {
    float m =fract(x.x*0.5);

    if (m<0.5) return vec3(1.0,MaskDark,1.0);
    else return vec3(MaskDark,1.0,MaskDark);
    }
   
    else if (Shadowmask == 1.0)
    {
        vec3 Mask = vec3(MaskDark);

        float line = MaskLight;
        float odd  = 0.0;

        if (fract(x.x/6.0) < 0.5)
            odd = 1.0;
        if (fract((x.y + odd)/2.0) < 0.5)
            line = MaskDark;

        float m = fract(x.x/3.0);
    
        if      (m< 0.333)  Mask.r = MaskLight;
        else if (m < 0.666) Mask.g = MaskLight;
        else                Mask.b = MaskLight;
        
        Mask*=line; 
        return Mask; 
    } 
    

    else if (Shadowmask == 2.0)
    {
    float m =fract(x.x*0.3333);

    if (m<0.3333) return vec3(MaskDark,MaskDark,MaskLight);
    if (m<0.6666) return vec3(MaskDark,MaskLight,MaskDark);
    else return vec3(MaskLight,MaskDark,MaskDark);
    }

    if (Shadowmask == 3.0)
    {
    float m =fract(x.x*0.5);

    if (m<0.5) return vec3(1.0);
    else return vec3(MaskDark);
    }
   

    else if (Shadowmask == 4.0)
    {   
        vec3 Mask = vec3(MaskDark,MaskDark,MaskDark);
        float line = MaskLight;
        float odd  = 0.0;

        if (fract(x.x/4.0) < 0.5)
            odd = 1.0;
        if (fract((x.y + odd)/2.0) < 0.5)
            line = MaskDark;

        float m = fract(x.x/2.0);
    
        if  (m < 0.5) {Mask.r = MaskLight; Mask.b = MaskLight;}
                else  Mask.g = MaskLight;   

        Mask*=line;  
        return Mask;
    } 
    else return vec3(1.0);
}



vec2 Warp(vec2 coord) {
    vec2 cc = coord - 0.5;
    float dist = dot(cc, cc) * WARP;
    dist -= WARP/4.0;
    return coord + cc * (1.0 - dist) * dist;
}

void main()
{
    vec2 uv = Warp(TEX0.xy*scale)/scale;
    float scanpos = uv.y;
    uv.y = uv.y*SourceSize.y + 0.5;
    float iuv = floor( uv.y );
    float fuv = fract( uv.y );
    uv.y = iuv + fuv*fuv*(3.0-2.0*fuv);
    uv.y = (uv.y - 0.5)*SourceSize.w;
   
    vec2 OGL2Pos = scanpos * SourceSize.xy;
    vec2 fp = fract(OGL2Pos-0.5);

    // Take multiple samples to displace different color channels
    vec3 sample1 = COMPAT_TEXTURE(Source, vec2(uv.x-CONVX/1000.0,uv.y-CONVY/1000.0)).rgb; 
    vec3 sample2 = COMPAT_TEXTURE(Source, uv).rgb;
    vec3 sample3 = COMPAT_TEXTURE(Source, vec2(uv.x+CONVX/1000.0,uv.y+CONVY/1000.0)).rgb;
 
    vec3 color = vec3(0.5*sample1.r + 0.5*sample2.r, 
                     0.25*sample1.g + 0.5*sample2.g + 0.25*sample3.g, 
                                      0.5*sample2.b +  0.5*sample3.b);  

    color *= color;;
    float lum = dot(vec3(0.25),color);

    color = color*scanLine(fp.y,lum) + color*scanLine(1.0-fp.y,lum);
    color *= mask(gl_FragCoord.xy*1.0001);

    color=sqrt(color); 
    color*=mix(BRIGHTBOOST1, 1.0, lum);    
    
    float gr = dot(vec3(0.3,0.6,0.1),color);
    vec3 grays = vec3(gr);
    color = mix(grays,color,SATURATION);

    #if defined GL_ES
    // hacky clamp fix for GLES
    vec2 bordertest = (uv);
    if ( bordertest.x > 0.0001 && bordertest.x < 0.9999 && bordertest.y > 0.0001 && bordertest.y < 0.9999)
        color = color;
    else
        color = vec3(0.0);
#endif

    FragColor = vec4(color,1.0);
} 
#endif
