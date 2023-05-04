/*
    A hack of crt-pi - A Raspberry Pi friendly CRT shader.
    By DariusG 	
    Copyright (C) 2015-2016 davej

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.

*/
#pragma parameter SCANLINE_WEIGHT "Scanline Brightness" 0.5 0.0 1.0 0.1


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
        omega = TEX0.y * pi* TextureSize.y;        // 2 cycles
}
#elif defined(FRAGMENT)

uniform sampler2D Texture;

#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize

float CalcScanLine(float dy)
{
        return 0.5 + sin(omega)*0.5  ;  // 1 cycles
}

void main()
{
      	vec2 pos = TEX0;
		vec2 OGL2pos = pos * TextureSize;          // 1 cycle    // this could be moved to vertex ?

		float tempY = floor(OGL2pos.y) + 0.5;      // 2 cycles? floor too
		float yCoord = tempY / TextureSize.y;      // 1 cycle
		float dy = OGL2pos.y - tempY;              // 1 cycle	  // up to here move to vertex and out yCoord and dy?
		float uy = yCoord + (dy*dy*dy)*SourceSize.w; //4 cycles                             
		vec2 tc = vec2(pos.x, uy); 	// 10 cycles total for tc?

// Vertex and Fragment processors calculate vec4 multiply/add etc operations in 1 cycle. 
// Either you multiply a vec4 to a vec4 or a float to a float will cost 1 cycle
// dot and sin cost 1 cycle. "Multiply and add" cost 1 cycle

vec3 colour = texture2D(Texture, tc).rgb;

//SCANLINES
		float scanLineWeight = CalcScanLine(TEX0.y);   // costed 1 cycles
		scanLineWeight = mix(scanLineWeight,1.0,SCANLINE_WEIGHT); //1 cycles? probably more		       // 1 cycle
		colour *= scanLineWeight; // 1 cycle 

		//float whichMask = fract((gl_FragCoord.x*1.0001) * 0.5);    
		//vec3 mask;
		//if (whichMask < 0.5) mask = vec3(MASK);		    
		//else mask = vec3(1.0);				   
		//colour *= mask;							
		
		gl_FragColor = vec4(colour, 1.0);

	}

#endif
