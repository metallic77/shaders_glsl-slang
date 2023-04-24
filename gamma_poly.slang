#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float gamma1;
	float gamma2;
} params;

#pragma parameter gamma1 "Gamma 1" 2.9 1.0 4.0 0.1
#define gamma1 params.gamma1

#pragma parameter gamma2 "Gamma 2" 3.8 1.0 4.0 0.1
#define gamma2 params.gamma2

#define SourceSize params.SourceSize
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
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
   
   vec3 col = texture (Source, vTexCoord).rgb;
   col = (2.0*pow(col,vec3(gamma1))) - pow(col,vec3(gamma2));
   col = pow (col,vec3(0.45));
    FragColor = vec4(col, 1.0);
}