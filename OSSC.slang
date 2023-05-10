#version 450

/*

   OSSC shader by DariusG
	uses parts of integer scaling by guest.r

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
   
*/

layout(push_constant) uniform Push
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float SCANLINE;
	float SATURATION;
	float OVERSCAN;
} params;

#pragma parameter SCANLINE "Scanline Brightness" 0.5 0.0 1.0 0.05
#define SCANLINE params.SCANLINE

#pragma parameter SATURATION "Saturation" 1.0 0.0 2.0 0.05
#define SATURATION params.SATURATION

#pragma parameter OVERSCAN "Overscan" 0.0 0.0 1.0 1.0 
#define OVERSCAN params.OVERSCAN


#define SourceSize params.SourceSize
#define TEX0 vTexCoord
#define OutputSize params.OutputSize

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D Source; 
	
vec2 Overscan(vec2 pos, float dx, float dy){
	pos=pos*2.0-1.0;    
	pos*=vec2(dx,dy);
	return pos*0.5 + 0.5;
} 

void main()
{
	vec2 texcoord = TEX0.xy;
	
		vec2 ofactor = OutputSize.xy/params.OriginalSize.xy;
		vec2 intfactor;
		 if (OVERSCAN == 0.0) intfactor = floor(ofactor); else intfactor = ceil(ofactor);
		vec2 diff = ofactor/intfactor;
		float scan = diff.y;
		texcoord = Overscan(texcoord, scan, scan);
		
		float pos = texcoord.y*SourceSize.y;

	vec4 res = texture(Source, texcoord);
	res = pow(res,vec4(2.4));

	vec3 lumweight = vec3(0.22,0.70,0.08);
	float lum = dot(res.rgb,lumweight);
	vec3 gray = vec3(lum);

	
	if (fract(pos) > 0.6) res *= SCANLINE; 
	
	res = pow(res,vec4(1.0/2.2));
	res.rgb = mix(gray,res.rgb, SATURATION); 

	FragColor = res;
}