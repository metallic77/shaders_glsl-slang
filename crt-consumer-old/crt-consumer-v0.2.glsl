

// Parameter lines go here:

#pragma parameter WARP "Curvature" 0.04 0.0 0.12 0.01
#pragma parameter CONVX "Convergence X" 0.35 -1.0 1.0 0.05
#pragma parameter CONVY "Convergence Y" -0.15 -1.0 1.0 0.05
#pragma parameter Shadowmask "Mask:0:cgwg,1-2:lottes,3:gw,4:slot " 0.0 -1.0 4.0 1.0
#pragma parameter MaskDark "Mask Dark" 0.5 0.0 2.0 0.1
#pragma parameter MaskLight "Mask Light" 1.5 0.0 2.0 0.1
#pragma parameter BRIGHTBOOST1 "Bright boost" 1.1 0.0 2.0 0.05
#pragma parameter GAMMA_OUT "Gamma Out" 1.8 0.0 4.0 0.1
#pragma parameter SATURATION "Saturation" 1.2 0.0 2.0 0.05



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

// compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy
#define iChannel0 Texture
#define iTime (float(FrameCount) / 60.0)

#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
// All parameter floats need to have COMPAT_PRECISION in front of them
uniform COMPAT_PRECISION float WARP;
uniform COMPAT_PRECISION float CONVX;
uniform COMPAT_PRECISION float CONVY;
uniform COMPAT_PRECISION float SATURATION;
uniform COMPAT_PRECISION float GAMMA_OUT;
uniform COMPAT_PRECISION float BRIGHTBOOST1;
uniform COMPAT_PRECISION float Shadowmask;
uniform COMPAT_PRECISION float MaskDark;
uniform COMPAT_PRECISION float MaskLight;




#else
#define WARP 0.04
#define CONVX 0.35
#define CONVY -0.15
#define SATURATION 1.2 
#define BRIGHTBOOST1 1.1 
#define GAMMA_OUT 2.2
#define Shadowmask 0.0
#define MaskDark 0.5
#define MaskLight 1.5



#endif




// Slight fish eye effect, bulge in the middle
vec2 Warp(vec2 uv) 
{
    float yMul = 1.0+WARP - WARP * sin(uv.x *PI);
            
    if(uv.y >= 0.5)
    {
        return vec2(uv.x, yMul*(uv.y-0.5)+0.5 );
    }
    else
    {
        return vec2(uv.x, 0.5+yMul*(uv.y-0.5));
    }
}

float scanLine (float x,float color)
{
    float scan = mix(6.0,8.0,x);
    float tmp = mix(1.35,1.05, color);
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


vec3 saturation (vec3 textureColor)
{

    vec3 luminanceWeighting = vec3(0.3,0.6,0.1);
    float luminance = dot(textureColor.rgb, luminanceWeighting);
    vec3 greyScaleColor = vec3(luminance);

    vec3 res = vec3(mix(greyScaleColor, textureColor.rgb, SATURATION));
    return res;
}



mat3 vign( float l )
{
    vec2 vpos = vTexCoord * (TextureSize.xy / InputSize.xy);
    vpos *= 1.0 - vpos.xy;
    float vig = vpos.x * vpos.y * 40.0;
    vig = min(pow(vig, 0.2), 1.0); 

    return mat3(vig, 0, 0,
                 0,   vig, 0,
                 0,    0, vig);

}

void main()
{
    vec2 uv = Warp(TEX0.xy*(TextureSize.xy/InputSize.xy))*(InputSize.xy/TextureSize.xy);
    vec2 OGL2Pos = uv * SourceSize.xy;
    vec2 fp = fract(OGL2Pos);
    // Take multiple samples to displace different color channels
    vec3 sample1 = texture(iChannel0, vec2(uv.x-CONVX/1000.0,uv.y-CONVY/1000.0)).rgb; 
    vec3 sample2 = texture(iChannel0, uv).rgb;
    vec3 sample3 = texture(iChannel0, vec2(uv.x+CONVX/1000.0,uv.y+CONVY/1000.0)).rgb;
 
    vec3 color = vec3(0.5*sample1.r+0.5*sample2.r, 0.25*sample1.g+0.5*sample2.g+0.25*sample3.g, 0.5*sample2.b+0.5*sample3.b);   
    color*=color;;
    float lum=color.r*0.3 + color.g*0.6 + color.b*0.1;

    color=color*scanLine(fp.y,lum)+color*scanLine(1.0-fp.y,lum);
    color*=mask(gl_FragCoord.xy*1.0001);

    color=pow(color,vec3(1.0/GAMMA_OUT,1.0/GAMMA_OUT,1.0/GAMMA_OUT)); 
    color*=mix(1.0, BRIGHTBOOST1, lum);    

    if (SATURATION != 1.0) color = saturation(color);
    color*=vign(lum);

    FragColor = vec4(color,1.0);
} 
#endif