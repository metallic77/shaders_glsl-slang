
// parameter lines here

#pragma parameter SCANLINE "Scanline Brightness" 0.6 0.0 1.0 0.05
#pragma parameter MASK "MASK Brightness" 0.8 0.0 1.0 0.05
#pragma parameter BOOST "Brightness Boost" 1.8 1.0 2.5 0.1
#pragma parameter SATURATION "Saturation"  1.25 0.0 2.0 0.05

// defines here
#define pi 3.141529
 
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

uniform  float whatever;
uniform  float SCANLINE;
uniform  float MASK;
uniform  float BOOST;
uniform  float SATURATION;

#define whatever 0.0
#define SCANLINE 0.7
#define MASK 0.8
#define BOOST 1.5
#define SATURATION 1.0


varying vec2 TEX0;
varying float pixel;
varying vec2 omega;

 #if defined(VERTEX)

attribute vec4 VertexCoord;
attribute vec4 TexCoord;


uniform mat4 MVPMatrix;
uniform  int FrameCount;
uniform  vec2 OutputSize;
uniform  vec2 TextureSize;
uniform  vec2 InputSize;


void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy*1.0001;
    pixel = 0.35/TextureSize.x;
    omega = vec2(4.0*pi * OutputSize.x, pi *2.0*TextureSize.y);
}

#elif defined(FRAGMENT)
uniform sampler2D Texture;

void main()
{
	vec3 color1 = 0.75*texture2D(Texture,TEX0).rgb;
	vec3 color2 = texture2D(Texture,TEX0 + vec2(pixel,0.0)).rgb;
	vec3 color3 = texture2D(Texture,TEX0 - vec2(pixel,0.0)).rgb;
	vec3 color = (color1 + 0.25*(color2 * color3));
	vec3 lumweight = vec3(0.22,0.7,0.08);
	float lum = dot(color,lumweight);
	
	vec2 scan = sin(TEX0.xy*omega);
	scan.y = mix(scan.y,1.0,SCANLINE);
	scan.x = mix(scan.x,1.0,MASK);
	color *= scan.y;	
	color *= scan.x;
	color *= mix(1.0,BOOST, lum);
	color = mix(vec3(lum),color, SATURATION);
	gl_FragColor = vec4(color, 1.0);
	}

#endif
