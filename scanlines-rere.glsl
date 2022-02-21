// Parameter lines go here:
#pragma parameter thickness0  "Scanline thickness"        0.75 0.00 1.00 0.05
#pragma parameter glow0       "Scanline glow"             0.50 0.00 1.00 0.05
#pragma parameter highlights0 "Scanline highlights"       0.75 0.00 1.00 0.05
#pragma parameter cgwg        "CGWG Mask Strength"        0.30 0.00 1.00 0.05        
#pragma parameter size        "Mask Size"                 1.0  1.0  2.0  1.0        
#pragma parameter boost0      "Luminance boost"           0.25 0.00 1.00 0.05
#pragma parameter sGamma     "Source gamma"              2.40 1.00 3.00 0.1
#pragma parameter tGamma     "Target gamma"              2.20 1.00 3.00 0.1

#define pi 3.141592654
#define luminance(c) (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)

vec3 gammaFn(vec3 c, float gamma) {
  return vec3(pow(c.x, gamma), pow(c.y, gamma), pow(c.z, gamma));
}

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
COMPAT_VARYING vec4 TEX0;
COMPAT_VARYING float thickness;
COMPAT_VARYING float glow;
COMPAT_VARYING float highlights;
COMPAT_VARYING float boost;


vec4 _oPosition1; 
uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform COMPAT_PRECISION float thickness0;
uniform COMPAT_PRECISION float glow0;
uniform COMPAT_PRECISION float highlights0;
uniform COMPAT_PRECISION float boost0;

void main()
{
   gl_Position = MVPMatrix * VertexCoord;
   thickness = 0.5 + mix(0.0, 2.0, thickness0);
   glow = mix(-0.5, 0.5, glow0);
   highlights = mix(0.0, 1.0, highlights0);
   boost = mix(0.0, 5.0, boost0);
   TEX0.xy = TexCoord.xy*1.0001;
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
COMPAT_VARYING float  boost;
COMPAT_VARYING float thickness;
COMPAT_VARYING float glow;
COMPAT_VARYING float highlights;

// compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy

#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutputSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
// All parameter floats need to have COMPAT_PRECISION in front of them
uniform COMPAT_PRECISION float sGamma;
uniform COMPAT_PRECISION float tGamma;
uniform COMPAT_PRECISION float cgwg;
uniform COMPAT_PRECISION float size;
#else
#define sGamma 2.40
#define tGamma 2.20
#define cgwg   0.30
#define size   1.00
#endif

vec3 mask(float pos)
{
   pos.x = fract(pos/2.0/size);
   if (pos.x < 0.5) return vec3(1.0,1.0-cgwg,1.0);
   else return vec3(1.0-cgwg,1.0,1.0-cgwg);
}

void main()
{
   vec2 pos = TEX0.xy;

//CRT-Pi Sharp filter  
      vec2 OGL2Pos = pos * TextureSize;
      vec2 pC4 = floor(OGL2Pos) + 0.5;
      vec2 coord = pC4 / TextureSize;
      vec2 deltas = OGL2Pos - pC4;
      vec2 signs = sign(deltas);
      deltas.x *= 2.0;
      deltas = deltas * deltas;
      deltas.y = deltas.y * deltas.y;
      deltas.x *= 0.5;
      deltas.y *= 8.0;
      deltas /= TextureSize;
      deltas *= signs;
      vec2 tc = coord + deltas;

   vec3 col = COMPAT_TEXTURE(Source, tc).rgb;

//GAMMA IN
   col = gammaFn(col, sGamma);
//SATURATION
   float l = length(col);
   col = normalize(pow(col, vec3(1.1)))*l; 
//APPLY MASK
   col*=mask(gl_FragCoord.x * 1.000001);

   float L = luminance(col);
   float y = fract(pos.y * SourceSize.y * 1.0);

   y = pow(sin(y * pi), thickness);
   y = (y + glow) / (1.0 + glow);
   float g = 1.0 + L * (1.0 - L) * boost;
   col = mix(col, col * g * y, 1.0 - L * highlights);
//GAMMA OUT
   FragColor = vec4(gammaFn(col, 1.0 / tGamma), 1.0);
} 
#endif
