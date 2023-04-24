#version 450

/*
   April 2023
   Fast CRT shader with adjustable bilinear by DariusG.
   Tries to mimic the look of a Sony Broadcast Monitor.
   Needs integer scaling 

*/
#pragma parameter sharp1 "Hor. Sharpness" 1.12 1.0 2.0 0.01
#pragma parameter sharp2 "Vert. Sharpness" 1.25 1.0 2.0 0.01
#pragma parameter scanline "Scanline Strength" 0.3 0.0 1.0 0.05
#pragma parameter beam_min "Brights Beam Width" 4.0 1.0 12.0 1.0
#pragma parameter beam_max "Darks Beam Width" 10.0 1.0 12.0 1.0
#pragma parameter BRIGHTBOOST "Boost Bright Colors" 1.4 1.0 2.0 0.05
#pragma parameter sat 		"Saturation adjustment" 1.2 0.0 2.0 0.05
#pragma parameter GAMMA 		"Gamma adjustment" 0.85 0.0 1.5 0.01
#pragma parameter PVM  "PVM Mask On" 0.0 0.0 1.0 1.0
#pragma parameter cgwg "PVM Mask Strength" 0.7 0.0 1.0 0.05
#pragma parameter preserve "Protect Bright On Masks" 0.6 0.0 1.0 0.01

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	float sharp1;
	float sharp2;
	float scanline;
	float beam_min;
	float beam_max;
	float BRIGHTBOOST;
	float sat;
	float GAMMA;
	float PVM;
	float cgwg;
	float preserve;

} params;

#define scanline params.scanline
#define sharp1 params.sharp1
#define sharp2 params.sharp2
#define SourceSize params.SourceSize
#define beam_max params.beam_max
#define beam_min params.beam_min
#define BRIGHTBOOST params.BRIGHTBOOST
#define sat params.sat
#define GAMMA params.GAMMA
#define PVM params.PVM
#define cgwg params.cgwg
#define preserve params.preserve

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 FinalViewportSize;
	vec4 OutputSize;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float width;

void main()
{
	gl_Position = global.MVP * Position;
	vTexCoord = TexCoord * 1.0001;
	width = SourceSize.y * params.OutputSize.w * 0.5;	

}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float width;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 1) uniform sampler2D Source;


float scan (float y, float l)
{
	float beam = mix(beam_max, beam_min, l);
	beam = mix(beam, beam*scanline, l);
	
	float scan0  = 1.0 - (y*y*beam);

	return scan0;
}

vec4 mask (float x)

{
	vec3 Mask = vec3 (1.0);
	float mc = fract (x*0.5);
	if (mc < 0.5) Mask = vec3 (1.0-cgwg); 

	return vec4(Mask.rgb,1.0);
}



vec3 saturation (vec3 textureColor, float l)
{
    vec3 luminanceWeighting = vec3(0.3,0.6,0.1);
    if (l<0.5) luminanceWeighting.rgb=(luminanceWeighting.rgb*luminanceWeighting.rgb)+(luminanceWeighting.rgb*luminanceWeighting.rgb);

    float luminance = dot(textureColor.rgb, luminanceWeighting);
    vec3 greyScaleColor = vec3(luminance);

    vec3 res = vec3(mix(greyScaleColor, textureColor.rgb, sat));
    return res;
}

void main()
{

vec2  texel = 1.0/SourceSize.xy;    // one pixel. eg 1.0 / 224.0 
	texel.x = pow(texel.x, sharp1); //  the higher sharp1 is-smaller distance, less blurry?
	texel.y = pow(texel.y, sharp2); //     	as above

vec2 OGL2Pos = vec2(vTexCoord) * SourceSize.xy;


// we will use these as texture coordinates
vec2 up    = vTexCoord;
vec2 upr   = vTexCoord + vec2(texel.x, 0.0 );
vec2 down  = vTexCoord + vec2(    0.0, texel.y);
vec2 downr = vTexCoord + vec2(texel.x, texel.y);

// let's get our images
vec4 col_up = vec4(texture(Source, up)); 
vec4 col_r  = vec4(texture(Source, upr));
vec4 col_d  = vec4(texture(Source, down));
vec4 col_dr = vec4(texture(Source, downr));

float f_hor  = fract(OGL2Pos.x);
float f_vert = fract(OGL2Pos.y);

vec4 up_line   = mix(col_up, col_r, f_hor);
vec4 down_line = mix(col_d, col_dr, f_hor);

float lum = max(max(up_line.r,up_line.g),up_line.b);

	up_line *= mix(1.0,BRIGHTBOOST,lum);
	//up_line *= mix(BRIGHTBOOST-1.0, 1.0,lum);

vec4 t0 = mix(up_line, down_line, f_vert);

// end of bilinear controllable

float uy = OGL2Pos.y - floor(OGL2Pos.y + 0.5); 

//pseudo-gamma correction but effective!
	 t0 *= mix(GAMMA, 1.0, lum);

	if (SourceSize.y < 400.0) t0 *= scan(fract(uy), lum);

	if (PVM == 1.0) t0 *= mix(mask (vTexCoord.x * global.OutputSize.x), vec4(1.0), preserve) ;
	t0.rgb = saturation(t0.rgb, lum);
	FragColor = t0;
}
