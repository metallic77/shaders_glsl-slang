#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float SCANLINE_SINE_COMP_B;
	float sat;
	float TVL;
	float mask_size;
	float mask_br;
	float temperature;
   float wp_red;
   float wp_green;
   float wp_blue;
   float blurx;
   float boost;
   float mitc_her;
} params;

#pragma parameter SCANLINE_SINE_COMP_B "Scanline Strength" 0.75 0.0 1.0 0.05

#pragma parameter TVL "TVL 2.0/3.0" 2.0 2.0 3.0 1.0
#define TVL params.TVL

#pragma parameter mask_size "Mask Size" 1.0 1.0 2.0 1.0
#define mask_size params.mask_size

#pragma parameter mask_br "Mask Brightness" 0.4 0.0 1.0 0.05
#define mask_br params.mask_br

#pragma parameter mitc_her "B-Spline/Mitchell/Hermite filter" 1.0 0.0 2.0 1.0
#define mitc_her params.mitc_her

#pragma parameter blurx "Horizontal Bluriness" 1.0 0.0 1.0 0.05

#pragma parameter boost "Brightness Boost" 1.2 1.0 2.0 0.02
#define boost params.boost

#pragma parameter sat "Saturation" 1.1 0.0 2.0 0.05
#define sat params.sat

#pragma parameter temperature "White Point temperature" 6503.0 1031.0 12047.0 72.0
#pragma parameter wp_red "Red Shift" 0.05 -1.0 1.0 0.01
#pragma parameter wp_green "Green Shift" -0.1 -1.0 1.0 0.01
#pragma parameter wp_blue "Blue Shift" 0.05 -1.0 1.0 0.01

#define SCANLINE_SINE_COMP_B params.SCANLINE_SINE_COMP_B
layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#define pi 3.145

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

vec3 wp_adjust(vec3 color){

    float temp = params.temperature / 100.;
    float k = params.temperature / 10000.;
    float lk = log(k);

    vec3 wp = vec3(1.);

    // calculate RED
    wp.r = (temp <= 65.) ? 1. : 0.32068362618584273 + (0.19668730877673762 * pow(k - 0.21298613432655075, - 1.5139012907556737)) + (- 0.013883432789258415 * lk);

    // calculate GREEN
    float mg = 1.226916242502167 + (- 1.3109482654223614 * pow(k - 0.44267061967913873, 3.) * exp(- 5.089297600846147 * (k - 0.44267061967913873))) + (0.6453936305542096 * lk);
    float pg = 0.4860175851734596 + (0.1802139719519286 * pow(k - 0.14573069517701578, - 1.397716496795082)) + (- 0.00803698899233844 * lk);
    wp.g = (temp <= 65.5) ? ((temp <= 8.) ? 0. : mg) : pg;

    // calculate BLUE
    wp.b = (temp <= 19.) ? 0. : (temp >= 66.) ? 1. : 1.677499032830161 + (- 0.02313594016938082 * pow(k - 1.1367244820333684, 3.) * exp(- 4.221279555918655 * (k - 1.1367244820333684))) + (1.6550275798913296 * lk);

    // clamp
    wp.rgb = clamp(wp.rgb, vec3(0.), vec3(1.));

    // R/G/B independent manual White Point adjustment
    wp.rgb += vec3(params.wp_red, params.wp_green, params.wp_blue);

    // Linear color input
    return color * wp;
}


vec3 mask (float uv, float l)
{
	float uv_x = uv/mask_size;
	if (TVL == 2.0)
{
	float pos = fract(uv_x*0.5);
    float br = mix (0.0, mask_br, l);
	if (pos <0.5) return vec3 (br); else return vec3(1.0);
}
 
   else if (TVL == 3.0)
   {
   	float pos = fract(uv_x*0.3333);
     float br = mix (0.0, mask_br, l);
   	if (pos <0.3333) return vec3 (br); else return vec3 (1.0);
   }

}

