/*
  

*/
#pragma parameter SCANLINE_WEIGHT "Scanline Strength" 0.3 0.0 1.0 0.1
#pragma parameter BLOOM "Bloom" 1.3 1.0 2.0 0.05


#define pi 3.14159

#ifdef GL_ES
#define COMPAT_PRECISION mediump
precision mediump float;
#else
#define COMPAT_PRECISION
#endif

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float SCANLINE_WEIGHT;
uniform COMPAT_PRECISION float BLOOM;
#else

#define SCANLINE_WEIGHT 1.0
#define BLOOM 1.0
#endif

/* COMPATIBILITY
   - GLSL compilers
*/

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
	TEX0 = TexCoord;                    
	gl_Position = MVPMatrix * VertexCoord;     
}

#elif defined(FRAGMENT)

uniform sampler2D Texture;

#define vTexCoord TEX0.xy
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define FragColor gl_FragColor
#define Source Texture


void main()
{
	float OGL2Pos = vTexCoord.y*SourceSize.y;
	float cent = floor(OGL2Pos)+0.5;
	float ycoord = cent*SourceSize.w; 
	//float p = 2.0*(OGL2Pos - cent); 

	//p = p*p*p; 
	//p *= 0.5;
	//p = p*SourceSize.w; 

    vec3 res = texture2D(Source, vec2(vTexCoord.x, ycoord)).rgb;
    res *= SCANLINE_WEIGHT*sin(fract(OGL2Pos*0.999)*pi) + 1.0-SCANLINE_WEIGHT ;
    
    float lum = dot(vec3(0.22,0.7,0.08), res);
	res *= mix(0.85,BLOOM, lum); 

	FragColor = vec4(res, 1.0);
}
#endif
