#pragma parameter ntsc "PAL to NTSC aspect ratio correction" 0.0 0.0 1.0 1.0

#pragma parameter mode "mode: Amiga, Genesis, SNES, Master System" 0.0 0.0 4.0 1.0

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
    TEX0 = TexCoord;                    
    gl_Position = MVPMatrix * VertexCoord;     
}

#elif defined(FRAGMENT)

uniform sampler2D Texture;
uniform vec2 OutputSize;

#define vTexCoord TEX0.xy
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define FragColor gl_FragColor
#define Source Texture


#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float mode;


#else

#define mode 0.0

#endif

 


void main()
{
        vec2 pos = vTexCoord;
        if (mode == 1.0) pos.y *=0.781; if (mode == 2.0) pos.y *= 0.933;  if (mode == 3.0) pos.y *= 0.833;
        if (mode == 4.0) {pos.x /=0.8; pos.x -= 0.1;}
        vec4 res = texture2D(Source,pos);
        res *= sin(fract(pos.y*TextureSize.y)*3.14159);
        FragColor = res;

}
#endif