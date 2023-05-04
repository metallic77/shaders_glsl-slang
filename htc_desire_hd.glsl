/*
    A hack of crt-pi - A Raspberry Pi friendly CRT shader.
    By DariusG 	
    Copyright (C) 2015-2016 davej

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.

*/

#pragma parameter MASK "Mask brightness" 0.70 0.0 1.0 0.05
#pragma parameter SCANLINE_WEIGHT "Scanline weight" 0.5 0.0 1.0 0.05
#pragma parameter BLOOM "Bloom factor" 0.7 0.0 1.5 0.05

#define pi 3.141529


#ifdef GL_ES
#define COMPAT_PRECISION mediump
precision mediump float;
#else
#define COMPAT_PRECISION
#endif

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float MASK;
uniform COMPAT_PRECISION float SCANLINE_WEIGHT;
uniform COMPAT_PRECISION float BLOOM;
#else

#define MASK 0.70
#define SCANLINE_WEIGHT 6.0
#define BLOOM 1.5
#endif

/* COMPATIBILITY
   - GLSL compilers
*/

uniform vec2 TextureSize;
varying vec2 TEX0;
varying float omega;

#if defined(VERTEX)
uniform mat4 MVPMatrix;
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
uniform vec2 InputSize;
uniform vec2 OutputSize;

void main()
{
	TEX0 = TexCoord*1.0001;
	gl_Position = MVPMatrix * VertexCoord;
        omega = 2.0*pi*TextureSize.y;

}
#elif defined(FRAGMENT)

uniform sampler2D Texture;


float CalcScanLine(float dy)
{
        return 1.5 + SCANLINE_WEIGHT*sin(dy*omega)*0.5  ;
}

void main()
{
      		vec2 pos = TEX0;
		vec2 OGL2pos = pos * TextureSize;   

		float tempY = floor(OGL2pos.y) + 0.5; 
		float yCoord = tempY / TextureSize.y;   
		float dy = OGL2pos.y - tempY;
		float signY = sign(dy);
		dy = dy * dy;
		dy = dy * dy;
		dy *= 8.0;
		dy /= TextureSize.y;
		dy *= signY;
		vec2 tc = vec2(pos.x, yCoord + dy); // 11 cycles for tc?

// Vertex and Fragment processors calculate vec4 multiply/add etc operations in 1 cycle. 
// Either you multiply a vec4 to a vec4 or a float to a float will cost 1 cycle
// dot and sin cost 1 cycle. "Multiply and add" cost 1 cycle

vec3 colour = texture2D(Texture, tc).rgb;

//SCANLINES
		float scanLineWeight = CalcScanLine(TEX0.y);   
		scanLineWeight *= BLOOM; 
		colour *= scanLineWeight;  // 7 cycles for scanlines

		//float whichMask = fract((gl_FragCoord.x*1.0001) * 0.5);
		//vec3 mask;
		//if (whichMask < 0.5) mask = vec3(MASK);
		//else mask = vec3(1.0);

		gl_FragColor = vec4(colour, 1.0);

	}

#endif
