// Parameter lines go here:
#pragma parameter SCANLINE1 "Scanline Strength dark" 0.75.0 1.00 0.05
#pragma parameter SCANLINE2 "Scanline Strength bright" 0.50 0.0 1.0 0.05
#pragma parameter BOOST "Bright Boost" 1.1 0.0 2.0 0.05
#pragma parameter SHARPNESS "Horizontal Sharpness" 2.0 1.0 5.0 0.25 

#define pi 6.28318

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
COMPAT_VARYING float omega;

vec4 _oPosition1; 
uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform COMPAT_PRECISION float size;

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    COL0 = COLOR;
    TEX0.xy = TexCoord.xy;
    omega = pi * TextureSize.y;
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
COMPAT_VARYING float omega;

// compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy

#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutputSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
// All parameter floats need to have COMPAT_PRECISION in front of them
uniform COMPAT_PRECISION float SCANLINE1;
uniform COMPAT_PRECISION float SCANLINE2;
uniform COMPAT_PRECISION float BOOST;
uniform COMPAT_PRECISION float SHARPNESS;

#else
#define SCANLINE1 0.4
#define SCANLINE2 0.25
#define BOOST 1.15
#define SHARPNESS 4.0
#endif

void main()
{
      vec2 pos = TEX0.xy;
      vec2 texcoordInPixels = pos * TextureSize;
      float tempX = floor(texcoordInPixels.x) + 0.5;
      float xCoord = tempX / TextureSize.x; 
      float dx = texcoordInPixels.x - tempX;
      float signX = sign(dx); //returns -1.0 if x is less than 0.0, 0.0 if x is equal to 0.0, and +1.0 if x is greater than 0.0
      dx = SHARPNESS/2.0 * pow(dx,SHARPNESS);
      dx /= TextureSize.x/2.0;
      dx *= signX;
      
      vec2 tc = vec2(xCoord + dx, pos.y );
   
   vec3 res = COMPAT_TEXTURE(Source, tc).xyz;
   res*=res;   
   
   float lum=res.r*0.3+res.g*0.6+res.b*0.1;
   float scan; scan = mix(SCANLINE1,SCANLINE2,lum);
   vec3 scanline = res * (1.0 + dot(scan * sin(pos * omega), vec2(0.0, 1.0)));

   scanline=sqrt(scanline);
   scanline*=mix(0.8,BOOST,lum);
 
   FragColor = vec4(scanline, 1.0);
} 
#endif
