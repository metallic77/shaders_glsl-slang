
// Parameter lines go here:
#pragma parameter Scanline1 "Scanline overall Strength" 1.0 0.0 1.5 0.05
#pragma parameter blur "Blur Horizontal" 0.50 0.00 1.50 0.10
#pragma parameter mask "Mask Type 0:CGWG, 1:Lottes 1, 2:Lottes 2, 3:Gray, 4:Gray 3px" 0.0 -1.0 4.0 1.0
#pragma parameter msk_size "Mask size" 1.0 1.0 2.0 1.0
#pragma parameter msk_str "Mask 0-3-4 Strength" 0.40 0.00 1.00 0.10
#pragma parameter MaskDark "Lottes Mask Dark" 0.50 0.00 2.00 0.10
#pragma parameter MaskLight "Lottes Mask Light" 1.50 0.00 2.00 0.10
#pragma parameter bright "Brightness" 1.20 0.00 2.00 0.02
#pragma parameter sat "Saturation" 1.20 0.00 2.00 0.05
#pragma parameter gamma "Gamma" 0.45 0.00 0.60 0.01

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
COMPAT_VARYING vec2 invDims;


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

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    TEX0.xy = TexCoord.xy * 1.0001;
    invDims = 1.0/TextureSize.xy;

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
uniform sampler2D PassPrev2Texture;
COMPAT_VARYING vec4 TEX0;
COMPAT_VARYING vec2 invDims;

// compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy

#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
// All parameter floats need to have COMPAT_PRECISION in front of them
uniform COMPAT_PRECISION float Scanline1;
uniform COMPAT_PRECISION float blur;
uniform COMPAT_PRECISION float mask;
uniform COMPAT_PRECISION float msk_size;
uniform COMPAT_PRECISION float msk_str;
uniform COMPAT_PRECISION float MaskDark;
uniform COMPAT_PRECISION float MaskLight;
uniform COMPAT_PRECISION float bright;
uniform COMPAT_PRECISION float gamma;
uniform COMPAT_PRECISION float sat;


#else
#define Scanline1  1.0
#define mask      0.0
#define blur      0.5
#define msk_size  1.0
#define msk_str   0.3
#define MaskDark  0.5
#define MaskLight  1.5
#define bright    1.06
#define gamma     0.45
#define sat       1.1


#endif

vec4 Mask (vec2 p)
{		
		p = floor(p/msk_size);
		float mf=fract(p.x*0.5);
		float m=1.0-msk_str;
		vec3 Mask = vec3 (0.5);

// Phosphor.
	if (mask==0.0)
	{
		if (mf < 0.5) return vec4 (1.0,m,1.0,1.0); 
		else return vec4 (m,1.0,m,1.0);
	}

// Very compressed TV style shadow mask.
	else if (mask == 1.0)
	{
		float line = MaskLight;
		float odd  = 0.0;

		if (fract(p.x/6.0) < 0.5)
			odd = 1.0;
		if (fract((p.y + odd)/2.0) < 0.5)
			line = MaskDark;

		p.x = fract(p.x/3.0);
    
		if      (p.x < 0.333) Mask.r = MaskLight;
		else if (p.x < 0.666) Mask.g = MaskLight;
		else                  Mask.b = MaskLight;
		
		Mask*=line;
		return vec4 (Mask.r, Mask.g, Mask.b,1.0);  
	} 

// Aperture-grille.
	else if (mask == 2.0)
	{
		p.x = fract(p.x/3.0);

		if      (p.x < 0.333) Mask.r = MaskLight;
		else if (p.x < 0.666) Mask.g = MaskLight;
		else                  Mask.b = MaskLight;
		return vec4 (Mask.r, Mask.g, Mask.b,1.0);  

	} 

	else if (mask==3.0)
	{
		
		if (mf < 0.5) return vec4 (1.0,1.0,1.0,1.0); 
		else return vec4 (m,m,m,1.0);
	}

	else if (mask==4.0)
	{
		float mf=fract(p.x*0.3333);
		if (mf < 0.6666) return vec4 (1.0,1.0,1.0,1.0); 
		else return vec4 (m,m,m,1.0);
	}

	else return vec4(1.0);
}

//CRT-Pi scanline code adjusted so that scanline takes in to account the actual emmited pixel light,
// e.g. blue emits less light on actual CRT.
float CalcScanLine(float dy, vec3 col)
{

	float str = (col.r*0.3)+(col.g*0.6)+(col.b*0.1);
	float scan = 0.0;
	scan = max(1.0-(dy*dy*dy*dy*50.0*(Scanline1-str)), 0.12);
	return scan;
}



// Code from https://www.shadertoy.com/view/XdcXzn
mat4 saturationMatrix( float saturation )
{
    vec3 luminance = vec3( 0.3086, 0.6094, 0.1520 );
    
    float oneMinusSat = 1.0 - saturation;
    
    vec3 red = vec3( luminance.x * oneMinusSat ); red+= vec3( saturation, 0, 0 );
    
    vec3 green = vec3( luminance.y * oneMinusSat ); green += vec3( 0, saturation, 0 );
    
    vec3 blue = vec3( luminance.z * oneMinusSat ); blue += vec3( 0, 0, saturation );
    
    return mat4( red,     0,
                 green,   0,
                 blue,    0,
                 0, 0, 0, 1 );
}

void main()
{
//Zfast-CRT filter
	vec2 pos = TEX0.xy;
	vec2 p = pos * TextureSize; 
	vec2 i = floor(p) + 0.50;
	vec2 f = p - i;

	p = (i + 4.0*f*f*f)*invDims;
	p.x = mix(p.x, pos.x, blur);

	vec4 screen = COMPAT_TEXTURE(Source, p);

	float scanLineWeight = CalcScanLine(f.y, screen.rgb);

	screen = screen * screen;

//APPLY MASK
	//screen *= Mask(gl_FragCoord.xy*1.0001);

	screen = pow(screen,vec4(gamma,gamma,gamma,1.0));

//APPLY SCANLINES
	screen *= scanLineWeight;
//BRIGHTNESS
	screen *= bright;
    FragColor = saturationMatrix(sat)*screen;
} 
#endif