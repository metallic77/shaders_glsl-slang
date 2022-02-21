
// Parameter lines go here:



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
uniform COMPAT_PRECISION float blur;




#else
#define WARP 0.0
#define blur 0.0

#endif


void main()
{
   COMPAT_PRECISION vec2 pos = TEX0.xy;   
   COMPAT_PRECISION vec3 sample1 = COMPAT_TEXTURE(Source,vec2(pos.x + 1.0/1000.0, pos.y - 0.3/1000.0)).rgb;
   COMPAT_PRECISION vec3 sample2 = COMPAT_TEXTURE(Source,pos).rgb;
   COMPAT_PRECISION vec3 sample3 = COMPAT_TEXTURE(Source,vec2(pos.x - 0.8/1000.0, pos.y + 0.5/1000.0)).rgb;
   
   COMPAT_PRECISION vec3 colour = vec3 (sample1.r*0.5+sample2.r*0.5, sample1.g*0.25 + sample2.g*0.5 + sample3.g*0.25, sample2.b*0.5 + sample3.b*0.5);
   
   float OGL2Pos = pos.y*TextureSize.y;
   float OGL2 = floor(OGL2Pos)+0.5;
   float fp = OGL2Pos-OGL2;
  
   colour*= 1.0-fp;
   

   FragColor = vec4(colour,1.0);
} 
#endif