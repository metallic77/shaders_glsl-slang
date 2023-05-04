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

#define pi 6.28306


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
	TEX0 = TexCoord*1.0001;                    // 1 cycle
	gl_Position = MVPMatrix * VertexCoord;     // 1 cycle
        omega = pi*TextureSize.y;                  // 1 cycle, total 3
}
#elif defined(FRAGMENT)

uniform sampler2D Texture;


float CalcScanLine(float dy)
{
        return 1.5 + SCANLINE_WEIGHT*sin(dy*omega)*0.5  ;  // 3 cycles
}

void main()
{
      		vec2 pos = TEX0;
		vec2 OGL2pos = pos * TextureSize;          // 1 cycle    // this could be moved to vertex ?

		float tempY = floor(OGL2pos.y) + 0.5;      // 1 cycle
		float yCoord = tempY / TextureSize.y;      // 1 cycle
		float dy = OGL2pos.y - tempY;              // 1 cycle	  // up to here move to vertex and out yCoord and dy?
		float signY = sign(dy);                    // 1 cycle ??
		dy = dy * dy;                              // 1 cycle
		dy = dy * dy;				   // 1 cycle
		dy *= 8.0;				   // 1 cycle
		dy /= TextureSize.y;                       // 1 cycle
		dy *= signY; 				   // 1 cycle
		vec2 tc = vec2(pos.x, yCoord + dy); 	// 10 cycles total for tc?

// Vertex and Fragment processors calculate vec4 multiply/add etc operations in 1 cycle. 
// Either you multiply a vec4 to a vec4 or a float to a float will cost 1 cycle
// dot and sin cost 1 cycle. "Multiply and add" cost 1 cycle

vec3 colour = texture2D(Texture, tc).rgb;

//SCANLINES
		float scanLineWeight = CalcScanLine(TEX0.y);   // costed 3 cycles
		scanLineWeight *= BLOOM; 		       // 1 cycle
		colour *= scanLineWeight;  // 7 cycles for scanlines   // 1 cycle, total 14 for filter and scanlines. If we take out filter we gain about 70% speedup!

		//float whichMask = fract((gl_FragCoord.x*1.0001) * 0.5);    
		//vec3 mask;
		//if (whichMask < 0.5) mask = vec3(MASK);		    
		//else mask = vec3(1.0);				   
									
		gl_FragColor = vec4(colour, 1.0);

	}

#endif
