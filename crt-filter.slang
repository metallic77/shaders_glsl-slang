#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;

} params;


#define pi 3.14159
#define iTime float(params.FrameCount) / 2.0
#define SourceSize params.SourceSize
#define OutputSize params.OutputSize
#define OriginalSize params.OriginalSize

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
   vTexCoord = TexCoord*1.0001;
 
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

vec2 Warp(vec2 pos)
{
    pos  = pos*2.0-1.0;    
    pos *= vec2(1.0 + (pos.y*pos.y)*0.02, 1.0 + (pos.x*pos.x)*0.04);
    
    return pos*0.5 + 0.5;
}

void main()
{
	vec2 pos = Warp(vTexCoord);
   vec2 OGL2Pos = pos * SourceSize.xy;

   float center = floor(OGL2Pos.y) + 0.5;
   float coord  = center / SourceSize.y;// back to vTexCoord 0.0....1.0 coordinates
   float p      = OGL2Pos.y - center; // could be negative or positive = right or left of center

   p   = p * 2.0;
   p   = p * p * p; // 3 times so we avoid using "sign", it's slow and not compatible with GL_ES 2.0?
   p  *= 0.5 * SourceSize.w ;// back to vTexCoord 0.0....1.0 coordinates
// result:
// x axis will still use bilinear filtering (no cost), 
// pixel blending happens mostly on x axis on a real CRT. 
// we will add blur in y axis as much as p is... coord alone is nearest
   vec2 tc = vec2(pos.x, coord + p);
   vec3 res = texture(Source, tc).rgb;

   float lum = dot(vec3(0.22,0.7,0.08),res);

// sin will be 0 top and bottom of pixel, or 1 at the middle 
//  ----  0
//  oooo  1
//  oooo  1
//  ----  0
// if sin is 1 and eg SCANLINE_WEIGHT is 0.3, bright lines will be multiplied to 30% brightness 
// only, unless we add that 1.0-0.3, to add 0.7 to have 100% brightness. 

// On the other hand when sin is 0 and scanline is 0.3 our dark line will be multiplied to 0.7. 
// 0.3*0.0 + 1.0-0.3
// If SCANLINE_WEIGHT is 1.0 on the same case, we will get a total 0. Total black lines
// 1.0*0.0 + 1.0-1.0 = 0.0 
// SCANLINE_WEIGHT = how much brightness % we lose on dark lines.   
   res *=  0.6*sin(fract(pos.y*SourceSize.y)*pi)+0.4;
   res *= 0.8*abs(sin(vTexCoord.x*pi*OutputSize.x*0.5))+0.2;
   res = mix(vec3(lum), res, 1.1);
   res *= mix(0.9, 1.4, lum);
   FragColor = vec4(res,1.0);
}
