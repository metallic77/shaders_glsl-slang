/*
    crt-pi - A Raspberry Pi friendly CRT shader.

    Copyright (C) 2015-2016 davej

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.


Notes:

This shader is designed to work well on Raspberry Pi GPUs (i.e. 1080P @ 60Hz on a game with a 4:3 aspect ratio). It pushes the Pi's GPU hard and enabling some features will slow it down so that it is no longer able to match 1080P @ 60Hz. You will need to overclock your Pi to the fastest setting in raspi-config to get the best results from this shader: 'Pi2' for Pi2 and 'Turbo' for original Pi and Pi Zero. Note: Pi2s are slower at running the shader than other Pis, this seems to be down to Pi2s lower maximum memory speed. Pi2s don't quite manage 1080P @ 60Hz - they drop about 1 in 1000 frames. You probably won't notice this, but if you do, try enabling FAKE_GAMMA.

SCANLINES enables scanlines. You'll almost certainly want to use it with MULTISAMPLE to reduce moire effects. SCANLINE_WEIGHT defines how wide scanlines are (it is an inverse value so a higher number = thinner lines). SCANLINE_GAP_BRIGHTNESS defines how dark the gaps between the scan lines are. Darker gaps between scan lines make moire effects more likely.

GAMMA enables gamma correction using the values in INPUT_GAMMA and OUTPUT_GAMMA. FAKE_GAMMA causes it to ignore the values in INPUT_GAMMA and OUTPUT_GAMMA and approximate gamma correction in a way which is faster than true gamma whilst still looking better than having none. You must have GAMMA defined to enable FAKE_GAMMA.

CURVATURE distorts the screen by CURVATURE_X and CURVATURE_Y. Curvature slows things down a lot.

By default the shader uses linear blending horizontally. If you find this too blury, enable SHARPER.

BLOOM controls the increase in width for bright scanlines.

MASK_TYPE defines what, if any, shadow mask to use. MASK defines how much the mask type darkens the screen.

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
uniform COMPAT_PRECISION float CURVATURE_X;
uniform COMPAT_PRECISION float CURVATURE_Y;
uniform COMPAT_PRECISION float MASK;
uniform COMPAT_PRECISION float SCANLINE_WEIGHT;
uniform COMPAT_PRECISION float SCANLINE_GAP_BRIGHTNESS;
uniform COMPAT_PRECISION float BLOOM;
uniform COMPAT_PRECISION float INPUT_GAMMA;
uniform COMPAT_PRECISION float OUTPUT_GAMMA;
#else
#define CURVATURE_X 0.10
#define CURVATURE_Y 0.25
#define MASK 0.70
#define SCANLINE_WEIGHT 6.0
#define SCANLINE_GAP_BRIGHTNESS 0.12
#define BLOOM 1.5
#define INPUT_GAMMA 2.4
#define OUTPUT_GAMMA 2.2
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
		vec2 tc = vec2(pos.x, yCoord + dy); // 13 cycles for tc

		vec3 colour = texture2D(Texture, tc).rgb;

//SCANLINES
		float scanLineWeight = CalcScanLine(TEX0.y);   
		scanLineWeight *= BLOOM; 
		colour *= scanLineWeight;  // 7 cycles for scanlines

		float whichMask = fract((gl_FragCoord.x*1.0001) * 0.5);
		vec3 mask;
		if (whichMask < 0.5) mask = vec3(MASK);
		else mask = vec3(1.0);

		gl_FragColor = vec4(colour * mask, 1.0);

	}

#endif
