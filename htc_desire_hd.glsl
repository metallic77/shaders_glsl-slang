
// parameter lines here

#pragma parameter SCANLINE "Scanline Brightness" 0.6 0.0 1.0 0.05
#pragma parameter MASK "MASK Brightness" 0.7 0.0 1.0 0.05
#pragma parameter BOOST "Brightness Boost" 1.5 1.0 2.0 0.1
// defines here
#define pi 3.141529
 
 #if defined(VERTEX)
////////////////////////////////////////////////////////////
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
COMPAT_VARYING float pixel;
COMPAT_VARYING vec2 omega;

uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

// vertex compatibility #defines
#define vTexCoord TEX0.xy

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    TEX0.xy = TexCoord.xy*1.0001;
    pixel = 0.35/TextureSize.x;
    omega = vec2(4.0*pi * OutputSize.x, pi *2.0*TextureSize.y);
}

#elif defined(FRAGMENT)
//////////////////////////////////////////////////////////////
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
COMPAT_VARYING float pixel;
COMPAT_VARYING vec2 omega;

// fragment compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy

#ifdef PARAMETER_UNIFORM
// All parameter floats need to have COMPAT_PRECISION in front of them
uniform COMPAT_PRECISION float whatever;
uniform COMPAT_PRECISION float SCANLINE;
uniform COMPAT_PRECISION float MASK;
uniform COMPAT_PRECISION float BOOST;

#else
#define whatever 0.0
#define SCANLINE 0.7
#define MASK 0.8
#define BOOST 1.5

#endif

//////////////////////////////////////////////////////////////////

void main()
{
	vec3 color1 = 0.75*COMPAT_TEXTURE(Source,vTexCoord).rgb;
	vec3 color2 = COMPAT_TEXTURE(Source,vTexCoord + vec2(pixel,0.0)).rgb;
	vec3 color3 = COMPAT_TEXTURE(Source,vTexCoord - vec2(pixel,0.0)).rgb;
	vec3 color = (color1 + 0.25*(color2 * color3));
	vec3 lumweight = vec3(0.22,0.7,0.08);
	float lum = dot(color,lumweight);
	
	vec2 scan = sin(vTexCoord*omega);
	scan.y = mix(scan.y,1.0,SCANLINE);
	scan.x = mix(scan.x,1.0,MASK);
	color *= scan.y;	
	color *= scan.x;
	color *= mix(1.0,BOOST, lum);
	gl_FragColor = vec4(color, 1.0);
	}

#endif
