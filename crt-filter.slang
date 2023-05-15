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
   float coord  = center / SourceSize.y;
   float p      = OGL2Pos.y - center;

   p   = p * 2.0;
   p   = p * p * p;
   p  *= 0.5 * SourceSize.w ;

   vec2 tc = vec2(pos.x, coord + p);
   vec3 res = texture(Source, tc).rgb;

   float lum = dot(vec3(0.22,0.7,0.08),res);
   res *=  0.6*sin(fract(pos.y*SourceSize.y)*pi)+0.4;
   res *= 0.8*abs(sin(vTexCoord.x*pi*OutputSize.x*0.5))+0.2;
   res = mix(vec3(lum), res, 1.1);
   res *= mix(0.9, 1.4, lum);
   FragColor = vec4(res,1.0);
}
