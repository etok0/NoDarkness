#include "ReShade.fxh"
#include "ReShadeUI.fxh"

uniform float f_TriggerRadius < __UNIFORM_SLIDER_FLOAT1
    ui_label = "Radius";
    ui_tooltip = "Screen area\n"
                 "1 = only the center of the image is used\n"
                 "7 = the whole image is used";
    ui_category = "General settings";
    ui_min = 1.0;
    ui_max = 7.0;
    ui_step = 0.25;
> = 7.0;

uniform float f_StrengthCoeff < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.1; ui_max = 5.0;
	ui_label = "Strength Divider";
	ui_category = "General settings";
	ui_tooltip = "Smaller = Stronger\n"
		"Default = 3";
> = 3.0;

uniform float f_LerpCoef< __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Alpha";
	ui_category = "General settings";
	ui_tooltip = "this number used in linear interpolation\n"
		"Default = 0.5";
> = 0.5;

uniform float f_AntiClip< __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.001; ui_max = 1.0;
	ui_label = "AntiClipping";
	ui_category = "General settings";
	ui_tooltip = "Default = 0.5";
> = 0.5;

uniform float LimitStrength <
	ui_min = 0.00001; ui_max = 1;
	ui_label = "LimitStrength";
	ui_category = "General settings";
	ui_tooltip = "Default = 0.001\n"
		"Min = 0.00001\n"
		"Max = 1.0";
> = 0.001;



uniform bool Enable_log <
	ui_category = "Use to further reduce Clipping of whites";
	ui_tooltip = "Default = true";
> = true;

uniform bool Enable_atan <	
	ui_category = "Use to further reduce Clipping of whites";
	ui_tooltip = "Default = true";
> = true;

texture2D TexLuma { Width = 256; Height = 256; Format = R8; MipLevels = 7; };
sampler SamplerLuma { Texture = TexLuma; };

texture2D TexAvgLuma { Format = R16F; };
sampler SamplerAvgLuma { Texture = TexAvgLuma; };

float PS_Luma(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float4 color = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0, 0));
    return dot(color.xyz, f_StrengthCoeff);
}

float PS_AvgLuma(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return tex2Dlod(SamplerLuma, float4(0.5.xx, 0, f_TriggerRadius)).x;
}

float3 PS_Adaption(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 colorInput = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0, 0)).xyz;
    float3 color = colorInput / max(LimitStrength, tex2Dlod(SamplerAvgLuma, 0).x);
    
    if (Enable_log) color = log(1 + color);
    if (Enable_atan) color = atan(color);
    
    color = color - 0.5;

    if (color.r > 0) color.r = color.r * f_AntiClip;
    if (color.g > 0) color.g = color.g * f_AntiClip;
    if (color.b > 0) color.b = color.b * f_AntiClip;   
    
    color = color + 0.5;

    if (color.r > 1) color.r = 1;
    if (color.g > 1) color.g = 1;
    if (color.b > 1) color.b = 1;

    return color > colorInput ? lerp(colorInput, color, f_LerpCoef) : colorInput;
}

technique NoDarkness
{
    pass Luma
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Luma;
        RenderTarget = TexLuma;
    }

	pass AvgLuma
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_AvgLuma;
        RenderTarget = TexAvgLuma;
    }

    pass Adaption
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Adaption;
    }
}