vec3 saturation (vec3 textureColor)
{
    float lum=length(textureColor.rgb)*0.5775;

    vec3 luminanceWeighting = vec3(0.3,0.6,0.1);
    if (lum<0.5) luminanceWeighting.rgb=(luminanceWeighting.rgb*luminanceWeighting.rgb)+(luminanceWeighting.rgb*luminanceWeighting.rgb);

    float luminance = dot(textureColor.rgb, luminanceWeighting);
    vec3 greyScaleColor = vec3(luminance);

    vec3 res = vec3(mix(greyScaleColor, textureColor.rgb, sat));
    return res;
}


void main()
{
   float sine_comp =  SCANLINE_SINE_COMP_B;
   vec2 ps = vec2(params.blurx,1.0) * params.SourceSize.zw;
   vec2 dx = vec2(ps.x, 0.0);
   vec2 dy = vec2(0.0, ps.y);
   
   vec2 tc = (floor(vTexCoord.xy * params.SourceSize.xy) + vec2(0.49999, 0.49999)) / params.SourceSize.xy;
   
   vec2 fp = fract(vTexCoord.xy * params.SourceSize.xy);
   
   vec3 c10 = texture(Source, tc -       dx).xyz;
   vec3 c11 = texture(Source, tc           ).xyz;
   vec3 c12 = texture(Source, tc +       dx).xyz;
   vec3 c13 = texture(Source, tc +       dx).xyz;
	  

   vec4 lobes = vec4(fp.x*fp.x*fp.x, fp.x*fp.x, fp.x, 1.0);

   vec4 InvX = vec4(0.0);
// Horizontal cubic filter
	 
    if (mitc_her == 0.0)
    {   
    InvX.x = dot(vec4( -0.1666, 0.5, -0.5, 0.1666), lobes);
    InvX.y = dot(vec4(  0.5,-1.0,  0.0, 0.6666), lobes);
    InvX.z = dot(vec4( -0.5, 0.5,  0.5, 0.1666), lobes);
    InvX.w = dot(vec4(  0.1666, 0.0,  0.0, 0.0), lobes);


	}
   else if (mitc_her == 1.0) 
   {
    InvX.x = dot(vec4(-0.3888,  0.8333, -0.5, 0.0555), lobes);
    InvX.y = dot(vec4( 1.1666, -2.0,     0.0, 0.8888), lobes);
    InvX.z = dot(vec4(-1.1666,  1.5,     0.5, 0.0555), lobes);
    InvX.w = dot(vec4( 0.3888, -0.3333,  0.0, 0.0), lobes);
    }
 else if (mitc_her == 2.0) 
   {
    InvX.x = dot(vec4(  0.0, 0.0,  0.0, 0.0), lobes);
    InvX.y = dot(vec4(  2.0,-3.0,  0.0, 1.0), lobes);
    InvX.z = dot(vec4( -2.0, 3.0,  0.0, 0.0), lobes);
    InvX.w = dot(vec4(  0.0, 0.0,  0.0, 0.0), lobes);
    }

    vec3 res = InvX.x*c10.xyz;
		   res+= InvX.y*c11.xyz;
		   res+= InvX.z*c12.xyz;
		   res+= InvX.w*c13.xyz;
   
       res = (2.0*pow(res,vec3(2.9))) - pow(res,vec3(3.8));
   float lum = res.r*0.4+res.g*0.3+res.b*0.2;

   res*= mask(vTexCoord.x * params.OutputSize.x, lum );

   float BRIGHTNESS = 1.0 - (SCANLINE_SINE_COMP_B/15.0)*5.0;
   sine_comp = mix(0.0, SCANLINE_SINE_COMP_B, 1.0-lum);
   float scale = params.OutputSize.y/params.SourceSize.y/2.0;
   float omega = params.SourceSize.y*pi*2.0;
   float sine_calc = sin(vTexCoord.y * omega);
   sine_calc = clamp(sine_calc,-1.0,1.0);
   vec3 scanline = res * (BRIGHTNESS + dot(sine_comp * sine_calc, 1.0));
   scanline = pow (scanline,vec3(0.45));
   scanline = saturation(scanline);
   scanline = wp_adjust(scanline);

   FragColor = vec4(scanline.x, scanline.y, scanline.z, 1.0);
}

